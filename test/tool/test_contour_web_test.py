import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time
import unittest


class TestContourWebWorkflowTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='contour workflow ')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / 'project with spaces'
        self.root.mkdir()
        source = Path(__file__).resolve().parents[2]
        self.script = self.root / 'tool/test_contour_web.sh'
        self.script.parent.mkdir()
        shutil.copy2(source / 'tool/test_contour_web.sh', self.script)
        shutil.copy2(source / 'Makefile', self.root / 'Makefile')
        self.assets = self.root / 'test/widgets/contour/assets'
        self.assets.parent.mkdir(parents=True)
        (self.root / 'shaders').mkdir()
        (self.root / 'shaders/contour_shadow_atlas.frag').write_text('// current shader\n')
        self.sdk = self.root / '.fvm/flutter_sdk'
        self.compiler_source = '''#!/usr/bin/env python3
import json, os, pathlib, sys
root = pathlib.Path(os.environ['MOCK_ROOT'])
(root / 'compiler.json').write_text(json.dumps({'host': pathlib.Path(sys.argv[0]).parent.name, 'args': sys.argv[1:]}))
if os.environ.get('MOCK_COMPILER_ASSETS'):
    assets = root / 'test/widgets/contour/assets'
    assets.mkdir()
    (assets / 'user.txt').write_text('preserve me')
status = int(os.environ.get('MOCK_COMPILER_EXIT', '0'))
if not status and not os.environ.get('MOCK_EMPTY_SHADER'):
    output = pathlib.Path(next(arg[5:] for arg in sys.argv if arg.startswith('--sl=')))
    output.write_text('browser shader')
sys.exit(status)
'''
        for host in ('darwin-x64', 'linux-x64', 'linux-arm64', 'linux-riscv64'):
            self._executable(self.sdk / f'bin/cache/artifacts/engine/{host}/impellerc', self.compiler_source)
        self._executable(self.sdk / 'bin/flutter', '''#!/usr/bin/env python3
import json, os, pathlib, sys, time
root = pathlib.Path(os.environ['MOCK_ROOT'])
assets = root / 'test/widgets/contour/assets'
target = os.readlink(assets)
shader = assets / 'shaders/contour_shadow_atlas.frag'
(root / 'flutter.json').write_text(json.dumps({'args': sys.argv[1:], 'link': target, 'shader': shader.read_text()}))
replacement = os.environ.get('MOCK_FLUTTER_ASSETS')
if replacement:
    assets.unlink()
    if replacement == 'file':
        assets.write_text('consumer replacement')
    else:
        user = root / 'consumer assets'
        user.mkdir()
        (user / 'user.txt').write_text('consumer replacement')
        assets.symlink_to(user)
if os.environ.get('MOCK_FLUTTER_BLOCK'):
    time.sleep(60)
sys.exit(int(os.environ.get('MOCK_FLUTTER_EXIT', '0')))
''')
        binary_directory = self.root / 'mock-bin'
        self._executable(binary_directory / 'uname', '''#!/usr/bin/env bash
case "$1" in
  -s) printf '%s\n' "${MOCK_SYSTEM:-Darwin}" ;;
  -m) printf '%s\n' "${MOCK_ARCH:-arm64}" ;;
esac
''')
        for name in ('flutter', 'fvm'):
            self._executable(binary_directory / name, '''#!/usr/bin/env python3
import os, pathlib, sys
(pathlib.Path(os.environ['MOCK_ROOT']) / 'global-called').write_text('wrong SDK')
sys.exit(97)
''')
        self.environment = {
            **os.environ,
            'MOCK_ROOT': str(self.root),
            'PATH': str(binary_directory) + os.pathsep + os.environ['PATH'],
        }

    def _executable(self, path, contents):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents)
        path.chmod(0o755)

    def _run(self, *arguments, **environment):
        return subprocess.run(
            ['bash', str(self.script), *arguments],
            cwd=self.temporary.name,
            env={**self.environment, **environment},
            capture_output=True,
            text=True,
            timeout=10,
        )

    def _remaining(self):
        return (
            os.path.lexists(self.assets),
            list((self.root / 'lib/src/gen').glob('contour_web_test_assets.*')),
        )

    def _read(self, name):
        return json.loads((self.root / name).read_text())

    def test_when_the_workflow_succeeds_it_should_use_the_tracked_tools_and_clean_its_assets(self):
        result = self._run()
        compiler = self._read('compiler.json')
        flutter = self._read('flutter.json')
        self.assertEqual(
            (result.returncode, compiler['host'],
             '--json' in compiler['args'], '--sksl' in compiler['args'],
             f'--input={self.root}/shaders/contour_shadow_atlas.frag' in compiler['args'],
             flutter['args'][:4], len([arg for arg in flutter['args'] if arg.endswith('_test.dart')]),
             flutter['shader'], flutter['link'].startswith('../../../lib/src/gen/contour_web_test_assets.'),
             (self.root / 'global-called').exists(), self._remaining()),
            (0, 'darwin-x64', True, True, True, ['test', '--ipv6', '--platform', 'chrome'],
             4, 'browser shader', True, False, (False, [])),
        )

    def test_when_flutter_arguments_contain_spaces_it_should_forward_them_without_splitting(self):
        arguments = ('--plain-name', 'when a child changes', '--reporter=json', 'test/additional_test.dart')
        result = self._run(*arguments)
        self.assertEqual((result.returncode, self._read('flutter.json')['args'][-4:]), (0, list(arguments)))

    def test_when_make_receives_test_arguments_it_should_forward_them_to_the_workflow(self):
        result = subprocess.run(
            ['make', 'test-contour-web', 'TEST_ARGS=--plain-name "when a child changes" --reporter=json'],
            cwd=self.root, env=self.environment, capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(
            (result.returncode, self._read('flutter.json')['args'][-3:]),
            (0, ['--plain-name', 'when a child changes', '--reporter=json']),
        )

    def test_when_assets_already_exist_it_should_refuse_every_kind_without_touching_user_files(self):
        for kind in ('file', 'directory', 'link', 'broken-link'):
            with self.subTest(kind=kind):
                if kind == 'file':
                    self.assets.write_text('preserve me')
                elif kind == 'directory':
                    self.assets.mkdir()
                    (self.assets / 'user.txt').write_text('preserve me')
                else:
                    target = self.root / f'user-{kind}'
                    if kind == 'link':
                        target.mkdir()
                        (target / 'user.txt').write_text('preserve me')
                    self.assets.symlink_to(target)
                result = self._run()
                preserved = (self.assets.read_text() if kind == 'file' else
                             str(self.assets.readlink()) if self.assets.is_symlink() else
                             (self.assets / 'user.txt').read_text())
                self.assertEqual(
                    (result.returncode, 'Refusing to replace' in result.stderr, preserved,
                     (self.root / 'compiler.json').exists(), (self.root / 'flutter.json').exists()),
                    (1, True, str(self.root / f'user-{kind}') if 'link' in kind else 'preserve me', False, False),
                )
                if self.assets.is_symlink() or self.assets.is_file():
                    self.assets.unlink()
                else:
                    shutil.rmtree(self.assets)

    def test_when_compilation_fails_it_should_preserve_the_status_and_remove_only_its_temporary_directory(self):
        existing = self.root / 'lib/src/gen/contour_web_test_assets.user'
        existing.mkdir(parents=True)
        (existing / 'user.txt').write_text('preserve me')
        result = self._run(MOCK_COMPILER_EXIT='17')
        self.assertEqual(
            (result.returncode, (self.root / 'flutter.json').exists(), self._remaining(),
             (existing / 'user.txt').read_text()),
            (17, False, (False, [existing]), 'preserve me'),
        )

    def test_when_the_compiler_produces_no_fixture_it_should_fail_before_running_flutter(self):
        result = self._run(MOCK_EMPTY_SHADER='1')
        self.assertEqual(
            (result.returncode, 'did not produce' in result.stderr,
             (self.root / 'flutter.json').exists(), self._remaining()),
            (1, True, False, (False, [])),
        )

    def test_when_flutter_fails_it_should_preserve_the_status_and_clean_the_owned_link(self):
        result = self._run(MOCK_FLUTTER_EXIT='37')
        self.assertEqual((result.returncode, self._remaining()), (37, (False, [])))

    def test_when_the_tracked_sdk_is_missing_it_should_not_fall_back_to_global_flutter(self):
        (self.sdk / 'bin/flutter').unlink()
        result = self._run()
        self.assertEqual(
            (result.returncode, (self.root / 'global-called').exists(),
             (self.root / 'compiler.json').exists(), self._remaining()),
            (1, False, False, (False, [])),
        )

    def test_when_the_host_changes_it_should_choose_only_that_tracked_sdk_compiler(self):
        for system, architecture, host in (
            ('Darwin', 'arm64', 'darwin-x64'),
            ('Linux', 'x86_64', 'linux-x64'),
            ('Linux', 'aarch64', 'linux-arm64'),
            ('Linux', 'riscv64', 'linux-riscv64'),
        ):
            with self.subTest(system=system, architecture=architecture):
                result = self._run(MOCK_SYSTEM=system, MOCK_ARCH=architecture)
                self.assertEqual((result.returncode, self._read('compiler.json')['host']), (0, host))

    def test_when_the_host_compiler_is_missing_it_should_not_select_another_sdk_artifact(self):
        (self.sdk / 'bin/cache/artifacts/engine/darwin-x64/impellerc').unlink()
        result = self._run()
        self.assertEqual(
            (result.returncode, (self.root / 'compiler.json').exists(), self._remaining()),
            (1, False, (False, [])),
        )

    def test_when_assets_appear_during_compilation_it_should_preserve_them_without_writing_inside(self):
        result = self._run(MOCK_COMPILER_ASSETS='directory')
        self.assertEqual(
            (result.returncode != 0, sorted(path.name for path in self.assets.iterdir()),
             (self.assets / 'user.txt').read_text(), self._remaining()[1],
             (self.root / 'flutter.json').exists()),
            (True, ['user.txt'], 'preserve me', [], False),
        )

    def test_when_the_owned_link_is_replaced_it_should_preserve_the_consumer_replacement(self):
        for kind in ('file', 'link'):
            with self.subTest(kind=kind):
                result = self._run(MOCK_FLUTTER_ASSETS=kind)
                content = self.assets.read_text() if kind == 'file' else (self.assets / 'user.txt').read_text()
                self.assertEqual((result.returncode, content, self._remaining()[1]), (0, 'consumer replacement', []))
                self.assets.unlink()

    def test_when_terminated_during_flutter_it_should_stop_the_child_and_clean_its_owned_assets(self):
        process = subprocess.Popen(
            ['bash', str(self.script)], cwd=self.temporary.name,
            env={**self.environment, 'MOCK_FLUTTER_BLOCK': '1'},
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )
        try:
            deadline = time.monotonic() + 5
            while not (self.root / 'flutter.json').exists() and process.poll() is None and time.monotonic() < deadline:
                time.sleep(.01)
            process.send_signal(signal.SIGTERM)
            process.communicate(timeout=5)
            self.assertEqual((process.returncode, self._remaining()), (143, (False, [])))
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()


if __name__ == '__main__':
    unittest.main()
