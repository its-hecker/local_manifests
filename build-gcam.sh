#!/usr/bin/env bash
# Build coral with the pinned stock Google Camera experiment.
set -eo pipefail

MANIFEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd -- "$MANIFEST_DIR/../.." && pwd)"
cd -- "$SOURCE_ROOT"

python3 vendor/google/coral/camera/tools/prepare_camera.py --check-hashes
source build/envsetup.sh
lunch lineage_coral-userdebug
bash "$MANIFEST_DIR/apply-build-fixes.sh"
python3 device/google/coral/faceunlock/tools/apply_framework_fixes.py --apply
mka bacon
