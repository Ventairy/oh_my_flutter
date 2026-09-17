"""Conservative PR selection and the Required gate, using only the standard library."""
import json
import os
from pathlib import Path
import subprocess
import sys


class CiJobs:
    platforms = ('android', 'ios', 'macos', 'linux', 'windows')
    optional = tuple(f'{platform}-native' for platform in platforms) + ('macos-generation',)
    desktop_tests = {
        'test/country/country_test.dart': ('macos-native', 'windows-native'),
        'test/country/country_names_io_test.dart': ('macos-native', 'windows-native'),
        'test/country/country_names_apple_test.dart': ('macos-native',),
        'test/country/country_names_windows_test.dart': ('windows-native',),
        'test/device/device_location/apple_device_location_platform_test.dart': ('macos-native',),
    }

    @classmethod
    def select(cls, paths, event):
        if event != 'pull_request' or paths is None:
            return set(cls.optional)
        selected = set()
        for path in paths:
            # Build inputs take precedence over documentation/test exemptions.
            if Path(path).name in ('pubspec.yaml', 'pubspec.lock', 'pubspec_overrides.yaml'):
                return set(cls.optional)
            if path.startswith('test/tool/ci/'):
                return set(cls.optional)
            if path == 'test/flutter_test_config.dart' or path.startswith('test/support/'):
                selected.update(('macos-native', 'windows-native'))
            elif path in cls.desktop_tests:
                selected.update(cls.desktop_tests[path])
            elif path.startswith('test/fixtures/country'):
                selected.update(('macos-native', 'windows-native'))
            elif path.startswith(('doc/', '.github/ISSUE_TEMPLATE/')) or path.endswith('.md') or path == '.github/pull_request_template.md':
                continue
            elif any(path.startswith((f'{p}/', f'example/{p}/')) for p in cls.platforms):
                for platform in cls.platforms:
                    if path.startswith((f'{platform}/', f'example/{platform}/')):
                        selected.update((f'{platform}-native', 'macos-generation'))
            elif path.startswith(('test/', 'example/test/')):
                continue
            else:
                # Shared production, integration tests, CI/tooling, and unknown
                # inputs can affect every build. New paths fail closed.
                return set(cls.optional)
        return selected

    @staticmethod
    def changed_paths(base, head):
        if not base or not head:
            return None
        try:
            merge_base = subprocess.check_output(
                ['git', 'merge-base', base, head], stderr=subprocess.PIPE,
            ).decode().strip()
            # --no-renames reports a rename as deletion + addition, preserving
            # both affected paths. NUL delimiters handle spaces and newlines.
            output = subprocess.check_output(
                ['git', 'diff', '--name-only', '--no-renames', '-z', merge_base, head],
                stderr=subprocess.PIPE,
            )
            return [os.fsdecode(path) for path in output.split(b'\0') if path]
        except (OSError, subprocess.CalledProcessError):
            print('Diff unavailable; selecting every job.', file=sys.stderr)
            return None

    @classmethod
    def failures(cls, needs, event):
        failures = []
        for job in ('changes', 'quality', 'minimum-dependencies'):
            if needs.get(job, {}).get('result') != 'success':
                failures.append(job)
        outputs = needs.get('changes', {}).get('outputs', {})
        for job in cls.optional:
            selection = outputs.get(job)
            result = needs.get(job, {}).get('result')
            if selection not in ('true', 'false'):
                failures.append(job)
            elif event != 'pull_request' and selection != 'true':
                failures.append(job)
            elif selection == 'true' and result != 'success':
                failures.append(job)
            elif selection == 'false' and result not in ('success', 'skipped'):
                failures.append(job)
        return failures

    @classmethod
    def main(cls):
        event = os.environ['GITHUB_EVENT_NAME']
        if sys.argv[1:] == ['required']:
            failures = cls.failures(json.loads(os.environ['CI_NEEDS']), event)
            if failures:
                raise SystemExit('Required checks failed: ' + ', '.join(failures))
            print('Every selected check succeeded.')
            return
        paths = cls.changed_paths(os.environ.get('BASE_SHA'), os.environ.get('HEAD_SHA')) if event == 'pull_request' else None
        selected = cls.select(paths, event)
        with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
            for job in cls.optional:
                output.write(f'{job}={str(job in selected).lower()}\n')
        print('Selected jobs: ' + ', '.join(sorted(selected)))


if __name__ == '__main__':
    CiJobs.main()
