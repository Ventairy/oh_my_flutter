"""Compile the Contour shader with the project SDK to catch platform hazards."""
from pathlib import Path
import platform
import os
import subprocess
import tempfile
import unittest


class ContourShadowAtlasTest(unittest.TestCase):
    def test_when_compiling_for_supported_backends_it_should_avoid_windows_sampler_hazards(self):
        root = Path(__file__).resolve().parents[2]
        host = {
            ('Darwin', 'arm64'): 'darwin-x64',
            ('Darwin', 'x86_64'): 'darwin-x64',
            ('Linux', 'x86_64'): 'linux-x64',
            ('Linux', 'aarch64'): 'linux-arm64',
            ('Linux', 'arm64'): 'linux-arm64',
            ('Linux', 'riscv64'): 'linux-riscv64',
            ('Windows', 'AMD64'): 'windows-x64',
            ('Windows', 'ARM64'): 'windows-arm64',
        }[(platform.system(), platform.machine())]
        sdk = Path(os.environ.get('FLUTTER_ROOT', str(root / '.fvm/flutter_sdk')))
        compiler = sdk / 'bin/cache/artifacts/engine' / host / (
            'impellerc.exe' if platform.system() == 'Windows' else 'impellerc'
        )
        results = []
        with tempfile.TemporaryDirectory() as directory:
            for backend in ('sksl', 'runtime-stage-metal', 'runtime-stage-gles',
                            'runtime-stage-gles3', 'runtime-stage-vulkan'):
                output = Path(directory) / backend
                result = subprocess.run([
                    str(compiler), f'--{backend}', '--iplr', '--input-type=frag',
                    f'--input={root}/shaders/contour_shadow_atlas.frag',
                    f'--sl={output}', f'--spirv={output}.spirv',
                    f'--include={compiler.parent}/shader_lib',
                ], capture_output=True, text=True, check=False)
                results.append((backend, result.returncode,
                                result.stdout + result.stderr, output.is_file()))
        self.assertEqual(results, [(backend, 0, '', True) for backend in (
            'sksl', 'runtime-stage-metal', 'runtime-stage-gles',
            'runtime-stage-gles3', 'runtime-stage-vulkan')])


if __name__ == '__main__':
    unittest.main()
