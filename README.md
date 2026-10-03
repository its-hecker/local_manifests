# Project Infinity X 17 for Pixel 4 XL (coral)

Local manifest and build notes for Project Infinity X (Android 17, based on LineageOS 24.0) on the Pixel 4 XL (coral), with Motion Sense, KernelSU-Next and Lunaris Dolby. Everything lives in the device, vendor and kernel trees: the ROM's own repositories, including Settings, stay unmodified.

- [Part 1: Build Infinity X on a build server](#part-1-build-infinity-x-on-a-build-server)
- [Part 2: Use these trees for another Android 17 ROM](#part-2-use-these-trees-for-another-android-17-rom)
- [Motion Sense porting guide](MOTION_SENSE.md)

## What this manifest adds

| Path | Repository | Branch | What it is |
| --- | --- | --- | --- |
| `device/google/coral` | [infinity_cnb_android_device_google_coral](https://github.com/its-hecker/infinity_cnb_android_device_google_coral) | `lineage-24.0` | Device tree (coral and flame) |
| `vendor/google/coral` | [infinity_cnb_proprietary_vendor_google_coral](https://github.com/its-hecker/infinity_cnb_proprietary_vendor_google_coral) | `lineage-24.0` | Vendor blobs from TP1A.221005.002.B2, plus the Motion Sense APKs |
| `kernel/google/msm-4.14` | [infinity_cnb_kernel_google_msm-4.14](https://github.com/its-hecker/infinity_cnb_kernel_google_msm-4.14) | `cnb` | Kernel with KernelSU-Next (as a submodule) |
| `vendor/lunaris/dolby` | [vendor_lunaris_dolby](https://github.com/its-hecker/vendor_lunaris_dolby) | `main` | Dolby Atmos |

Smali source for the Motion Sense app: [infinity_OsloFeedback](https://github.com/its-hecker/infinity_OsloFeedback) (`cnb`). The build does not use it directly: it uses the finished APK in the vendor tree.

## Part 1: Build Infinity X on a build server

A ROM build needs an x86-64 Linux machine; it cannot run on a phone. These steps were used on a ServerHive build server running Ubuntu. Plan for at least 16 CPU cores, 32 GB RAM and 300 GB free disk.

### 1. Connect and set up the environment (once)

SSH into the server, then install the build packages:

```bash
sudo apt update
sudo apt install -y bc bison build-essential ccache curl flex g++-multilib gcc-multilib \
  git git-lfs gnupg gperf imagemagick lib32readline-dev lib32z1-dev libelf-dev \
  liblz4-tool libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync \
  schedtool squashfs-tools xsltproc zip zlib1g-dev python3 python-is-python3 unzip
```

Install `repo`:

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
mkdir -p ~/infinityx && cd ~/infinityx
repo init -u https://github.com/projectinfinity-X/manifest -b 17 --git-lfs
git clone https://github.com/its-hecker/local_manifests .repo/local_manifests
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --optimized-fetch --prune
```

The kernel brings KernelSU-Next in as a submodule. If `kernel/google/msm-4.14/KernelSU` is empty after the sync:

```bash
git -C kernel/google/msm-4.14 submodule update --init --recursive
```

If the sync fails with a "duplicate project" error, a project in this manifest is also in the ROM's manifest. Add `<remove-project name="..."/>` for the ROM's copy to `coral.xml`.

### 3. Check the tree before building

```bash
ls kernel/google/msm-4.14/KernelSU/kernel/Kconfig
ls -la kernel/google/msm-4.14/drivers/kernelsu
ls vendor/lunaris/dolby/dolby.mk
ls vendor/google/coral/proprietary/system_ext/priv-app/OsloFeedback/OsloFeedback.apk
```

All four should exist. `drivers/kernelsu` should be a link to `../KernelSU/kernel`.

### 4. Build

```bash
. build/envsetup.sh
lunch lineage_coral-cp2a-user
m selinux_policy
mka bacon
```

`m selinux_policy` checks the SELinux policy in a few minutes, before the full build. Use `lineage_flame-cp2a-user` for the Pixel 4 (flame). `lunch` may also fetch `packages/apps/ElmyraService` (Active Edge), which the device tree lists in `lineage.dependencies`.

The flashable zip is written to `out/target/product/coral/`:

```bash
ls -lh out/target/product/coral/*.zip
```

### 5. Update and rebuild

```bash
cd ~/infinityx
git -C .repo/local_manifests pull
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --optimized-fetch --prune
. build/envsetup.sh
lunch lineage_coral-cp2a-user
mka bacon
```

To pick up a change in only one of these trees, sync just that path, for example `repo sync -c --force-sync vendor/google/coral`.

### After flashing

Open Settings → System → Motion Sense and turn on Use Motion Sense. The page also has the gesture switches, the media app list, the "Control any media app" and "Ignore videos" options, and the glow color.

Testing and troubleshooting are in [MOTION_SENSE.md](MOTION_SENSE.md#testing).

## Part 2: Use these trees for another Android 17 ROM

The trees work on another Android 17 ROM based on LineageOS 24.0 (for example Evolution X 17), but the device tree has Infinity-specific parts. Keep a separate branch of the device tree per ROM (for example `evo-17`, branched from `lineage-24.0`) so Motion Sense fixes can be cherry-picked into all of them.

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
| SystemUI plugin allowlist | `overlay-oslo/frameworks/base/packages/SystemUI/res/values/config.xml` | It holds Infinity's `config_pluginAllowlist` plus `com.google.oslo`. Replace it with the new ROM's own list (`grep -rn config_pluginAllowlist vendor/`) and keep `com.google.oslo` at the end. With Infinity's list, Oslo still loads, but the ROM's own SystemUI plugins stop working. If the ROM does not define the array at all, this folder can stay as it is |
| Common ROM makefile | `lineage_coral.mk`, `lineage_flame.mk` | Replace `vendor/infinity/config/common_full_phone.mk` with the new ROM's common makefile |
| ROM flags | `lineage_coral.mk` | Remove `INFINITY_BUILD`, `INFINITY_MAINTAINER`, `ro.infinity.soc` and `ro.infinity.camera`, and add the new ROM's own flags. Copy them from one of that ROM's official device trees |
| Face unlock flag | `lineage_coral.mk` | `TARGET_FACE_UNLOCK_SUPPORTED := false` is Infinity's switch for its camera face unlock. Use the new ROM's equivalent, if it has one |
| Build target | `lunch` command | The release name (`cp2a`) and product name may differ. Check the ROM's build guide |
| Motion Sense settings page | `parts/` (GoogleParts) | None on a LineageOS-based ROM: it is a separate app that Settings shows by itself, so the ROM's Settings needs no patch. It needs `org.lineageos.settings.resources`, which LineageOS-based ROMs ship |

### What to change in the local manifest

Copy `coral.xml`, point each project at the branch you made for the new ROM, and remove the Dolby project if the ROM already has Dolby. If the ROM's manifest already includes a coral device, vendor or kernel tree, add a `<remove-project>` line for it.

## Credits

- Motion Sense on Android 17: its-hecker. Based on the Android 14 PixysOS port by [Aswin A S](https://github.com/aswin7469), and earlier work by the Dirty Unicorns developers
- Kernel base: [0xSoul24/kernel_google_msm-4.14](https://github.com/0xSoul24/kernel_google_msm-4.14)
- [Project Infinity X](https://github.com/ProjectInfinity-X) and [LineageOS](https://github.com/LineageOS)
