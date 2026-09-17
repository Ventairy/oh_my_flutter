import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tool.ci.verify_sdk import SdkVerification


class SdkVerificationTest(unittest.TestCase):
    def test_when_fvm_uses_the_restored_sdk_it_should_accept_its_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            (root / 'sdk/bin').mkdir(parents=True)
            (root / 'fvm').symlink_to(root / 'sdk', target_is_directory=True)
            with patch.dict(os.environ, FLUTTER_ROOT=str(root / 'sdk')):
                with patch('shutil.which', side_effect=lambda name: str(root / 'fvm/bin' / name)):
                    self.assertIsNone(SdkVerification.verify())

    def test_when_fvm_uses_another_sdk_it_should_reject_it(self):
        with patch.dict(os.environ, FLUTTER_ROOT='/expected/sdk'):
            with patch('shutil.which', return_value='/unexpected/sdk/bin/flutter'):
                with self.assertRaises(RuntimeError):
                    SdkVerification.verify()


if __name__ == '__main__':
    unittest.main()
