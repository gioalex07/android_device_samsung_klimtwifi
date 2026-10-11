#!/bin/bash
#
# Applies the published LineageOS-UL and Exynos 5420 patches, then builds
# klimtwifi and checks the output.
#
# Usage: device/samsung/klimtwifi/tools/build-lineage21.sh [patch|build|all]
#   Run from the root of the LineageOS-UL 21.0 tree. Patching is idempotent:
#   a patch that is already applied is skipped.
#

set -o pipefail

ANDROID_ROOT="$(pwd)"
DEVICE_DIR="${ANDROID_ROOT}/device/samsung/klimtwifi"
PATCH_DIR="${ANDROID_ROOT}/.klimtwifi-patches"
PATCH_URL="https://raw.githubusercontent.com/retiredtab/LineageOS-build-manifests/main/21"
LOCAL_PATCHES="${DEVICE_DIR}/patches"

if [ ! -f build/envsetup.sh ] || [ ! -d "${DEVICE_DIR}" ]; then
    echo "Run this from the root of the LineageOS tree."
    exit 1
fi

FAILED=()

fetch() {
    local dst="${PATCH_DIR}/$(basename "$1")"
    mkdir -p "${PATCH_DIR}"
    if [ ! -s "${dst}" ] && ! curl -sfL "${PATCH_URL}/$1" -o "${dst}"; then
        rm -f "${dst}"
        return 1
    fi
    echo "${dst}"
}

# apply <project dir> <am|patch> <patch file>
apply() {
    local dir="$1" mode="$2" file="$3" name
    name="$(basename "${file}")"
    if [ ! -f "${file}" ]; then
        echo "  [MISS] ${dir}: ${name}"
        FAILED+=("${dir}: ${name} (missing)")
        return
    fi
    if (cd "${dir}" && git apply --check -p1 "${file}" 2> /dev/null); then
        if [ "${mode}" = am ]; then
            if (cd "${dir}" && git am -q --keep-cr "${file}"); then
                echo "  [ AM ] ${dir}: ${name}"
            else
                (cd "${dir}" && git am --abort)
                echo "  [FAIL] ${dir}: ${name}"
                FAILED+=("${dir}: ${name}")
            fi
        elif (cd "${dir}" && git apply -p1 "${file}"); then
            echo "  [ OK ] ${dir}: ${name}"
        else
            echo "  [FAIL] ${dir}: ${name}"
            FAILED+=("${dir}: ${name}")
        fi
    elif (cd "${dir}" && git apply --check -R -p1 "${file}" 2> /dev/null); then
        echo "  [SKIP] ${dir}: ${name} (already applied)"
    else
        echo "  [FAIL] ${dir}: ${name} (does not apply)"
        FAILED+=("${dir}: ${name}")
    fi
}

do_patch() {
    echo "== LineageOS-UL patches"
    apply packages/modules/Bluetooth am "$(fetch UL-patches-2024/packages_modules_Bluetooth-aug-2024.patch)"
    apply frameworks/av am "$(fetch UL-patches-2024/frameworks-av-sept-2024.patch)"
    apply frameworks/base am "$(fetch UL-patches-2024/frameworks-base-aug-2024.patch)"
    apply frameworks/native am "$(fetch UL-patches-2024/frameworks_native_sept-2024.patch)"
    apply hardware/interfaces am "$(fetch UL-patches-2024/hardware_interfaces-aug-2024.patch)"
    apply vendor/lineage patch "$(fetch UL-patches-2024/vendor_lineage-nov-2024.diff)"
    apply vendor/lineage patch "$(fetch UL-patches-2024/vendor_lineage_skip_abi_checks.patch)"
    apply system/vold patch "$(fetch UL-patches-2024/system_vold_remove_time_offset.diff)"
    apply build/make am "$(fetch UL-patches-2024/build-aug-2024.patch)"
    apply hardware/lineage/interfaces patch "$(fetch UL-patches-2024/hardware_lineage_interfaces.diff)"

    echo "== Exynos 5420 patches"
    apply frameworks/av patch "$(fetch exynos5420/5420-frameworks-av-omx-codecs.diff)"
    # 5420-hardware-samsung-include-ril.diff no longer applies: rebased in patches/hardware+samsung
    apply hardware/samsung_slsi/exynos patch "$(fetch exynos5420/hardware_samsung_slsi_exynos.diff)"
    # hardware_samsung_slsi_exynos5.diff only adds comments (and is corrupt): skipped
    apply hardware/samsung_slsi/exynos5420 patch "$(fetch exynos5420/hardware_samsung_slsi_exynos5420.diff)"

    # libfimg4x/5x -Wunreachable-code-loop-increment fixes (abandoned upstream)
    # shellcheck disable=SC1091
    (source build/envsetup.sh > /dev/null && repopick -f 331660 331661) || FAILED+=("repopick 331660 331661")

    # Patches retiredtab uses but has not published, recreated in this repo.
    # Layout: patches/<project path with / replaced by +>/<NNNN-name>.patch
    if [ -d "${LOCAL_PATCHES}" ]; then
        echo "== klimtwifi patches"
        for d in "${LOCAL_PATCHES}"/*/; do
            local project
            project="$(basename "${d}" | tr '+' '/')"
            for p in "${d}"*.patch; do
                [ -f "${p}" ] && apply "${project}" patch "${p}"
            done
        done
    fi

    echo
    if [ "${#FAILED[@]}" -gt 0 ]; then
        echo "Patches that need attention:"
        printf '  %s\n' "${FAILED[@]}"
        return 1
    fi
    echo "All patches applied."
}

do_build() {
    # shellcheck disable=SC1091
    source build/envsetup.sh
    breakfast klimtwifi || return 1
    # Leave headroom for the rest of the system on a 26 GB WSL VM.
    m -j"$(( $(nproc) > 12 ? 12 : $(nproc) ))" bacon || return 1
    "${DEVICE_DIR}/tests/check-build-output.sh" "${OUT}"
}

case "${1:-all}" in
    patch) do_patch ;;
    build) do_build ;;
    all) do_patch && do_build ;;
    *) echo "Usage: $0 [patch|build|all]"; exit 1 ;;
esac
