# Stock Google Camera experiment for coral

This branch adds Google-signed **8.7.250.494820638.44** (`65822832`) to
Project Infinity-X Android 17 for Pixel 4 XL. It follows the last stock Camera
8.7 generation for Pixel 4/4 XL. Physical-device operation on Android 17 still
requires a ROM build and testing.

| Repository | Branch |
| --- | --- |
| `infinity_cnb_android_device_google_coral` | `gcam-experimental` |
| `infinity_cnb_proprietary_vendor_google_coral` | `gcam-experimental` |
| `local_manifests` | `gcam-experimental` |
| `infinity_cnb_kernel_google_msm-4.14` | `cnb-Latest-stable` |

The manifest selects the matching device/vendor branches. Stable branch heads,
default branches, Flame and the kernel are unchanged. The existing camera app
remains available during testing. Native 3D Face ID, Motion Sense and the other
tested stable changes are inherited from the stable source commits.

## Switch an existing Infinity source checkout

From `~/infinityx` (or your existing Infinity source root):

```bash
git -C .repo/local_manifests fetch origin gcam-experimental:gcam-experimental &&
git -C .repo/local_manifests switch gcam-experimental &&
repo sync -c -j8 --fail-fast device/google/coral vendor/google/coral &&
bash .repo/local_manifests/build-gcam.sh
```

The fetch safely refuses a divergent local branch; it does not force-reset local
changes. `git switch` also refuses conflicting uncommitted edits. A single-branch
clone is supported by the explicit fetch refspec. Before a later sync, update
the checked-out manifest branch with `git pull --ff-only`.

The helper checks the exact committed Camera payload without needing an Android
SDK install, selects `lineage_coral-userdebug`, applies the existing protobuf and
Face ID framework fixes, and runs `mka bacon`. It preserves the build provider's
RBE configuration and existing Ninja settings.

## New source checkout

Follow the stable README's server/tool/Git LFS setup, then:

```bash
mkdir -p ~/infinityx-gcam &&
cd ~/infinityx-gcam &&
repo init -u https://github.com/projectinfinity-X/manifest -b 17 --git-lfs &&
git clone --branch gcam-experimental --single-branch \
  https://github.com/its-hecker/local_manifests .repo/local_manifests &&
repo sync -c -j8 --fail-fast --no-clone-bundle --no-tags &&
git -C kernel/google/msm-4.14 submodule update --init --recursive &&
bash .repo/local_manifests/build-gcam.sh
```

## What verification covers

The vendor workflow and the local verifier reconstruct the app set and check
the base plus nine common feature APKs. Every installed APK must match the pinned
SHA-256, package, version and original Google signing certificate. The stock
startup JNI library is included. Six Tensor-specific feature modules are omitted.

APKs are not merged or re-signed. The source chunks are committed, so Android
builds require neither an external Camera download nor Camera Git LFS access.
The original vendor radio files retain their existing Git LFS requirements.

Camera CI does not build a complete Android ROM or establish runtime stability.
Follow `device/google/coral/camera/README.md` after flashing. Test rear/front/2x
photos, Portrait, Night Sight, video and microphone, preview, lock-screen launch,
and Face ID before considering promotion. If an installed Play Store Camera
update overrides the preinstalled version, uninstall that app's updates in
Settings before testing.

## Return to stable

```bash
git -C .repo/local_manifests switch cnb-Latest-stable &&
git -C .repo/local_manifests pull --ff-only &&
repo sync -c -j8 --fail-fast device/google/coral vendor/google/coral
```

Rebuild using the stable README. An existing `/data` Camera update is separate
from the ROM source choice and may remain installed on a dirty flash.
