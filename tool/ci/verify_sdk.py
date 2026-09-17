"""Run through `fvm exec` to reject a second or unexpected Flutter SDK."""
import os
from pathlib import Path
import shutil


class SdkVerification:
    @staticmethod
    def verify():
        root = Path(os.environ['FLUTTER_ROOT']).resolve()
        for executable in ('flutter', 'dart'):
            resolved = shutil.which(executable)
            if resolved is None or Path(resolved).resolve().parent != root / 'bin':
                raise RuntimeError(f'{executable} resolved outside {root}: {resolved}')
        print(f'FVM SDK verified in {Path.cwd()}: {root}')


if __name__ == '__main__':
    SdkVerification.verify()
