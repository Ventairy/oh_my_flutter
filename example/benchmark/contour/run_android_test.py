"""Offline regression checks for the Android log framing protocol."""

import argparse
from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from run_android import ChunkParser, collect, source_metadata
from source_manifest import write_manifest


def records(result=None):
    value = result if result is not None else {'schema': 2, 'payload': 'x' * 1400}
    text = json.dumps(value, ensure_ascii=False)
    encoded = text.encode('utf-16-le')
    chunks = [encoded[index:index + 1200].decode('utf-16-le') for index in range(0, len(encoded), 1200)]
    header = json.dumps({'chunks': len(chunks), 'characters': len(encoded) // 2})
    return [f'CONTOUR_BENCHMARK_BEGIN {header}', *[
        f'CONTOUR_BENCHMARK_CHUNK {index}/{len(chunks)} {chunk}'
        for index, chunk in enumerate(chunks, start=1)
    ], 'CONTOUR_BENCHMARK_END']


class ChunkParserTest(unittest.TestCase):
    def test_when_chunks_arrive_out_of_order_it_should_reassemble_numeric_order(self):
        parser = ChunkParser()
        lines = records()
        result = None
        for line in [lines[0], *reversed(lines[1:-1]), lines[-1]]:
            result = parser.feed(line)
        self.assertEqual(result, {'schema': 2, 'payload': 'x' * 1400})

    def test_when_a_large_diagnostic_table_spans_hundreds_of_chunks_it_should_reassemble_it(self):
        parser = ChunkParser()
        expected = {'schema': 2, 'payload': 'x' * 198000}
        result = None
        for line in records(expected):
            result = parser.feed(line)
        self.assertEqual(result, expected)

    def test_when_text_contains_non_bmp_unicode_it_should_count_dart_utf16_units(self):
        parser = ChunkParser()
        result = None
        for line in records({'schema': 2, 'text': '😀'}):
            result = parser.feed(line)
        self.assertEqual(result, {'schema': 2, 'text': '😀'})

    def test_when_optional_probe_fields_change_it_should_preserve_old_and_current_reports(self):
        for implementation in (
            {'probe_version': 3, 'native_status_counts': {'accepted': 2},
             'atlas_status_counts': {}, 'atlas_fallback_counts': {}},
            {'probe_version': 3, 'native_status_counts': {'accepted': 2}},
        ):
            with self.subTest(implementation=implementation):
                expected = {'schema': 2, 'implementation_at_end': implementation}
                parser = ChunkParser()
                result = None
                for line in records(expected):
                    result = parser.feed(line)
                self.assertEqual(result, expected)

    def test_when_end_is_missing_it_should_not_return_a_result(self):
        parser = ChunkParser()
        result = None
        for line in records()[:-1]:
            result = parser.feed(line)
        self.assertIsNone(result)

    def test_when_a_chunk_is_missing_it_should_reject_the_end_marker(self):
        parser = ChunkParser()
        lines = records()
        with self.assertRaisesRegex(ValueError, 'missing chunks'):
            for line in [lines[0], *lines[2:]]:
                parser.feed(line)

    def test_when_a_chunk_is_duplicated_it_should_reject_it(self):
        parser = ChunkParser()
        lines = records()
        with self.assertRaisesRegex(ValueError, 'Duplicate chunk'):
            for line in [lines[0], lines[1], lines[1]]:
                parser.feed(line)

    def test_when_a_second_result_begins_it_should_reject_mixed_runs(self):
        parser = ChunkParser()
        line = records()[0]
        parser.feed(line)
        with self.assertRaisesRegex(ValueError, 'Duplicate result'):
            parser.feed(line)

    def test_when_a_chunk_arrives_before_begin_it_should_reject_it(self):
        with self.assertRaisesRegex(ValueError, 'outside an active result'):
            ChunkParser().feed(records()[1])

    def test_when_a_chunk_total_disagrees_it_should_reject_it(self):
        parser = ChunkParser()
        parser.feed(records()[0])
        with self.assertRaisesRegex(ValueError, 'index or total'):
            parser.feed(records()[1].replace('1/3', '1/4'))

    def test_when_a_chunk_index_is_out_of_range_it_should_reject_it(self):
        parser = ChunkParser()
        parser.feed(records()[0])
        with self.assertRaisesRegex(ValueError, 'index or total'):
            parser.feed(records()[1].replace('1/3', '0/3'))

    def test_when_logcat_truncates_a_chunk_it_should_reject_it(self):
        parser = ChunkParser()
        parser.feed(records()[0])
        with self.assertRaisesRegex(ValueError, 'payload length'):
            parser.feed(records()[1][:-1])

    def test_when_header_character_count_is_wrong_it_should_reject_it(self):
        parser = ChunkParser()
        lines = records()
        header = json.loads(lines[0].split(' ', 1)[1])
        header['characters'] += 1
        parser.feed('CONTOUR_BENCHMARK_BEGIN ' + json.dumps(header))
        with self.assertRaisesRegex(ValueError, 'payload length'):
            for line in lines[1:]:
                parser.feed(line)

    def test_when_header_uses_a_boolean_count_it_should_reject_it(self):
        with self.assertRaisesRegex(ValueError, 'Invalid chunk'):
            ChunkParser().feed('CONTOUR_BENCHMARK_BEGIN {"chunks":true,"characters":1}')

    def test_when_chunk_count_cannot_match_header_length_it_should_reject_it(self):
        with self.assertRaisesRegex(ValueError, '600-character framing'):
            ChunkParser().feed('CONTOUR_BENCHMARK_BEGIN {"chunks":2,"characters":1}')

    def test_when_result_schema_is_unsupported_it_should_reject_it(self):
        parser = ChunkParser()
        with self.assertRaisesRegex(ValueError, 'Unsupported benchmark result'):
            for line in records({'schema': 1}):
                parser.feed(line)

    def test_when_the_app_reports_an_error_it_should_reject_the_run(self):
        with self.assertRaisesRegex(ValueError, 'does not fit'):
            ChunkParser().feed('CONTOUR_BENCHMARK_ERROR workload does not fit')

    def test_when_end_arrives_before_begin_it_should_reject_it(self):
        with self.assertRaisesRegex(ValueError, 'outside an active result'):
            ChunkParser().feed('CONTOUR_BENCHMARK_END')


class OfflineRunnerTest(unittest.TestCase):
    def _run(self, complete, with_manifest=False):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            fixture = ['CONTOUR_BENCHMARK_START {}', *records()]
            if not complete:
                fixture.pop()
            script = directory / 'fake_adb.py'
            commands = directory / 'commands.jsonl'
            launched = directory / 'launched'
            script.write_text(
                '#!' + sys.executable + '\n' +
                'import json, pathlib, sys, time\n' +
                'args = sys.argv[3:]\n' +
                f'with open({str(commands)!r}, "a") as log: log.write(json.dumps(args) + "\\n")\n' +
                'if args[0] == "logcat":\n' +
                f'    while not pathlib.Path({str(launched)!r}).exists(): time.sleep(.01)\n' +
                f'    for line in {fixture!r}: print(line, flush=True)\n' +
                '    time.sleep(30)\n' +
                'elif args[:3] == ["shell", "pm", "path"]:\n' +
                '    print("package:/fake/base.apk")\n' +
                'elif args[0] == "shell" and args[1].startswith("sha256sum"):\n' +
                '    print("a" * 64 + "  /fake/base.apk")\n' +
                'elif args[:2] == ["shell", "getprop"]:\n' +
                '    print("[ro.product.model]: [Offline fixture]\\n[ro.build.version.sdk]: [33]")\n' +
                'elif args[0] == "shell" and args[1].startswith("am start"):\n' +
                f'    pathlib.Path({str(launched)!r}).touch()\n' +
                '    print("Status: ok")\n' +
                'else: print("fixture")\n'
            )
            script.chmod(0o755)
            output = directory / 'run.json'
            args = argparse.Namespace(
                output=output, adb=str(script), device='offline-fixture', label='fixture',
                activity='fixture/.MainActivity', apk=None, install=False,
                route='/?enabled=true', impeller=False, trace_skia=False,
                timeout=5 if complete else .3,
            )
            if with_manifest:
                source = directory / 'source'
                source.mkdir()
                (source / 'pubspec.yaml').write_text('name: fixture')
                args.source_manifest = directory / 'snapshot.json'
                identity = write_manifest(source, args.source_manifest, [], 'skia')
                args.source_manifest_sha256 = identity['sha256']
            with redirect_stdout(io.StringIO()):
                exit_code = collect(args)
            metadata = json.loads(output.read_text())
            invocations = [json.loads(line) for line in commands.read_text().splitlines()]
            force_stops = invocations.count(['shell', 'am', 'force-stop', 'fixture'])
            return exit_code, metadata, force_stops

    def test_when_complete_logs_arrive_it_should_save_metadata_and_stop_the_app(self):
        code, metadata, stops = self._run(True)
        self.assertEqual(
            (code, metadata['status'], metadata['before']['identity']['android_api'],
             metadata['cleanup_force_stop']['exit_code'], stops),
            (0, 'ok', '33', 0, 2),
        )

    def test_when_end_never_arrives_it_should_preserve_error_metadata_and_cleanup(self):
        code, metadata, stops = self._run(False)
        self.assertEqual(
            (code, metadata['status'], metadata['error'].startswith('TimeoutError:'),
             metadata['cleanup_force_stop']['exit_code'], stops),
            (1, 'error', True, 0, 2),
        )

    def test_when_snapshot_is_supplied_it_should_record_independent_build_source_identity(self):
        code, metadata, stops = self._run(True, with_manifest=True)
        self.assertEqual(
            (code, metadata['build_source_manifest']['file_count'],
             metadata['build_source_manifest']['build']['renderer']),
            (0, 1, 'skia'),
        )

    def test_when_snapshot_sha_disagrees_it_should_fail_before_device_access(self):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            (directory / 'pubspec.yaml').write_text('name: fixture')
            snapshot = directory / 'snapshot.json'
            write_manifest(directory, snapshot, [], 'skia')
            args = argparse.Namespace(source_manifest=snapshot, source_manifest_sha256='0' * 64)
            with self.assertRaisesRegex(ValueError, 'expected frozen file'):
                collect(args)

    def test_when_snapshot_is_missing_it_should_reject_a_pinned_sha_before_device_access(self):
        args = argparse.Namespace(source_manifest=None, source_manifest_sha256='0' * 64)
        with self.assertRaisesRegex(ValueError, 'requires --source-manifest'):
            collect(args)

    def test_when_runner_workspace_is_dirty_it_should_omit_raw_paths_and_errors(self):
        with patch('run_android.subprocess.run') as run, patch('run_android.sdk_identity', return_value={}):
            run.return_value.returncode = 0
            run.return_value.stdout = '?? /private/location\n'
            metadata = source_metadata()
        self.assertEqual(
            (metadata['head'], metadata['dirty'], '/private/location' in json.dumps(metadata), 'status' in metadata),
            (None, True, False, False),
        )


if __name__ == '__main__':
    unittest.main()
