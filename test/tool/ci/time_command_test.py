from pathlib import Path
import subprocess
import unittest


class TimeCommandTest(unittest.TestCase):
    def test_when_a_command_finishes_it_should_preserve_its_exit_status(self):
        for status in (0, 7):
            with self.subTest(status=status):
                result = subprocess.run(
                    ['bash', str(Path('tool/ci/time_command.sh')), 'Example',
                     'bash', '-c', f'exit {status}'], capture_output=True, text=True,
                )
                self.assertEqual((result.returncode, 'Example:' in result.stdout), (status, True))


if __name__ == '__main__':
    unittest.main()
