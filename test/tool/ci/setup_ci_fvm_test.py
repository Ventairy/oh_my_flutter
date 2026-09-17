"""Regression coverage for the CI SDK bootstrap, without downloading an SDK."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class SetupCiFvmTest(unittest.TestCase):
    def test_when_bootstrapping_it_should_export_the_registered_sdk_cache(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            (root / '.fvmrc').write_text('{"flutter":"3.47.1"}')
            for package in ('example', 'tool/country_bindings', 'tool/device_location_bindings'):
                (root / package).mkdir(parents=True)
            binary = root / 'bin'
            binary.mkdir()
            sdk = root / 'sdk'
            (sdk / 'bin').mkdir(parents=True)
            for name, content in {
                'dart': '#!/bin/sh\nif [ "$3" = list ]; then echo "fvm 4.3.0"; fi\n',
                'fvm': '#!/bin/sh\ntest -e "$FVM_CACHE_PATH/versions/3.47.1/bin/flutter" || exit 1\necho "$PWD" >> "$SDK_CALLS"\n',
            }.items():
                path = binary / name
                path.write_text(content)
                path.chmod(0o755)
            flutter = sdk / 'bin/flutter'
            flutter.write_text('#!/bin/sh\necho \'{"frameworkVersion":"3.47.1"}\'\n')
            flutter.chmod(0o755)
            environment_file = root / 'environment'
            env = dict(os.environ, PATH=f'{binary}:{os.environ["PATH"]}',
                       FLUTTER_ROOT=str(sdk), PUB_CACHE=str(root / 'pub'),
                       GITHUB_ENV=str(environment_file), GITHUB_PATH=str(root / 'path'),
                       RUNNER_OS='Linux', SDK_CALLS=str(root / 'calls'))
            env.pop('FVM_CACHE_PATH', None)
            subprocess.run(['bash', str(Path('tool/setup_ci_fvm.sh').resolve())],
                           cwd=root, env=env, check=True, capture_output=True)
            self.assertEqual(
                (environment_file.read_text().strip(), (root / 'calls').read_text().splitlines()),
                (f'FVM_CACHE_PATH={root}/.fvm', [str(root / package) for package in
                 ('.', 'example', 'tool/country_bindings', 'tool/device_location_bindings')]),
            )


if __name__ == '__main__':
    unittest.main()
