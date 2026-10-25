"""Offline provenance checks; never builds or accesses an Android device."""

import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from source_manifest import (
    canonical_bytes, create_manifest, load_manifest, validate_manifest,
    verify_manifest, write_manifest,
)


class SourceManifestTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / 'source'
        (self.root / 'lib').mkdir(parents=True)
        (self.root / 'lib/contour.dart').write_text('class Contour {}')
        (self.root / 'pubspec.yaml').write_text('name: fixture')
        self.output = Path(self.temporary.name) / 'frozen.json'

    def create(self):
        write_manifest(self.root, self.output, ['CONTOUR_COUNT=40'], 'skia')
        return json.loads(self.output.read_text())

    def test_when_files_and_directories_share_a_prefix_it_should_sort_relative_path_strings(self):
        (self.root / 'lib/foo').mkdir()
        (self.root / 'lib/foo.dart').write_text('class Foo {}')
        (self.root / 'lib/foo/part.dart').write_text('part of Foo;')
        self.assertEqual([row['path'] for row in self.create()['files']], [
            'lib/contour.dart', 'lib/foo.dart', 'lib/foo/part.dart', 'pubspec.yaml',
        ])

    def test_when_scanning_the_real_repository_it_should_produce_a_valid_canonical_inventory(self):
        root = Path(__file__).resolve().parents[3]
        data = create_manifest(root, [], 'skia')
        self.assertEqual(validate_manifest(data)['files_sha256'], data['files_sha256'])

    def test_when_snapshot_matches_it_should_verify_unchanged_inputs(self):
        self.create()
        self.assertEqual(verify_manifest(self.root, self.output)['file_count'], 2)

    def test_when_generated_reports_change_it_should_preserve_the_frozen_inventory(self):
        results = self.root / 'example/benchmark/contour/results'
        results.mkdir(parents=True)
        (results / 'report.md').write_text('draft')
        self.create()
        expected = verify_manifest(self.root, self.output)
        (results / 'report.md').write_text('final report containing the manifest digest')
        (results / 'results.json').write_text('{"result":1}')
        (results / 'source-manifest.json').write_bytes(self.output.read_bytes())
        self.assertEqual(verify_manifest(self.root, self.output), expected)

    def test_when_source_changes_it_should_reject_the_snapshot(self):
        self.create()
        (self.root / 'lib/contour.dart').write_text('changed')
        with self.assertRaisesRegex(ValueError, 'changed since'):
            verify_manifest(self.root, self.output)

    def test_when_new_source_is_added_it_should_reject_the_snapshot(self):
        self.create()
        (self.root / 'lib/new.dart').touch()
        with self.assertRaisesRegex(ValueError, 'changed since'):
            verify_manifest(self.root, self.output)

    def test_when_sdk_changes_it_should_reject_the_snapshot(self):
        self.create()
        version = self.root / '.fvm/flutter_sdk/bin/cache/flutter.version.json'
        version.parent.mkdir(parents=True)
        version.write_text('{"frameworkVersion":"3.47.1"}')
        with self.assertRaisesRegex(ValueError, 'SDK changed'):
            verify_manifest(self.root, self.output)

    def test_when_sdk_has_unrelated_metadata_it_should_include_only_identity_fields(self):
        version = self.root / '.fvm/flutter_sdk/bin/cache/flutter.version.json'
        version.parent.mkdir(parents=True)
        version.write_text('{"frameworkVersion":"3.47.1","repositoryUrl":"/private/location"}')
        self.assertEqual(self.create()['sdk'], {'frameworkVersion': '3.47.1'})

    def test_when_digest_is_pinned_it_should_match_the_exact_file(self):
        self.create()
        expected = hashlib.sha256(self.output.read_bytes()).hexdigest()
        self.assertEqual(load_manifest(self.output, expected)['sha256'], expected)

    def test_when_expected_digest_disagrees_it_should_reject_it(self):
        self.create()
        with self.assertRaisesRegex(ValueError, 'expected frozen file'):
            load_manifest(self.output, '0' * 64)

    def test_when_expected_digest_is_not_a_hash_it_should_reject_it(self):
        self.create()
        with self.assertRaisesRegex(ValueError, '64 hexadecimal'):
            load_manifest(self.output, '/private/local/path')

    def test_when_file_digest_is_modified_it_should_reject_it(self):
        data = self.create()
        data['files'][0]['sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'file-list digest'):
            validate_manifest(data)

    def test_when_path_is_not_allowlisted_it_should_reject_it(self):
        data = self.create()
        data['files'][0]['path'] = '../private/secret'
        data['files_sha256'] = hashlib.sha256(canonical_bytes(data['files'])).hexdigest()
        with self.assertRaisesRegex(ValueError, 'non-allowlisted'):
            validate_manifest(data)

    def test_when_snapshot_output_would_hash_itself_it_should_reject_it(self):
        with self.assertRaisesRegex(ValueError, 'outside the scanned'):
            write_manifest(self.root, self.root / 'lib/frozen.json', [], 'skia')

    def test_when_output_already_exists_it_should_preserve_the_frozen_file(self):
        self.create()
        with self.assertRaises(FileExistsError):
            write_manifest(self.root, self.output, [], 'skia')

    def test_when_metadata_contains_paths_it_should_reject_the_injection(self):
        base = self.create()
        changes = [
            {'unexpected': '/private/location'},
            {'base_head': '/private/location'},
            {'sdk': {'frameworkVersion': '/private/location'}},
            {'sdk': {'repositoryUrl': '/private/location'}},
            {'build': {**base['build'], 'target': '/private/location'}},
            {'build': {**base['build'], 'defines': {'CONTOUR_FLAG': '/private/location'}}},
            {'build': {**base['build'], 'localPath': '/private/location'}},
        ]
        for change in changes:
            with self.subTest(change=change), self.assertRaises(ValueError):
                validate_manifest({**copy.deepcopy(base), **change})

    def test_when_source_symlink_escapes_tree_it_should_reject_it(self):
        (self.root / 'lib/escape.dart').symlink_to(Path(self.temporary.name) / 'private.dart')
        (Path(self.temporary.name) / 'private.dart').write_text('private')
        with self.assertRaisesRegex(ValueError, 'escapes source tree'):
            create_manifest(self.root, [], 'skia')

    def test_when_loaded_for_results_it_should_omit_input_paths_and_snapshot_timestamp(self):
        self.create()
        self.assertEqual(
            set(load_manifest(self.output)),
            {'sha256', 'files_sha256', 'file_count', 'base_head', 'sdk', 'build', 'binary_linkage'},
        )

    def test_when_git_output_is_not_a_revision_it_should_reject_it(self):
        with patch('source_manifest.subprocess.run') as run:
            run.return_value.returncode = 0
            run.return_value.stdout = '/private/location'
            with self.assertRaisesRegex(ValueError, 'base revision'):
                create_manifest(self.root, [], 'skia')


if __name__ == '__main__':
    unittest.main()
