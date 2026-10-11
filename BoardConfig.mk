#
# Copyright (C) 2018 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Inherit from klimt-common
include device/samsung/klimt-common/BoardConfigCommon.mk

LOCAL_PATH := device/samsung/klimtwifi

# Assert
TARGET_OTA_ASSERT_DEVICE := klimtwifi,klimtltecan,klimtlte

# Kernel
TARGET_KERNEL_CONFIG := lineageos_klimtwifi_defconfig

# Partitions
BOARD_BOOTIMAGE_PARTITION_SIZE := 8388608
# The physical RECOVERY partition is 10485760 bytes. This value is larger only
# so the build does not fail; never flash a recovery.img bigger than 10485760.
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 13485760
# Physical SYSTEM is 2527068160; kept smaller so the T705 TWRP can flash it.
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 2506096640
BOARD_USERDATAIMAGE_PARTITION_SIZE := 12532580352
BOARD_CACHEIMAGE_PARTITION_SIZE := 209715200
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_FLASH_BLOCK_SIZE := 4096


# Shims
TARGET_LD_SHIM_LIBS += \
    /vendor/bin/gpsd|/vendor/lib/libshim_gpsd.so

# Inherit from the proprietary version
-include vendor/samsung/klimtwifi/BoardConfigVendor.mk
