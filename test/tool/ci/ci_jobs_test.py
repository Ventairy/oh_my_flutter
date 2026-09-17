import copy
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tool.ci.ci_jobs import CiJobs


class CiJobsTest(unittest.TestCase):
    def test_when_paths_change_it_should_select_their_consumers(self):
        all_jobs = set(CiJobs.optional)
        cases = {
            'README.md': set(), 'doc/widgets/motion.md': set(),
            '.github/ISSUE_TEMPLATE/bug_report.yml': set(),
            'test/widgets/motion_test.dart': set(),
            'test/widgets/goldens/ci/motion.png': set(),
            'lib/src/widgets/motion.dart': all_jobs,
            'lib/src/gen/country.g.dart': all_jobs,
            'pubspec.yaml': all_jobs, 'example/pubspec.lock': all_jobs,
            'tool/setup_ci_fvm.sh': all_jobs, '.fvmrc': all_jobs,
            'test/tool/ci/ci_jobs_test.py': all_jobs,
            'test/flutter_test_config.dart': {'macos-native', 'windows-native'},
            'test/support/test_configuration.dart': {'macos-native', 'windows-native'},
            '.github/workflows/ci.yml': all_jobs,
            'example/integration_test/country_names_test.dart': all_jobs,
            'new_input.json': all_jobs,
            'test/fixtures/country_iso_3166_1.csv': {'macos-native', 'windows-native'},
            **{path: set(jobs) for path, jobs in CiJobs.desktop_tests.items()},
        }
        for platform in CiJobs.platforms:
            for prefix in (platform, f'example/{platform}'):
                cases[f'{prefix}/native.g.source'] = {f'{platform}-native', 'macos-generation'}
        for path, expected in cases.items():
            with self.subTest(path=path):
                self.assertEqual(CiJobs.select([path], 'pull_request'), expected)

    def test_when_diff_is_unavailable_it_should_select_every_job(self):
        self.assertEqual(CiJobs.select(None, 'pull_request'), set(CiJobs.optional))

    def test_when_not_a_pr_it_should_select_every_job(self):
        for event in ('push', 'workflow_dispatch'):
            with self.subTest(event=event):
                self.assertEqual(CiJobs.select(['README.md'], event), set(CiJobs.optional))

    def test_when_git_fails_it_should_report_an_unavailable_diff(self):
        with patch('subprocess.check_output', side_effect=subprocess.CalledProcessError(1, 'git')):
            self.assertIsNone(CiJobs.changed_paths('base', 'head'))

    def test_when_a_file_moves_or_is_deleted_it_should_include_both_affected_paths(self):
        with tempfile.TemporaryDirectory() as directory:
            def git(*args):
                return subprocess.check_output(['git', '-C', directory, *args], stderr=subprocess.PIPE).decode().strip()
            git('init')
            git('config', 'user.email', 'test@example.invalid')
            git('config', 'user.name', 'CI test')
            root = Path(directory)
            (root / 'android').mkdir()
            (root / 'android/old file').write_text('native')
            (root / 'windows').mkdir()
            (root / 'windows/deleted').write_text('removed')
            git('add', '.')
            git('commit', '-m', 'base')
            base = git('rev-parse', 'HEAD')
            (root / 'android/old file').rename(root / 'moved.md')
            (root / 'windows/deleted').unlink()
            git('add', '-A')
            git('commit', '-m', 'change')
            with patch.dict(os.environ, GIT_DIR=str(root / '.git'), GIT_WORK_TREE=str(root)):
                self.assertEqual(set(CiJobs.changed_paths(base, 'HEAD')),
                                 {'android/old file', 'moved.md', 'windows/deleted'})

    def test_when_gate_results_change_it_should_only_accept_expected_skips(self):
        needs = {job: {'result': 'success'} for job in ('changes', 'quality', 'minimum-dependencies', *CiJobs.optional)}
        needs['changes']['outputs'] = {job: 'true' for job in CiJobs.optional}
        cases = [('pull_request', None, None, None, []), ('push', None, None, None, [])]
        for result in ('failure', 'cancelled', 'skipped'):
            cases.append(('pull_request', 'android-native', 'true', result, ['android-native']))
        for result in ('failure', 'cancelled'):
            cases.append(('pull_request', 'android-native', 'false', result, ['android-native']))
        cases.extend([
            ('pull_request', 'android-native', 'false', 'skipped', []),
            ('push', 'android-native', 'false', 'skipped', ['android-native']),
            ('workflow_dispatch', 'android-native', 'false', 'skipped', ['android-native']),
            ('pull_request', 'android-native', '', 'success', ['android-native']),
        ])
        for event, job, selection, result, expected in cases:
            with self.subTest(event=event, selection=selection, result=result):
                value = copy.deepcopy(needs)
                if job:
                    value[job]['result'] = result
                    value['changes']['outputs'][job] = selection
                self.assertEqual(CiJobs.failures(value, event), expected)

    def test_when_a_mandatory_job_does_not_succeed_it_should_fail_the_gate(self):
        for job in ('changes', 'quality', 'minimum-dependencies'):
            for result in ('skipped', 'failure', 'cancelled'):
                needs = {key: {'result': 'success'} for key in ('changes', 'quality', 'minimum-dependencies', *CiJobs.optional)}
                needs['changes']['outputs'] = {key: 'true' for key in CiJobs.optional}
                needs[job]['result'] = result
                with self.subTest(job=job, result=result):
                    self.assertEqual(CiJobs.failures(needs, 'pull_request'), [job])


if __name__ == '__main__':
    unittest.main()
