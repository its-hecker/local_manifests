# Project Infinity X 17 for Pixel 4 XL (coral)

Local manifest and build notes for Project Infinity X (Android 17, based on LineageOS 24.0) on the Pixel 4 XL (coral), with Motion Sense, KernelSU-Next and Lunaris Dolby. Compatibility libraries, apps and configuration live in the device, vendor and kernel trees. Face ID also requires two guarded framework adapter fixes applied from the device tree after syncing. The ROM's Settings source stays unmodified.

- [Part 1: Build Infinity X on a build server](#part-1-build-infinity-x-on-a-build-server)
- [Part 2: Use these trees for another Android 17 ROM](#part-2-use-these-trees-for-another-android-17-rom)
- [Motion Sense porting guide](MOTION_SENSE.md)

## What this manifest adds

| Path | Repository | Branch | What it is |
| --- | --- | --- | --- |
| `device/google/coral` | [infinity_cnb_android_device_google_coral](https://github.com/its-hecker/infinity_cnb_android_device_google_coral) | `cnb-Latest-stable` | Device tree (coral and flame) |
| `vendor/google/coral` | [infinity_cnb_proprietary_vendor_google_coral](https://github.com/its-hecker/infinity_cnb_proprietary_vendor_google_coral) | `cnb-Latest-stable` | Vendor blobs from TP1A.221005.002.B2, plus the Motion Sense APKs |
| `kernel/google/msm-4.14` | [infinity_cnb_kernel_google_msm-4.14](https://github.com/its-hecker/infinity_cnb_kernel_google_msm-4.14) | `cnb-Latest-stable` | Kernel with KernelSU-Next (as a submodule) |
| `vendor/lunaris/dolby` | [vendor_lunaris_dolby](https://github.com/its-hecker/vendor_lunaris_dolby) | `main` | Dolby Atmos |

Smali source for the Motion Sense app: [infinity_OsloFeedback](https://github.com/its-hecker/infinity_OsloFeedback) (`cnb-Latest-stable`). The build does not use it directly: it uses the finished APK in the vendor tree.

The device, vendor, OsloFeedback source and local manifest branches were promoted from
`features-experimental`; the kernel branch was promoted from `cnb`.
Google Pokemon Sidekick and custom Sidekick wallpapers are removed.
Motion Sense, glow and 3D Face ID retain the tested fixes.

## Part 1: Build Infinity X on a build server

A ROM build needs an x86-64 Linux machine; it cannot run on a phone. These steps were used on a ServerHive build server running Ubuntu. Plan for at least 16 CPU cores, 32 GB RAM and 300 GB free disk.

### 1. Connect and set up the environment (once)

On ServerHive, use the preconfigured build tools inside a Byobu/Tmux session.
Check that the required commands are available:

```bash
command -v repo git python3
git lfs version
```

The provider does not supply standard root access. If a tool is missing, request
it from ServerHive support. The package-install commands below are for a
self-managed Ubuntu machine with sudo access:

```bash
sudo apt update
sudo apt install -y bc bison build-essential ccache curl flex g++-multilib gcc-multilib \
  git git-lfs gnupg gperf imagemagick lib32readline-dev lib32z1-dev libelf-dev \
  liblz4-tool libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync \
  schedtool squashfs-tools xsltproc zip zlib1g-dev python3 python-is-python3 unzip
```

ServerHive already provides `repo`. On another machine where it is missing,
install it in your home directory:

```bash
mkdir -p ~/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Set up git and Git LFS. Infinity X keeps some repositories on LFS, and the sync fails without it:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git lfs install
```

If you use gitcookies or a token to push from the server, keep that file out of every repository.

Optional, but it makes rebuilds much faster:

```bash
echo 'export USE_CCACHE=1' >> ~/.bashrc
echo 'export CCACHE_EXEC=/usr/bin/ccache' >> ~/.bashrc
source ~/.bashrc
ccache -M 50G
```

### 2. Get the source

```bash
mkdir -p ~/infinityx &&
cd ~/infinityx &&
repo init -u https://github.com/projectinfinity-X/manifest -b 17 --git-lfs &&
git clone --branch cnb-Latest-stable --single-branch \
    https://github.com/its-hecker/local_manifests .repo/local_manifests &&
repo sync -c -j8 --fail-fast --force-sync --no-clone-bundle --no-tags --optimized-fetch --prune
```

The kernel brings KernelSU-Next in as a submodule. If `kernel/google/msm-4.14/KernelSU` is empty after the sync:

```bash
git -C kernel/google/msm-4.14 submodule update --init --recursive
```

If the sync fails with a "duplicate project" error, a project in this manifest is also in the ROM's manifest. Add `<remove-project name="..."/>` for the ROM's copy to `coral.xml`.

KernelSU-Next's `path_umount` and seccomp compatibility changes are committed in
the stable kernel, so they are present before compilation starts. Earlier
versions applied these changes from KernelSU's Kbuild while a parallel build
was already running, which could leave `fs/namespace.o` without the required
symbol. When migrating an old checkout, back up and restore autogenerated edits
in `fs/namespace.c`, `fs/internal.h` and `include/linux/seccomp.h` before syncing.
Rebuild `out/target/product/coral/obj/KERNEL_OBJ` once after the update.

#### Android 17 protobuf compatibility fix

On `cnb-Latest-stable`, check the protobuf providers after syncing and selecting
the build target:

```bash
cd ~/infinityx &&
source build/envsetup.sh &&
breakfast lineage_coral-userdebug &&
test "$TARGET_PRODUCT" = "lineage_coral" &&
test "$TARGET_BUILD_VARIANT" = "userdebug" &&
bash .repo/local_manifests/apply-build-fixes.sh
```

Android 17's `prebuilts/misc/protobuf_vendorcompat` and the inherited Lineage
compatibility tree both declare the full and lite protobuf 21.12 vendor libraries.
Current Infinity excludes the AOSP directory with `PRODUCT_SOURCE_ROOT_DIRS`,
so the Lineage declarations must remain. The script reads the selected product's
effective source roots, retains the active providers and can reverse the old
two-module removal when AOSP is excluded. It removes the two Lineage declarations
only when both directories are active and AOSP supplies both replacements.
Unrelated compatibility libraries and local edits stay in place. The script is
safe to rerun; do not remove the entire compatibility tree.

### 3. Check the tree before building

```bash
ls kernel/google/msm-4.14/KernelSU/kernel/Kconfig
ls -la kernel/google/msm-4.14/drivers/kernelsu
ls vendor/lunaris/dolby/dolby.mk
ls vendor/google/coral/proprietary/system_ext/priv-app/OsloFeedback/OsloFeedback.apk
```

All four should exist. `drivers/kernelsu` should be a link to `../KernelSU/kernel`.

### 4. Build

On ServerHive, open a fresh Byobu/Tmux window for this ROM (`F2` in Byobu),
then run the commands in that window's current shell. The
[provider's guide](https://github.com/ServerHive-Development/guide) requires a
persistent session and documents building through `mka` or `brunch`. Keep
environment setup in the current shell so the selected target remains available.

```bash
cd ~/infinityx &&
source build/envsetup.sh &&
breakfast lineage_coral-userdebug &&
test "$TARGET_PRODUCT" = "lineage_coral" &&
test "$TARGET_BUILD_VARIANT" = "userdebug" &&
test "$(build/soong/soong_ui.bash --dumpvar-mode USE_RBE)" = "true" &&
bash .repo/local_manifests/apply-build-fixes.sh &&
python3 device/google/coral/faceunlock/tools/apply_framework_fixes.py --apply &&
mka -j8 selinux_policy &&
mka -j8 bacon
```

`breakfast lineage_coral-userdebug` forwards this full target to `lunch`.
The current Infinity X `lunch` function accepts `<product>-<variant>` and derives
the release from `build/make/core/build_id.mk`. Do not use the old three-part
`lineage_coral-cp2a-userdebug` form: this function reads `cp2a-userdebug` as the
variant. `breakfast coral` currently expands to that old three-part form, so use
the full target above. `lunch` can return success after target selection fails, so the checks above
must pass before compiling. A log mentioning `build.aosp_arm64.ninja` is analyzing
the generic AOSP product rather than coral.

These instructions use `userdebug` for development builds. For a release
`user` build, use `lunch lineage_coral-user` and check that the variant is `user`.

`mka -j8 selinux_policy` checks the SELinux policy before the full build. Use `breakfast lineage_flame-userdebug` for the Pixel 4 (flame), and change the product check to `lineage_flame`. `lunch` may also fetch `packages/apps/ElmyraService` (Active Edge), which the device tree lists in `lineage.dependencies`.

For this ServerHive setup, retain the provider's RBE environment and keep RBE
enabled as instructed by its administrator. `USE_RBE=1` is accepted as true;
`soong_ui` normalizes it for product configuration. Keep host settings out of
`vendor/infinity/config/common.mk`. A reproxy connection failure should be
investigated with the provider using the RBE logs.

ServerHive may add a `CUSTOM_NINJA_BIN` hook in `build/soong/ui/build/config.go`
and change status messages in `ui/build/rbe.go`. Inspect these local diffs before
restoring them: they can be part of the provider's build setup.

The Face ID script checks the challenge-revocation and enrollment-feature methods
before writing and backs up the adapter under `out/face-framework-patches/`.
Reapply it after syncing or restoring `frameworks/base`. Its implementation and
patches are committed in the stable device tree, but applying them intentionally
leaves `HidlToAidlSessionAdapter.java` locally modified in the upstream framework
repository. That `repo status` entry is expected. See the
[Face ID framework notes](https://github.com/its-hecker/infinity_cnb_android_device_google_coral/blob/cnb-Latest-stable/faceunlock/patches/README.md).

The flashable zip is written to `out/target/product/coral/`:

```bash
ls -lh out/target/product/coral/*.zip
```

### 5. Update and rebuild

```bash
cd ~/infinityx &&
git -C .repo/local_manifests fetch origin &&
if git -C .repo/local_manifests show-ref --verify --quiet refs/heads/cnb-Latest-stable; then
    git -C .repo/local_manifests switch cnb-Latest-stable
else
    git -C .repo/local_manifests switch --track origin/cnb-Latest-stable
fi &&
git -C .repo/local_manifests pull --ff-only &&
repo sync -c -j8 --fail-fast --force-sync --no-clone-bundle --no-tags --optimized-fetch --prune &&
git -C kernel/google/msm-4.14 submodule update --init --recursive &&
source build/envsetup.sh &&
breakfast lineage_coral-userdebug &&
test "$TARGET_PRODUCT" = "lineage_coral" &&
test "$TARGET_BUILD_VARIANT" = "userdebug" &&
bash .repo/local_manifests/apply-build-fixes.sh &&
python3 device/google/coral/faceunlock/tools/apply_framework_fixes.py --apply &&
mka -j8 selinux_policy &&
mka -j8 bacon
```

The `&&` chain stops at the first failed command without closing your SSH shell,
and leaves environment setup in that same shell. Do not
compile after `Unable to fully sync the tree`. `--force-sync` repairs Git directory
links; it does not resolve modified tracked files.

If a previous local build fix blocks checkout in `hardware/lineage/compat` or
`vendor/infinity`, save the edits before rerunning the update block:

```bash
cd ~/infinityx
build_fix_backup="$(mktemp -d "$HOME/infinityx-local-fixes-XXXXXXXX")"
for build_fix_repo in hardware/lineage/compat vendor/infinity; do
    build_fix_name="${build_fix_repo//\//_}"
    git -C "$build_fix_repo" diff --binary HEAD > "$build_fix_backup/$build_fix_name.patch"
    git -C "$build_fix_repo" stash push -u -m "before stable sync: $build_fix_backup"
done
echo "Saved local edits in $build_fix_backup and each repository's stash."
```

The stashes also retain untracked files. Leave these stashes saved while the
protobuf script checks the new configuration; do not automatically pop the old
workarounds over the updated sources. Review any unrelated ServerHive fixes in
the saved patches before deciding to reapply them.

To pick up a change in only one of these trees, sync just that path, for example `repo sync -c --force-sync vendor/google/coral`.

### After flashing

Open Settings → System → Motion Sense and turn on Use Motion Sense. The page also has the gesture switches, the media app list, the "Control any media app" and "Ignore videos" options, and the glow color.

Testing and troubleshooting are in [MOTION_SENSE.md](MOTION_SENSE.md#testing).

## Part 2: Use these trees for another Android 17 ROM

The trees work on another Android 17 ROM based on LineageOS 24.0 (for example Evolution X 17), but the device tree has Infinity-specific parts. Keep a separate branch of the device tree per ROM (for example `evo-17`, branched from `cnb-Latest-stable`) so Motion Sense fixes can be cherry-picked into all of them.

### What stays the same

| Repository | Change needed | Why |
| --- | --- | --- |
| Vendor tree | None | Blobs, firmware, the Oslo nanoapp and the patched `OsloFeedback.apk` do not depend on the ROM |
| Kernel | None | Motion Sense needs no kernel changes. KernelSU-Next is optional |
| Dolby | None, or drop it | Leave out the `vendor_lunaris_dolby` project if the ROM ships its own Dolby |
| Device tree, Motion Sense parts | None | Props, SELinux rules, the `vendor_init` rule and the framework overlays carry over as they are |

### What to change in the device tree

| What | Where | Change |
| --- | --- | --- |
| SystemUI plugin allowlist | `overlay-oslo/frameworks/base/packages/SystemUI/res/values/config.xml` | Preserve the new ROM's own `config_pluginAllowlist` and append the exact `com.google.oslo/com.google.oslo.OsloOverlay` and `com.google.oslo/com.google.oslo.OsloSensorManager` components. The production overlay is in `rro_overlays/OsloSystemUIOverlay/`. With Infinity's list, Oslo still loads, but the ROM's own SystemUI plugins stop working. If the ROM does not define the array at all, this folder can stay as it is |
| Common ROM makefile | `lineage_coral.mk`, `lineage_flame.mk` | Replace `vendor/infinity/config/common_full_phone.mk` with the new ROM's common makefile |
| ROM flags | `lineage_coral.mk` | Remove `INFINITY_BUILD`, `INFINITY_MAINTAINER`, `ro.infinity.soc` and `ro.infinity.camera`, and add the new ROM's own flags. Copy them from one of that ROM's official device trees |
| Face unlock flag | `lineage_coral.mk` | `TARGET_FACE_UNLOCK_SUPPORTED := false` is Infinity's switch for its camera face unlock. Use the new ROM's equivalent, if it has one |
| Build target | `lunch` command | The target syntax and product name may differ. Infinity selects its release automatically; check the other ROM's build guide |
| Motion Sense settings page | `parts/` (GoogleParts) | None on a LineageOS-based ROM: it is a separate app that Settings shows by itself, so the ROM's Settings needs no patch. It needs `org.lineageos.settings.resources`, which LineageOS-based ROMs ship |

### What to change in the local manifest

Copy `coral.xml`, point each project at the branch you made for the new ROM, and remove the Dolby project if the ROM already has Dolby. If the ROM's manifest already includes a coral device, vendor or kernel tree, add a `<remove-project>` line for it.

## Credits

- Motion Sense on Android 17: its-hecker. Based on the Android 14 PixysOS port by [Aswin A S](https://github.com/aswin7469), and earlier work by the Dirty Unicorns developers
- Kernel base: [0xSoul24/kernel_google_msm-4.14](https://github.com/0xSoul24/kernel_google_msm-4.14)
- [Project Infinity X](https://github.com/ProjectInfinity-X) and [LineageOS](https://github.com/LineageOS)
