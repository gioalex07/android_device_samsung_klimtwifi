# klimtwifi (SM-T700) — LineageOS 21 device tree

Fork of retiredtab's tree; work on branch `lineage-21.0` (default), push to `origin` (gioalex07).
Goal: everything on the tablet working on LineageOS 21.

- Build tree: `/mnt/wsl/android/lineage` (VHDX on D:, mount with `android-disk`). This repo is checked out
  there as `device/samsung/klimtwifi` from the fork; keep both copies in sync via git, not by copying files.
- Dependencies: `device/samsung/klimt-common`, `device/samsung/universal5420-common` (most HALs, sepolicy,
  init), kernel `retiredcrave/android_kernel_samsung_exynos5420`. Patches to repos we don't own go in
  `patches/<project path with / as +>/NNNN-name.patch`.
- Skills: `lineage-build`, `android-device-debug`, `android-hal-revival`, `samsung-flash-t700`.

## Commands
- Static checks: `tests/check-tree.sh [ANDROID_ROOT]` — run before every commit.
- Patch + build + verify: `tools/build-lineage21.sh [patch|build|all]` from the build tree root.
- Output checks: `tests/check-build-output.sh $OUT`; on device: `tests/check-device.sh`.

## Rules
- Commit subjects: `klimtwifi: <imperative summary>`, body explains why.
- Physical partitions: boot 8 MiB, recovery 10 MiB, system 2527068160. BoardConfig values for recovery are
  larger on purpose; never flash a recovery.img over 10485760 bytes.
- A HAL goes into a VINTF `manifest.xml` only after its service runs stably; a declared-but-crashing HAL
  causes bootloops on this device.
- Iterate with `m <module>` + `adb sync`; full `m bacon` only to validate.
