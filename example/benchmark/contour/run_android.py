#!/usr/bin/env python3
"""Collect one reproducible Contour profile run without changing device settings."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import select
import shlex
import subprocess
import sys
import time
from typing import Any
from urllib.parse import parse_qs, urlparse

from source_manifest import load_manifest, sdk_identity


class ChunkParser:
    """Reject incomplete, repeated, truncated, or mixed benchmark results."""

    def __init__(self) -> None:
        self.expected: int | None = None
        self.characters: int | None = None
        self.chunks: dict[int, str] = {}
        self.ended = False

    def feed(self, line: str) -> dict[str, Any] | None:
        if line.startswith('CONTOUR_BENCHMARK_ERROR'):
            raise ValueError(line)
        if line.startswith('CONTOUR_BENCHMARK_BEGIN '):
            if self.expected is not None or self.ended:
                raise ValueError('Duplicate result begin marker')
            header = json.loads(line.removeprefix('CONTOUR_BENCHMARK_BEGIN '))
            if not isinstance(header, dict):
                raise ValueError('Invalid result header')
            count, characters = header.get('chunks'), header.get('characters')
            if type(count) is not int or type(characters) is not int or count < 1 or characters < 1:
                raise ValueError('Invalid chunk or character count')
            if count != (characters + 599) // 600:
                raise ValueError('Chunk count does not match 600-character framing')
            self.expected, self.characters = count, characters
        elif line.startswith('CONTOUR_BENCHMARK_CHUNK '):
            if self.expected is None or self.ended:
                raise ValueError('Chunk outside an active result')
            match = re.fullmatch(r'CONTOUR_BENCHMARK_CHUNK (\d+)/(\d+) (.*)', line)
            if match is None:
                raise ValueError('Malformed chunk record')
            index, count, payload = int(match[1]), int(match[2]), match[3]
            if count != self.expected or not 1 <= index <= count:
                raise ValueError('Inconsistent chunk index or total')
            if index in self.chunks:
                raise ValueError('Duplicate chunk index')
            expected_length = 600 if index < count else self.characters - 600 * (count - 1)
            # Dart String.length counts UTF-16 code units, including surrogate pairs.
            if len(payload.encode('utf-16-le')) // 2 != expected_length:
                raise ValueError('Truncated or malformed chunk payload length')
            self.chunks[index] = payload
        elif line == 'CONTOUR_BENCHMARK_END':
            if self.expected is None or self.ended:
                raise ValueError('End marker outside an active result')
            if set(self.chunks) != set(range(1, self.expected + 1)):
                raise ValueError('End marker arrived with missing chunks')
            text = ''.join(self.chunks[index] for index in range(1, self.expected + 1))
            if len(text.encode('utf-16-le')) // 2 != self.characters:
                raise ValueError('Reassembled character count differs from header')
            result = json.loads(text)
            if not isinstance(result, dict) or result.get('schema') != 2:
                raise ValueError('Unsupported benchmark result')
            self.ended = True
            return result
        return None


class AndroidRunner:
    """Run adb with one explicit target and bounded command durations."""

    def __init__(self, adb: str, device: str) -> None:
        self.prefix = [adb, '-s', device]

    def command(self, *args: str, timeout: float = 20, check: bool = True) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [*self.prefix, *args], capture_output=True, text=True, errors='replace', timeout=timeout, check=check,
        )

    def capture(self, *args: str, timeout: float = 8) -> dict[str, Any]:
        try:
            value = self.command(*args, timeout=timeout, check=False)
            return {'exit_code': value.returncode, 'stdout': value.stdout, 'stderr': value.stderr}
        except (OSError, subprocess.TimeoutExpired) as error:
            return {'error': str(error)}

    def metadata(self) -> dict[str, Any]:
        properties = self.capture('shell', 'getprop')
        parsed = dict(re.findall(r'^\[([^]]+)\]: \[([^]]*)\]$', properties.get('stdout', ''), re.MULTILINE))
        return {
            'identity': {
                'model': parsed.get('ro.product.model'),
                'manufacturer': parsed.get('ro.product.manufacturer'),
                'android_api': parsed.get('ro.build.version.sdk'),
                'android_release': parsed.get('ro.build.version.release'),
                'build_fingerprint': parsed.get('ro.build.fingerprint'),
                'cpu_abi': parsed.get('ro.product.cpu.abi'),
            },
            'captured_at_unix': time.time(),
            'properties': properties,
            'thermal': self.capture('shell', 'dumpsys', 'thermalservice'),
            'battery': self.capture('shell', 'dumpsys', 'battery'),
            'cpu_frequencies': self.capture('shell',
                'grep -H . /sys/devices/system/cpu/online '
                '/sys/devices/system/cpu/cpufreq/policy*/scaling_cur_freq '
                '/sys/devices/system/cpu/cpufreq/policy*/scaling_min_freq '
                '/sys/devices/system/cpu/cpufreq/policy*/scaling_max_freq '
                '/sys/devices/system/cpu/cpufreq/policy*/cpuinfo_min_freq '
                '/sys/devices/system/cpu/cpufreq/policy*/cpuinfo_max_freq '
                '/sys/devices/system/cpu/cpufreq/policy*/related_cpus '
                '/sys/devices/system/cpu/cpufreq/policy*/scaling_governor'),
            'screen_size': self.capture('shell', 'wm', 'size'),
            'screen_density': self.capture('shell', 'wm', 'density'),
        }

    def installed_apks(self, package: str) -> list[dict[str, Any]]:
        paths = self.command('shell', 'pm', 'path', package).stdout.splitlines()
        result = []
        for line in paths:
            if not line.startswith('package:'):
                continue
            path = line.removeprefix('package:').strip()
            fingerprint = self.capture('shell', f'sha256sum {shlex.quote(path)}')
            match = re.match(r'^([0-9a-fA-F]{64})\s', fingerprint.get('stdout', ''))
            result.append({'path': path, 'sha256': match[1].lower() if match else None, 'command': fingerprint})
        if not result:
            raise RuntimeError(f'No APK installed for {package}')
        return result


def source_metadata() -> dict[str, Any]:
    root = Path(__file__).resolve().parents[3]
    result: dict[str, Any] = {
        'scope': 'Runner workspace only; does not identify the installed APK source.',
        'runner_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    }
    for key, args in [('head', ['rev-parse', 'HEAD']), ('status', ['status', '--short'])]:
        try:
            command = subprocess.run(
                ['git', '-C', str(root), *args], capture_output=True,
                text=True, errors='replace', check=False, timeout=10,
            )
            value = command.stdout.strip()
            if key == 'head':
                result['head'] = value if command.returncode == 0 and re.fullmatch(r'[0-9a-f]{40,64}', value) else None
            else:
                result['dirty'] = bool(value) if command.returncode == 0 else None
        except (OSError, subprocess.TimeoutExpired):
            result['head' if key == 'head' else 'dirty'] = None
    try:
        result['sdk'] = sdk_identity(root)
    except (OSError, ValueError):
        result['sdk'] = {}
    return result


def stop_logcat(process: subprocess.Popen[bytes] | None) -> None:
    if process is None:
        return
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)
    if process.stdout is not None:
        process.stdout.close()


def collect(args: argparse.Namespace) -> int:
    manifest_path = getattr(args, 'source_manifest', None)
    manifest_sha = getattr(args, 'source_manifest_sha256', None)
    if manifest_sha is not None and manifest_path is None:
        raise ValueError('--source-manifest-sha256 requires --source-manifest')
    manifest = load_manifest(manifest_path, manifest_sha) if manifest_path is not None else None
    output = args.output.expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    log_path = output.with_suffix('.log')
    if output.exists() or log_path.exists():
        raise ValueError('Output JSON or raw log already exists; use a new output path')
    runner = AndroidRunner(args.adb, args.device)
    package = args.activity.split('/')[0]
    metadata: dict[str, Any] = {
        'label': args.label, 'device_serial': args.device, 'route': args.route,
        'activity': args.activity, 'renderer_requested': 'impeller' if args.impeller else 'skia',
        'trace_skia': args.trace_skia, 'started_at_unix': time.time(), 'source': source_metadata(),
        'status': 'error', 'result': None,
    }
    if manifest is not None:
        metadata['build_source_manifest'] = manifest
    process = None
    did_stop = False
    started = time.monotonic()
    exit_code = 1
    try:
        runner.command('get-state')
        runner.command('shell', 'am', 'force-stop', package)
        did_stop = True
        if args.apk is not None:
            apk = args.apk.expanduser().resolve(strict=True)
            metadata['local_apk'] = {'name': apk.name, 'sha256': hashlib.sha256(apk.read_bytes()).hexdigest()}
            if args.install:
                runner.command('install', '-r', str(apk), timeout=180)
        metadata['installed_apks'] = runner.installed_apks(package)
        installed_hashes = {apk['sha256'] for apk in metadata['installed_apks'] if apk['sha256']}
        if args.apk is not None and installed_hashes and metadata['local_apk']['sha256'] not in installed_hashes:
            raise ValueError('Local APK hash does not match any installed APK; use --install or the correct artifact')
        if args.apk is None and not installed_hashes:
            raise ValueError('Cannot hash the installed APK; provide --apk to record the artifact explicitly')
        metadata['before'] = runner.metadata()
        # Do not clear the global device log. The fresh START marker gates parsing.
        process = subprocess.Popen(
            [*runner.prefix, 'logcat', '-v', 'raw', '-T', '1', '-s', 'flutter'],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=0,
        )
        launch = [
            'am', 'start', '-W', '-n', args.activity,
            '--ez', 'enable-impeller', str(args.impeller).lower(), '--es', 'route', args.route,
        ]
        if args.trace_skia:
            launch += ['--ez', 'trace-skia', 'true']
        capture_started = time.monotonic()
        metadata['launch'] = runner.command('shell', shlex.join(launch), timeout=min(args.timeout, 60)).stdout
        if re.search(r'(?im)^\s*(?:Error|Exception|SecurityException)\b', metadata['launch']):
            raise RuntimeError(f'Android launch failed: {metadata["launch"]}')
        parser = ChunkParser()
        pending = b''
        workload_started = False
        with log_path.open('wb') as log:
            while time.monotonic() - capture_started < args.timeout:
                assert process.stdout is not None
                if not select.select([process.stdout], [], [], min(1, args.timeout))[0]:
                    if process.poll() is not None:
                        raise RuntimeError(f'logcat exited with code {process.returncode}')
                    continue
                block = os.read(process.stdout.fileno(), 65536)
                if not block:
                    raise RuntimeError('logcat ended before a complete benchmark result')
                log.write(block)
                log.flush()
                pending += block
                while b'\n' in pending:
                    raw, pending = pending.split(b'\n', 1)
                    line = raw.rstrip(b'\r').decode('utf-8', errors='replace')
                    if line.startswith('CONTOUR_BENCHMARK_START '):
                        if workload_started:
                            raise ValueError('Multiple workload starts in one capture')
                        workload_started = True
                    if line.startswith('CONTOUR_BENCHMARK_ERROR'):
                        raise ValueError(line)
                    if not workload_started:
                        continue
                    result = parser.feed(line)
                    if result is not None:
                        metadata['result'] = result
                        metadata['affinity_actual_final'] = result.get('affinity_at_end')
                        metadata['capture_wall_seconds'] = time.monotonic() - capture_started
                        if 'cpumask' in parse_qs(urlparse(args.route).query):
                            affinity = result.get('affinity_at_end')
                            if not isinstance(affinity, dict) or affinity.get('all_threads_restricted') is not True:
                                raise ValueError('Requested CPU affinity was not verified for every final thread')
                        metadata['status'] = 'ok'
                        exit_code = 0
                        break
                if metadata['result'] is not None:
                    break
            else:
                raise TimeoutError(f'No complete result within {args.timeout:g} seconds (END required)')
    except KeyboardInterrupt:
        metadata['error'] = 'Interrupted by user'
        exit_code = 130
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        metadata['error'] = f'{type(error).__name__}: {error}'
    finally:
        try:
            stop_logcat(process)
        except (OSError, subprocess.SubprocessError) as error:
            metadata['cleanup_logcat_error'] = str(error)
        if did_stop:
            try:
                metadata['after'] = runner.metadata()
            finally:
                metadata['cleanup_force_stop'] = runner.capture('shell', 'am', 'force-stop', package)
        metadata['wall_seconds'] = time.monotonic() - started
        output.write_text(json.dumps(metadata, indent=2) + '\n')
    print(json.dumps({'label': args.label, 'status': metadata['status'], 'output': str(output), 'error': metadata.get('error')}))
    return exit_code


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adb', default='adb', help='Path to adb (default: PATH)')
    parser.add_argument('--device', required=True, help='Explicit adb device serial')
    parser.add_argument('--apk', type=Path, help='Local APK to fingerprint and optionally install')
    parser.add_argument('--install', action='store_true', help='Install --apk before running')
    parser.add_argument('--source-manifest', type=Path, help='Frozen pre-build source manifest (independent of APK identity)')
    parser.add_argument('--source-manifest-sha256', help='Expected SHA-256 of the exact frozen manifest file')
    parser.add_argument('--label', required=True, help='Human-readable variant/run label')
    parser.add_argument('--route', default='/?enabled=true&workload=combined&count=20&delayMs=5000')
    parser.add_argument('--output', required=True, type=Path, help='New .json metadata output; sibling .log is raw logcat')
    parser.add_argument('--activity', default='dev.ventairy.oh_my_flutter_example/.MainActivity')
    parser.add_argument('--timeout', type=float, default=240, help='Maximum capture seconds, including launch/delay')
    parser.add_argument('--impeller', action='store_true', help='Request Impeller instead of the default Skia')
    parser.add_argument('--trace-skia', action='store_true', help='Enable engine Skia trace events for a separate diagnostic run')
    args = parser.parse_args()
    if args.install and args.apk is None:
        parser.error('--install requires --apk')
    if args.source_manifest_sha256 is not None and args.source_manifest is None:
        parser.error('--source-manifest-sha256 requires --source-manifest')
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    if args.output.suffix != '.json':
        parser.error('--output must end in .json')
    try:
        return collect(args)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    return 2


if __name__ == '__main__':
    sys.exit(main())
