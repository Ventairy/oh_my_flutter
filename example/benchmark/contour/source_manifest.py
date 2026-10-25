#!/usr/bin/env python3
"""Freeze or verify allowlisted Contour benchmark build inputs without building."""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
from typing import Any

TREE_PREFIXES = (
    'lib/', 'hook/', 'src/', 'shaders/', 'assets/', 'android/src/',
    'example/benchmark/contour/', 'example/android/app/src/',
    'example/android/gradle/wrapper/',
)
EXACT_FILES = {
    'pubspec.yaml', 'pubspec.lock', '.fvmrc', 'example/pubspec.yaml', 'example/pubspec.lock',
    'android/build.gradle', 'android/build.gradle.kts',
    'example/android/app/build.gradle', 'example/android/app/build.gradle.kts',
    'example/android/build.gradle', 'example/android/build.gradle.kts',
    'example/android/settings.gradle', 'example/android/settings.gradle.kts',
    'example/android/gradle.properties',
}
SDK_KEYS = {'frameworkVersion', 'frameworkRevision', 'engineRevision', 'dartSdkVersion'}


def validate_sdk(data: Any) -> dict[str, str]:
    if not isinstance(data, dict) or not set(data).issubset(SDK_KEYS):
        raise ValueError('Invalid SDK identity fields')
    for key, value in data.items():
        pattern = r'[0-9a-f]{7,64}' if key.endswith('Revision') else r'[0-9][A-Za-z0-9._+-]{0,79}'
        if not isinstance(value, str) or re.fullmatch(pattern, value) is None:
            raise ValueError('Invalid SDK identity value')
    return data


def validate_defines(data: Any) -> dict[str, str]:
    if not isinstance(data, dict):
        raise ValueError('Invalid build defines')
    for key, value in data.items():
        if (not isinstance(key, str) or re.fullmatch(r'CONTOUR_[A-Z0-9_]{1,80}', key) is None
                or not isinstance(value, str) or re.fullmatch(r'[A-Za-z0-9_:+-][A-Za-z0-9_.:+-]{0,79}', value) is None):
            raise ValueError('Defines must be CONTOUR_NAME=value with a path-free scalar value')
    return data


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=True).encode()


def allowed_path(value: str) -> bool:
    path = PurePosixPath(value)
    return (
        bool(value) and not path.is_absolute() and '\\' not in value
        and all(part not in ('.', '..') for part in value.split('/'))
        and (value in EXACT_FILES or value.startswith(TREE_PREFIXES))
        # Generated reports are not APK inputs and can contain this manifest's
        # digest. Including them would create a circular source identity.
        and not value.startswith('example/benchmark/contour/results/')
        and not any(part in ('__pycache__', '.dart_tool', 'build', '.gradle', '.cxx') for part in path.parts)
        and path.suffix not in ('.pyc', '.apk', '.log')
    )


def sdk_identity(root: Path) -> dict[str, Any]:
    path = root / '.fvm/flutter_sdk/bin/cache/flutter.version.json'
    if not path.is_file():
        return {}
    data = json.loads(path.read_text())
    return validate_sdk({key: data[key] for key in (
        'frameworkVersion', 'frameworkRevision', 'engineRevision', 'dartSdkVersion',
    ) if key in data})


def scan_files(root: Path) -> list[dict[str, Any]]:
    root = root.resolve(strict=True)
    candidates = {root / name for name in EXACT_FILES}
    for prefix in TREE_PREFIXES:
        directory = root / prefix
        if directory.is_dir():
            candidates.update(directory.rglob('*'))
    rows = []
    for path in sorted(candidates):
        relative = path.relative_to(root).as_posix()
        if not path.is_file() or not allowed_path(relative):
            continue
        if not path.resolve().is_relative_to(root):
            raise ValueError(f'Build input escapes source tree: {relative}')
        content = path.read_bytes()
        rows.append({'path': relative, 'sha256': hashlib.sha256(content).hexdigest(), 'bytes': len(content)})
    # Path ordering compares components; the serialized inventory is ordered by
    # complete POSIX strings, including punctuation before directory separators.
    rows.sort(key=lambda row: row['path'])
    return rows


def validate_manifest(data: Any) -> dict[str, Any]:
    if not isinstance(data, dict) or data.get('schema') != 1 or data.get('kind') != 'contour_benchmark_build_source':
        raise ValueError('Unsupported source manifest')
    if set(data) != {'schema', 'kind', 'created_at_utc', 'base_head', 'sdk', 'build', 'files_sha256', 'files'}:
        raise ValueError('Unexpected source manifest metadata')
    if data['base_head'] is not None and (
        not isinstance(data['base_head'], str) or re.fullmatch(r'[0-9a-f]{40,64}', data['base_head']) is None
    ):
        raise ValueError('Invalid source base revision')
    if not isinstance(data['created_at_utc'], str) or re.fullmatch(
        r'\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,6})?\+00:00', data['created_at_utc'],
    ) is None:
        raise ValueError('Invalid source snapshot timestamp')
    validate_sdk(data['sdk'])
    build = data['build']
    if (not isinstance(build, dict) or set(build) != {'mode', 'platform', 'renderer', 'target', 'defines'}
            or build['mode'] != 'profile' or build['platform'] != 'android-arm64'
            or build['renderer'] not in ('skia', 'impeller')
            or build['target'] != 'benchmark/contour/main.dart'):
        raise ValueError('Invalid benchmark build identity')
    validate_defines(build['defines'])
    rows = data.get('files')
    if not isinstance(rows, list) or not rows:
        raise ValueError('Source manifest has no file hashes')
    paths = []
    for row in rows:
        if not isinstance(row, dict) or set(row) != {'path', 'sha256', 'bytes'}:
            raise ValueError('Invalid source file record')
        if not isinstance(row['path'], str) or not allowed_path(row['path']):
            raise ValueError('Source manifest contains a non-allowlisted path')
        if not isinstance(row['sha256'], str) or re.fullmatch('[0-9a-f]{64}', row['sha256']) is None:
            raise ValueError('Invalid source file SHA-256')
        if type(row['bytes']) is not int or row['bytes'] < 0:
            raise ValueError('Invalid source file length')
        paths.append(row['path'])
    if paths != sorted(set(paths)):
        raise ValueError('Source file records must be sorted and unique')
    actual = hashlib.sha256(canonical_bytes(rows)).hexdigest()
    if data.get('files_sha256') != actual:
        raise ValueError('Source manifest file-list digest mismatch')
    return data


def load_manifest(path: Path, expected_sha256: str | None = None) -> dict[str, Any]:
    if expected_sha256 is not None and re.fullmatch(r'[0-9a-fA-F]{64}', expected_sha256) is None:
        raise ValueError('Expected source manifest SHA-256 must contain 64 hexadecimal characters')
    raw = path.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    if expected_sha256 is not None and digest != expected_sha256.lower():
        raise ValueError('Source manifest SHA-256 does not match the expected frozen file')
    data = validate_manifest(json.loads(raw))
    # Do not copy arbitrary caller metadata into public result provenance.
    return {
        'sha256': digest,
        'files_sha256': data['files_sha256'],
        'file_count': len(data['files']),
        'base_head': data.get('base_head'),
        'sdk': data.get('sdk', {}),
        'build': data.get('build', {}),
        'binary_linkage': 'Caller-supplied build-input snapshot; APK SHA is recorded independently.',
    }


def create_manifest(root: Path, defines: list[str], renderer: str) -> dict[str, Any]:
    values = {}
    for item in defines:
        name, separator, value = item.partition('=')
        if not separator:
            raise ValueError('Defines must be CONTOUR_NAME=value with a path-free scalar value')
        if name in values:
            raise ValueError('Duplicate build define')
        values[name] = value
    validate_defines(values)
    files = scan_files(root)
    revision = subprocess.run(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True, capture_output=True, check=False, timeout=10)
    return validate_manifest({
        'schema': 1, 'kind': 'contour_benchmark_build_source',
        'created_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'base_head': revision.stdout.strip() if revision.returncode == 0 else None,
        'sdk': sdk_identity(root),
        'build': {'mode': 'profile', 'platform': 'android-arm64', 'renderer': renderer,
                  'target': 'benchmark/contour/main.dart', 'defines': dict(sorted(values.items()))},
        'files_sha256': hashlib.sha256(canonical_bytes(files)).hexdigest(), 'files': files,
    })


def verify_manifest(root: Path, path: Path) -> dict[str, Any]:
    data = validate_manifest(json.loads(path.read_bytes()))
    if scan_files(root) != data['files'] or sdk_identity(root) != data['sdk']:
        raise ValueError('Allowlisted source inputs or SDK changed since the snapshot')
    return load_manifest(path)


def write_manifest(root: Path, output: Path, defines: list[str], renderer: str) -> dict[str, Any]:
    root = root.resolve(strict=True)
    resolved = output.expanduser().resolve()
    if resolved.is_relative_to(root) and allowed_path(resolved.relative_to(root).as_posix()):
        raise ValueError('Source manifest output must be outside the scanned build inputs')
    data = create_manifest(root, defines, renderer)
    resolved.parent.mkdir(parents=True, exist_ok=True)
    with resolved.open('x') as stream:
        stream.write(json.dumps(data, indent=2) + '\n')
    return load_manifest(resolved)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument('--output', type=Path, help='New immutable JSON snapshot, created before building')
    parser.add_argument('--verify', type=Path, help='Verify a frozen snapshot still matches this source tree after building')
    parser.add_argument('--define', action='append', default=[], help='Explicit CONTOUR_NAME=value build define; repeat as needed')
    parser.add_argument('--renderer', choices=['skia', 'impeller'], default='skia')
    args = parser.parse_args()
    if (args.output is None) == (args.verify is None):
        parser.error('Choose exactly one of --output or --verify')
    root = args.root.expanduser().resolve(strict=True)
    try:
        if args.verify:
            print(json.dumps({'verified': True, **verify_manifest(root, args.verify)}))
        else:
            print(json.dumps(write_manifest(root, args.output, args.define, args.renderer)))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        parser.error(str(error))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
