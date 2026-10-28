"""Exercise decoded native-port descriptors with strict alignment checks."""

from pathlib import Path
import subprocess
import tempfile
import unittest


class NativePortCompositeTest(unittest.TestCase):
    def test_when_descriptors_are_unaligned_it_should_match_aligned_composition(self):
        root = Path(__file__).resolve().parents[4]
        native = root / "src/contour_native_port"
        with tempfile.TemporaryDirectory(prefix="contour-alignment-") as temporary:
            sdk_object = Path(temporary) / "dart_api_dl.o"
            executable = Path(temporary) / "composite_test"
            subprocess.run([
                "clang", "-std=c11", "-c", str(native / "sdk/include/dart_api_dl.c"),
                "-o", str(sdk_object),
            ], check=True)
            subprocess.run([
                "clang++", "-std=c++17", "-O1", "-g", "-fsanitize=alignment",
                "-fno-sanitize-recover=alignment", "-ffp-contract=off", "-fno-fast-math",
                "-DClipper2Lib=ContourPackageBackingClipper2Lib", "-I", str(native),
                "-I", str(native / "composite/portable/deps/trace"),
                "-I", str(native / "composite/portable/deps/backing"),
                "-I", str(native / "composite/portable/deps/backing/clipper2/include"),
                "-I", str(native / "composite/portable/deps/compositor"),
                str(Path(__file__).with_suffix(".cpp")),
                *[str(native / source) for source in (
                    "composite/contour_cpu_batch.cpp",
                    "composite/portable/contour_generic_fused.cpp",
                    "composite/portable/deps/trace/contour_source_a8.cpp",
                    "composite/portable/deps/backing/contour_backing_raster.cpp",
                    "composite/portable/deps/backing/scanline.cpp",
                    "composite/portable/deps/backing/clipper2/src/clipper.engine.cpp",
                    "composite/portable/deps/backing/clipper2/src/clipper.offset.cpp",
                    "composite/portable/deps/compositor/contour_a8_compositor.cpp",
                )],
                str(sdk_object), "-o", str(executable),
            ], check=True)
            result = subprocess.run([str(executable)], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
