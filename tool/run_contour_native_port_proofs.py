#!/usr/bin/env python3
"""Run native barrier proofs in an isolated copy with test-only C exports."""

import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


PROOF_INPUTS = (
    "pubspec.yaml", "analysis_options.yaml", "lib", "src", "hook", "shaders",
    "test/fixtures/contour_native_port",
)
PROOF_TESTS = (
    "test/fixtures/contour_native_port/contour_native_port_session_proof.dart",
    "test/fixtures/contour_native_port/contour_native_port_processor_proof.dart",
)


def prepare_workspace(source: Path, destination: Path, sdk: Path) -> None:
    for name in PROOF_INPUTS:
        original, copied = source / name, destination / name
        copied.parent.mkdir(parents=True, exist_ok=True)
        if original.is_dir():
            shutil.copytree(original, copied)
        else:
            shutil.copy2(original, copied)
    (destination / ".fvm").mkdir()
    (destination / ".fvm/flutter_sdk").symlink_to(sdk, target_is_directory=True)
    library = destination / "lib/src/widgets/contour/tracing/contour_native_port_c_library.dart"
    content = library.read_text()
    anchor = "    defines: const {'Clipper2Lib': 'ContourPackageBackingClipper2Lib'},\n"
    if content.count(anchor) != 1 or "'CT_TESTING'" in content:
        raise SystemExit(f"The proof hook needs review before modifying {library}.")
    library.write_text(content.replace(anchor, "    defines: const {'Clipper2Lib': 'ContourPackageBackingClipper2Lib', 'CT_TESTING': null},\n"))


def run_proofs(source: Path, *, keep_workspace: bool = False) -> None:
    sdk = (source / ".fvm/flutter_sdk").resolve(strict=True)
    if not (sdk / "bin/flutter").is_file():
        raise FileNotFoundError("The tracked FVM SDK is missing. Run fvm install first.")
    temporary = Path(tempfile.mkdtemp(prefix="contour-native-port-proof-"))
    destination = temporary / "oh_my_flutter"
    try:
        prepare_workspace(source, destination, sdk)
        flutter = str(destination / ".fvm/flutter_sdk/bin/flutter")
        print(f"Proof copy: {destination}", flush=True)
        print("CT_TESTING is enabled only in this temporary copy's native build hook.", flush=True)
        subprocess.run([flutter, "pub", "get"], cwd=destination, check=True)
        subprocess.run([
            flutter, "test", "--no-pub", "--reporter", "expanded", *PROOF_TESTS,
        ], cwd=destination, check=True)
    finally:
        if keep_workspace:
            print(f"Retained proof workspace: {temporary}", flush=True)
        else:
            shutil.rmtree(temporary)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keep-workspace", action="store_true", help="Retain the isolated proof workspace for diagnosis")
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("The native barrier proof requires the macOS host backend.")
    try:
        run_proofs(Path(__file__).resolve().parents[1], keep_workspace=args.keep_workspace)
    except OSError as error:
        parser.error(str(error))
    except subprocess.CalledProcessError as error:
        return error.returncode
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
