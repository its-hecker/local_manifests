# Stable Google Camera for coral

Google Camera **8.7.250.494820638.44** (`65822832`) is included in stable
Infinity-X builds for Pixel 4 XL (coral). On **2026-10-16**, the maintainer reported
that the experimental build booted and GCam worked, then approved promotion.

The Camera code, Google signing certificate and APK payload are unchanged from
that tested experimental integration. Per-mode capture results were not supplied;
this records successful boot and general Camera operation.

| Source | Repository | Branch |
| --- | --- | --- |
| Device | `its-hecker/infinity_cnb_android_device_google_coral` | `cnb-Latest-stable` |
| Vendor | `its-hecker/infinity_cnb_proprietary_vendor_google_coral` | `cnb-Latest-stable` |
| Local manifest | `its-hecker/local_manifests` | `cnb-Latest-stable` |
| Kernel | `its-hecker/infinity_cnb_kernel_google_msm-4.14` | `cnb-Latest-stable` |

The stable `coral.xml` continues to select stable device/vendor/kernel revisions.
The experimental branches remain available. The Camera package is selected only
by `lineage_coral.mk`; Flame is unaffected by this promotion.

## Switch the existing experimental checkout to stable

Run in the source directory used for the successful build:

```bash
cd ~/infinityx-gcam &&
git -C .repo/local_manifests fetch origin cnb-Latest-stable:refs/remotes/origin/cnb-Latest-stable &&
if git -C .repo/local_manifests show-ref --verify --quiet refs/heads/cnb-Latest-stable; then
    git -C .repo/local_manifests switch cnb-Latest-stable
else
    git -C .repo/local_manifests switch --track origin/cnb-Latest-stable
fi &&
git -C .repo/local_manifests pull --ff-only origin cnb-Latest-stable &&
repo sync -c -j8 --fail-fast device/google/coral vendor/google/coral &&
python3 vendor/google/coral/camera/tools/prepare_camera.py --check-hashes
```

The explicit fetch supports the previous single-branch experimental clone.
These commands preserve source edits and stop if a branch switch or sync
conflicts with them. The source directory can keep its existing name.

An existing stable checkout only needs its local manifest updated with
`git pull --ff-only origin cnb-Latest-stable`, followed by syncing `device/google/coral` and
`vendor/google/coral`. New checkouts can follow the stable README as usual.

The successful experimental ROM already contains this Camera payload.
Promotion makes it part of subsequent stable builds.

## Build on ServerHive

Use a fresh Byobu window and run the stable README's environment/setup and
build commands in that window's current shell. Keep the provider's RBE and
Ninja configuration, and retain the existing protobuf and Face ID framework
fixes. Camera does not need a separate build flag or an external download.

## Verification and runtime notes

The read-only vendor CI reconstructs the committed APK set and checks all ten
APKs against the pinned hashes, package/version and original Google signer.
The device CI checks the certificate-scoped SELinux mapping, permission XML
and coral-only product selection. The actual Infinity-X Soong extractor has
also been checked to preserve the base plus nine feature APKs byte-for-byte.

The Tensor-specific feature modules are excluded. The startup native library
and common Camera assets are included. The existing camera app stays installed.

Runtime commands and individual-mode checks are in
`device/google/coral/camera/README.md`. A newer user-installed Camera update can
override the preinstalled version; inspect the active package when investigating
a difference from the tested stock version.
