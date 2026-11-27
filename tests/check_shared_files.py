"""Keep Floor's regular-file copies synchronized with their shared sources."""

import argparse
import os
from pathlib import Path
import sys


SHARED_FILES = {
    "tofu/modules/kubernetes/istio/shared/versions.tofu": (
        "tofu/modules/kubernetes/istio/regional/versions.tofu",
        "tofu/modules/kubernetes/istio/regional/runtime/versions.tofu",
    ),
    "tofu/runtime/shared/cluster.tofu": (
        "tofu/runtime/agentgateway/cluster.tofu",
        "tofu/runtime/agentgateway-manifests/cluster.tofu",
        "tofu/runtime/authentik/cluster.tofu",
        "tofu/runtime/cert-manager/cluster.tofu",
        "tofu/runtime/cert-manager-istio-csr/cluster.tofu",
        "tofu/runtime/istio/cluster.tofu",
        "tofu/runtime/istio-manifests/cluster.tofu",
        "tofu/runtime/istio-test/cluster.tofu",
        "tofu/runtime/mesh/cluster.tofu",
        "tofu/runtime/onboarding/cluster.tofu",
        "tofu/runtime/opa-gatekeeper/cluster.tofu",
        "tofu/runtime/opa-gatekeeper-constraints/cluster.tofu",
        "tofu/runtime/opa-gatekeeper-templates/cluster.tofu",
        "tofu/runtime/openbao/cluster.tofu",
    ),
}


def check_shared_files(root: Path) -> list[str]:
    errors = []
    for source, copies in SHARED_FILES.items():
        canonical = root / source
        if canonical.is_symlink() or not canonical.is_file():
            errors.append(f"{source}: canonical source must be a regular file")
            continue
        content = canonical.read_bytes()
        for copy in copies:
            path = root / copy
            if not path.is_file():
                errors.append(f"{copy}: shared copy is missing")
            elif not path.is_symlink() and path.read_bytes() != content:
                errors.append(f"{copy}: differs from {source}")

    for base in ("tofu/modules", "tofu/runtime"):
        for directory, directories, files in os.walk(root / base):
            directories[:] = [name for name in directories if name not in (".terraform", "tests")]
            for name in files:
                path = Path(directory) / name
                if path.suffix == ".tofu" and path.is_symlink():
                    errors.append(f"{path.relative_to(root)}: Flux source artifacts omit symlinks")
    return errors


def sync_shared_files(root: Path) -> None:
    contents = {}
    for source in SHARED_FILES:
        path = root / source
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"{source}: canonical source must be a regular file")
        contents[source] = path.read_bytes()

    for source, copies in SHARED_FILES.items():
        for copy in copies:
            path = root / copy
            if path.is_symlink():
                path.unlink()
            path.write_bytes(contents[source])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sync", action="store_true", help="Regenerate copies from canonical sources")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    if args.sync:
        sync_shared_files(root)
    errors = check_shared_files(root)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        print("Edit canonical shared files, then run: python3 tests/check_shared_files.py --sync",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
