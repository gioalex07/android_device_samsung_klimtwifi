Copyright 2020 - The LineageOS Project

Device configuration for Samsung Galaxy Tab S 8.4 (SM-T700).
========================================

Basic   | Specification List
-------:|:-------------------------
CPU     | Quad-core 1.9 GHz + Quad-core 1.3 GHz
Chipset | Samsung Exynos 5420
GPU     | ARM Mali-T628 MP6
Memory  | 3 GB
Shipped Android Version | 4.4.2
Storage | 16/32 GB
MicroSD | Up to 256 GB
Battery | Li-Ion 4900 mAh
Dimensions | 218,8 mm x 125.6 mm x 6,6 mm
Display | 2560 x 1600 pixel, 8.4"
Rear Camera  | 8.0 MP AF
Front Camera | 2.1 MP
Release Date | July 2014

![Galaxy Tab S 8.4](https://fdn2.gsmarena.com/vv/pics/samsung/samsung-galaxy-tab-s-84-1.jpg "Galaxy Tab S 8.4")

Building LineageOS 21
---------------------

This tree is built on top of LineageOS-UL 21.0 together with the Exynos 5420
local manifest and patches maintained at
https://github.com/retiredtab/LineageOS-build-manifests/tree/main/21/exynos5420
(read `5420-build-instructions.txt` there; it changes month to month).

Plan for about 300 GB of free disk and 64 GB of RAM + swap.

```
repo init -u https://github.com/LineageOS-UL/android.git -b lineage-21.0 --git-lfs --depth=1
# copy 5420-21.xml into .repo/local_manifests/, sync, apply the UL and 5420 patches
. build/envsetup.sh
brunch klimtwifi
```

Install with TWRP. The physical RECOVERY partition is 10 MiB, so never flash a
recovery.img larger than 10485760 bytes.

Known limitations: fingerprint (HAL disabled), IR blaster (removed, it made the
OS fail to boot) and LiveDisplay (removed for the same reason).

Tests
-----

* `tests/check-tree.sh [ANDROID_ROOT]`: static checks of this tree, and of
  klimt-common, vendor blobs and kernel when the source root is given.
* `tests/check-build-output.sh [OUT]`: checks image sizes against the physical
  partitions and the OTA zip before flashing.
* `tests/check-device.sh [serial]`: functional checks on the tablet over adb
  (Wi-Fi, Bluetooth, sensors, GPS, audio, camera, SELinux denials, crashes).
