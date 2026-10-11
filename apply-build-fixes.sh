#!/usr/bin/env bash
# Apply the Android 17 protobuf declaration fix after repo sync.
set -euo pipefail

MANIFEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd -- "$MANIFEST_DIR/../.." && pwd)"
AOSP_BP="$SOURCE_ROOT/prebuilts/misc/protobuf_vendorcompat/Android.bp"
COMPAT_DIR="$SOURCE_ROOT/hardware/lineage/compat"
PATCH="$MANIFEST_DIR/patches/android17-protobuf-vendorcompat.patch"

# Do not remove a provider unless AOSP supplies both replacements.
state="$(python3 - "$AOSP_BP" "$COMPAT_DIR/Android.bp" <<'PY'
from pathlib import Path
import re
import sys

names = {
    "libprotobuf-cpp-full-21.12-vendorcompat",
    "libprotobuf-cpp-lite-21.12-vendorcompat",
}
def modules(path):
    source = Path(path).read_text()
    # Ignore comments so commented-out declarations do not count as providers.
    source = re.sub(r'/\*.*?\*/|//[^\n]*', '', source, flags=re.S)
    return set(re.findall(r'^\s*name:\s*"([^"]+)"', source, flags=re.M))

try:
    aosp = modules(sys.argv[1])
    lineage = modules(sys.argv[2])
except OSError as exc:
    raise SystemExit(f"Source checkout is incomplete: {exc}")

missing = names - aosp
if missing:
    raise SystemExit("Refusing to patch: AOSP providers missing: " + ", ".join(sorted(missing)))
duplicates = names & lineage
if not duplicates:
    print("clean")
elif duplicates == names:
    print("patch")
else:
    raise SystemExit("Only one duplicate remains. Review the upstream change before applying this patch.")
PY
)"

if [[ "$state" == "clean" ]]; then
    echo "No duplicate protobuf 21.12 declarations in Lineage compat; nothing to change."
    exit 0
fi

git -C "$COMPAT_DIR" apply --check "$PATCH"
git -C "$COMPAT_DIR" apply "$PATCH"
echo "Removed only the two duplicate protobuf 21.12 declarations from Lineage compat."
echo "AOSP providers and all other Lineage compatibility modules are retained."
