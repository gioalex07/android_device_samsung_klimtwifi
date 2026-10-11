#!/bin/bash
#
# Static sanity checks for the klimtwifi device tree.
#
# Usage: tests/check-tree.sh [ANDROID_ROOT]
#
# Works on a bare checkout of this repo. When ANDROID_ROOT (the LineageOS
# source tree) is given, it also cross-checks klimt-common, the vendor blobs
# and the kernel defconfig.
#

MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_ROOT="${1:-}"

PASS=0
FAIL=0
WARN=0

ok()   { echo "  [ OK ] $*"; PASS=$((PASS + 1)); }
bad()  { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }
warn() { echo "  [WARN] $*"; WARN=$((WARN + 1)); }

mk_value() {
    sed -n "s/^${1}[[:space:]]*:\?=[[:space:]]*//p" "${MY_DIR}/BoardConfig.mk" | tail -n1
}

echo "== Shell scripts"
for f in "${MY_DIR}"/*.sh "${MY_DIR}"/tests/*.sh; do
    if bash -n "${f}" 2>/dev/null; then ok "syntax ${f#${MY_DIR}/}"; else bad "syntax ${f#${MY_DIR}/}"; fi
done
if grep -q 'vendor/lineage/build/tools/extract_utils.sh' "${MY_DIR}"/*.sh; then
    bad "extract scripts use the pre-21 helper path (vendor/lineage/build/tools)"
else
    ok "extract scripts use tools/extract-utils"
fi

echo "== XML / JSON"
while IFS= read -r -d '' f; do
    if python3 -I -c 'import sys, xml.dom.minidom; xml.dom.minidom.parse(sys.argv[1])' "${f}" 2>/dev/null; then
        ok "xml ${f#${MY_DIR}/}"
    else
        bad "xml ${f#${MY_DIR}/}"
    fi
done < <(find "${MY_DIR}" -path "${MY_DIR}/.git" -prune -o -name '*.xml' -print0)
if python3 -I -c 'import json, sys; json.load(open(sys.argv[1]))' "${MY_DIR}/lineage.dependencies" 2>/dev/null; then
    ok "json lineage.dependencies"
else
    bad "json lineage.dependencies"
fi

echo "== BoardConfig"
assert="$(mk_value TARGET_OTA_ASSERT_DEVICE)"
case "${assert}" in
    *,|,*|*,,*) bad "TARGET_OTA_ASSERT_DEVICE has an empty entry: '${assert}'" ;;
    *klimtwifi*) ok "TARGET_OTA_ASSERT_DEVICE = ${assert}" ;;
    *) bad "TARGET_OTA_ASSERT_DEVICE does not include klimtwifi" ;;
esac
# Physical sizes from the stock PIT (same values as the official TWRP tree)
for spec in BOOT:8388608 RECOVERY:10485760 SYSTEM:2527068160; do
    name="${spec%%:*}"; phys="${spec##*:}"
    val="$(mk_value "BOARD_${name}IMAGE_PARTITION_SIZE")"
    if [ -z "${val}" ]; then
        bad "BOARD_${name}IMAGE_PARTITION_SIZE not set"
    elif [ "${val}" -gt "${phys}" ]; then
        warn "BOARD_${name}IMAGE_PARTITION_SIZE=${val} > physical ${phys} (check image size after build)"
    else
        ok "BOARD_${name}IMAGE_PARTITION_SIZE=${val} <= physical ${phys}"
    fi
done

echo "== init scripts"
if grep -qE '^\s*(start|stop)\s+ril-daemon' "${MY_DIR}"/ramdisk/etc/*.rc; then
    warn "init references ril-daemon, which does not exist on a wifi-only build"
else
    ok "no ril-daemon references"
fi

if [ -z "${ANDROID_ROOT}" ]; then
    echo
    echo "(pass ANDROID_ROOT to also check klimt-common, vendor blobs and kernel)"
else
    ANDROID_ROOT="$(cd "${ANDROID_ROOT}" && pwd)"
    echo "== Source tree: ${ANDROID_ROOT}"

    for d in device/samsung/klimt-common device/samsung/universal5420-common \
             vendor/samsung/klimtwifi vendor/samsung/klimt-common \
             vendor/samsung/universal5420-common kernel/samsung/exynos5420 \
             hardware/samsung tools/extract-utils device/samsung_slsi/sepolicy; do
        if [ -d "${ANDROID_ROOT}/${d}" ]; then ok "present ${d}"; else bad "missing ${d}"; fi
    done

    defconfig="$(mk_value TARGET_KERNEL_CONFIG)"
    if [ -f "${ANDROID_ROOT}/kernel/samsung/exynos5420/arch/arm/configs/${defconfig}" ]; then
        ok "kernel defconfig ${defconfig}"
    else
        bad "kernel defconfig ${defconfig} not found"
    fi

    blobs="${ANDROID_ROOT}/vendor/samsung/klimtwifi/proprietary"
    if [ -d "${blobs}" ]; then
        missing=0
        while IFS= read -r line; do
            line="${line%%#*}"; line="${line#-}"
            [ -z "${line// }" ] && continue
            spec="${line%%;*}"
            dst="${spec##*:}"
            if [ ! -f "${blobs}/${dst}" ]; then
                bad "blob missing: ${dst}"
                missing=$((missing + 1))
            fi
        done < "${MY_DIR}/proprietary-files.txt"
        [ "${missing}" -eq 0 ] && ok "all proprietary-files.txt blobs present"

        if grep -aq 'SSLv3_client_method' "${blobs}/vendor/bin/gpsd" 2>/dev/null; then
            bad "gpsd still imports SSLv3_client_method (blob_fixup not applied)"
        else
            ok "gpsd SSLv3 patch applied"
        fi
        if grep -aq 'system/etc/floating_feature' "${blobs}/vendor/lib/libfloatingfeature.so" 2>/dev/null; then
            bad "libfloatingfeature.so still points to /system/etc"
        else
            ok "libfloatingfeature.so points to /vendor/etc"
        fi
    fi

    # Every service started from our init.target.rc needs an SELinux domain,
    # otherwise init refuses to start it on an enforcing build.
    fc="${ANDROID_ROOT}/device/samsung/universal5420-common/sepolicy/vendor/file_contexts"
    while read -r _ name path _; do
        if grep -q "$(basename "${path}")" "${fc}" 2>/dev/null; then
            ok "sepolicy label for service ${name}"
        else
            bad "no sepolicy label for service ${name} (${path})"
        fi
    done < <(grep -E '^service ' "${MY_DIR}"/ramdisk/etc/*.rc)
fi

echo
echo "Result: ${PASS} ok, ${WARN} warnings, ${FAIL} failures"
[ "${FAIL}" -eq 0 ]
