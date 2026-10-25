"""Check proof isolation and cleanup without compiling native code."""

from contextlib import redirect_stdout
import importlib.util
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[2] / 'tool/run_contour_native_port_proofs.py'
SPEC = importlib.util.spec_from_file_location('contour_native_port_proofs', SCRIPT)
proofs = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(proofs)


class ContourNativePortProofRunnerTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='contour proof test ')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / 'source'
        self.source.mkdir()
        for name in proofs.PROOF_INPUTS:
            path = self.source / name
            if '.' in path.name:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('fixture\n')
            else:
                path.mkdir(parents=True)
                (path / 'fixture.txt').write_text('fixture\n')
        self.library = self.source / 'lib/src/widgets/contour/tracing/contour_native_port_c_library.dart'
        self.library.parent.mkdir(parents=True)
        self.library.write_text("    defines: const {'Clipper2Lib': 'ContourPackageBackingClipper2Lib'},\n")
        self.sdk = self.root / 'tracked sdk'
        (self.sdk / 'bin').mkdir(parents=True)
        (self.sdk / 'bin/flutter').touch()
        (self.source / '.fvm').mkdir()
        (self.source / '.fvm/flutter_sdk').symlink_to(self.sdk, target_is_directory=True)
        self.workspace = self.root / 'proof workspace'
        self.workspace.mkdir()

    def run_proofs(self, *, keep=False, failure=None):
        with patch.object(proofs.tempfile, 'mkdtemp', return_value=str(self.workspace)), \
                patch.object(proofs.subprocess, 'run', side_effect=failure) as run, \
                redirect_stdout(io.StringIO()):
            proofs.run_proofs(self.source, keep_workspace=keep)
        return run

    def test_when_proofs_succeed_it_should_use_only_required_inputs_and_remove_the_workspace(self):
        (self.source / 'example').mkdir()
        (self.source / 'example/unrelated-result.json').write_text('{}')
        observed = []

        def inspect(command, *, cwd, check):
            observed.append((command, cwd, check, (cwd / 'example').exists(),
                             "'CT_TESTING': null" in (cwd / self.library.relative_to(self.source)).read_text()))

        self.run_proofs(failure=inspect)
        flutter = str(self.workspace / 'oh_my_flutter/.fvm/flutter_sdk/bin/flutter')
        self.assertEqual(
            ([(item[0], item[2:]) for item in observed], self.workspace.exists(),
             "'CT_TESTING'" in self.library.read_text()),
            ([([flutter, 'pub', 'get'], (True, False, True)),
              ([flutter, 'test', '--no-pub', '--reporter', 'expanded', *proofs.PROOF_TESTS],
               (True, False, True))], False, False),
        )

    def test_when_a_command_fails_it_should_remove_only_its_workspace(self):
        status = None
        try:
            self.run_proofs(failure=subprocess.CalledProcessError(17, ['flutter', 'test']))
        except subprocess.CalledProcessError as error:
            status = error.returncode
        self.assertEqual((status, self.workspace.exists(), self.library.is_file()), (17, False, True))

    def test_when_retention_is_requested_it_should_keep_the_isolated_copy_for_diagnosis(self):
        self.run_proofs(keep=True)
        self.assertEqual(
            ((self.workspace / 'oh_my_flutter' / self.library.relative_to(self.source)).is_file(),
             "'CT_TESTING'" in self.library.read_text()),
            (True, False),
        )

    def test_when_the_build_anchor_changes_it_should_fail_before_running_flutter_and_clean_up(self):
        self.library.write_text('different hook\n')
        message = ''
        try:
            self.run_proofs()
        except SystemExit as error:
            message = str(error)
        self.assertEqual(('needs review' in message, self.workspace.exists()), (True, False))

    def test_when_a_source_file_is_a_symlink_it_should_patch_only_its_independent_copy(self):
        original = self.root / 'original library.dart'
        original.write_text(self.library.read_text())
        self.library.unlink()
        self.library.symlink_to(original)
        self.run_proofs(keep=True)
        copied = self.workspace / 'oh_my_flutter' / self.library.relative_to(self.source)
        self.assertEqual(
            (copied.is_symlink(), "'CT_TESTING': null" in copied.read_text(),
             "'CT_TESTING'" in original.read_text()),
            (False, True, False),
        )


if __name__ == '__main__':
    unittest.main()
