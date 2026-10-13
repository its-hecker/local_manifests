#!/usr/bin/env bash
# Keep exactly one active Android 17 protobuf 21.12 provider after repo sync.
set -euo pipefail

MANIFEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd -- "$MANIFEST_DIR/../.." && pwd)"
AOSP_BP="$SOURCE_ROOT/prebuilts/misc/protobuf_vendorcompat/Android.bp"
COMPAT_DIR="$SOURCE_ROOT/hardware/lineage/compat"
PATCH="$MANIFEST_DIR/patches/android17-protobuf-vendorcompat.patch"

# Source-root exclusions are product-specific. File existence alone does not
# mean that Soong will use the declarations in that file.
if [[ -z "${TARGET_PRODUCT:-}" || -z "${TARGET_BUILD_VARIANT:-}" ]]; then
    echo "Select the product first: source build/envsetup.sh && lunch lineage_coral-userdebug" >&2
    exit 1
fi
SOURCE_ROOT_DIRS="$(cd -- "$SOURCE_ROOT" &&
    build/soong/soong_ui.bash --dumpvar-mode PRODUCT_SOURCE_ROOT_DIRS)"

provider_state() {
    python3 - "$AOSP_BP" "$COMPAT_DIR/Android.bp" "$SOURCE_ROOT_DIRS" <<'PY'
from pathlib import Path
import re
import sys

names = {
    "libprotobuf-cpp-full-21.12-vendorcompat",
    "libprotobuf-cpp-lite-21.12-vendorcompat",
}
def allowed(path):
    # Blueprint checks the longest matching prefix first and defaults to allow.
    for entry in sorted(sys.argv[3].split(), key=len, reverse=True):
        prefix = entry[1:] if entry.startswith("-") else entry
        if path.startswith(prefix):
            return not entry.startswith("-")
    return True

def modules(path, enabled):
    if not enabled:
        return set()
    source = Path(path).read_text()
    # Ignore comments so commented-out declarations do not count as providers.
    source = re.sub(r'/\*.*?\*/|//[^\n]*', '', source, flags=re.S)
    return set(re.findall(r'\bname:\s*"([^"]+)"', source))

aosp_enabled = allowed("prebuilts/misc/protobuf_vendorcompat/Android.bp")
lineage_enabled = allowed("hardware/lineage/compat/Android.bp")
try:
    aosp = names & modules(sys.argv[1], aosp_enabled)
    lineage = names & modules(sys.argv[2], lineage_enabled)
except OSError as exc:
    raise SystemExit(f"Source checkout is incomplete: {exc}")

if not aosp_enabled and lineage_enabled and not lineage:
    # The old workaround may have removed the only providers now in scope.
    # Only its exact reverse patch is permitted to restore them.
    print("restore")
elif names - (aosp | lineage):
    raise SystemExit("Refusing to patch: active providers missing: " +
                     ", ".join(sorted(names - (aosp | lineage))))
elif (aosp & lineage) == names:
    print("patch")
elif aosp & lineage:
    raise SystemExit("Only one duplicate remains. Review the upstream change before applying this patch.")
elif lineage == names:
    print("lineage")
elif aosp == names:
    print("aosp")
else:
    raise SystemExit("Providers are split between AOSP and Lineage. Review the upstream change before patching.")
PY
}

state="$(provider_state)"
case "$state" in
    restore)
        git -C "$COMPAT_DIR" apply --reverse --check "$PATCH"
        git -C "$COMPAT_DIR" apply --reverse "$PATCH"
        echo "Restored only the two Lineage protobuf 21.12 providers; AOSP's directory is excluded."
        ;;
    patch)
        git -C "$COMPAT_DIR" apply --check "$PATCH"
        git -C "$COMPAT_DIR" apply "$PATCH"
        echo "Removed only the two duplicate Lineage protobuf 21.12 declarations; AOSP supplies both."
        ;;
esac

case "$(provider_state)" in
    lineage) echo "Using Lineage protobuf 21.12 providers; no duplicate active AOSP providers." ;;
    aosp) echo "Using AOSP protobuf 21.12 providers; no duplicate active Lineage providers." ;;
    *) echo "Provider verification failed after patching; stop the build." >&2; exit 1 ;;
esac
echo "All other Lineage compatibility modules are retained."
