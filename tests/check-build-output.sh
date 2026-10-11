#!/bin/bash
#
# Checks the images produced by "brunch klimtwifi" before flashing them.
#
# Usage: tests/check-build-output.sh [OUT_DIR]
#   OUT_DIR defaults to $OUT, then to out/target/product/klimtwifi.
#

OUT_DIR="${1:-${OUT:-out/target/product/klimtwifi}}"

PASS=0
FAIL=0
WARN=0

ok()   { echo "  [ OK ] $*"; PASS=$((PASS + 1)); }
bad()  { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }
warn() { echo "  [WARN] $*"; WARN=$((WARN + 1)); }

if [ ! -d "${OUT_DIR}" ]; then
    echo "Output directory not found: ${OUT_DIR}"
    exit 1
fi

echo "== Image sizes vs physical partitions (${OUT_DIR})"
# Physical sizes from the stock PIT, not the BoardConfig values.
for spec in boot.img:8388608 recovery.img:10485760 system.img:2527068160; do
    img="${spec%%:*}"; limit="${spec##*:}"
    f="${OUT_DIR}/${img}"
    if [ ! -f "${f}" ]; then
        if [ "${img}" = "recovery.img" ]; then warn "${img} not built"; else bad "${img} not found"; fi
        continue
    fi
    size="$(stat -c %s "${f}")"
    if [ "${size}" -le "${limit}" ]; then
        ok "${img} ${size} <= ${limit}"
    elif [ "${img}" = "recovery.img" ]; then
        bad "${img} ${size} > ${limit}: DO NOT flash it, use TWRP instead"
    else
        bad "${img} ${size} > ${limit}"
    fi
done

echo "== Flashable zip"
zip="$(ls -t "${OUT_DIR}"/lineage-21.0-*-klimtwifi.zip 2>/dev/null | head -n1)"
if [ -z "${zip}" ]; then
    bad "no lineage-21.0-*-klimtwifi.zip found"
else
    ok "zip $(basename "${zip}") ($(du -h "${zip}" | cut -f1))"
    script="$(unzip -p "${zip}" META-INF/com/google/android/updater-script 2>/dev/null)"
    if [ -z "${script}" ]; then
        bad "updater-script missing from zip"
    else
        for dev in klimtwifi klimtlte klimtltecan; do
            if grep -q "== \"${dev}\"" <<< "${script}"; then ok "assert allows ${dev}"; else bad "assert does not allow ${dev}"; fi
        done
        if grep -q '== ""' <<< "${script}"; then
            bad "assert contains an empty device entry"
        else
            ok "assert has no empty device entry"
        fi
    fi
    for entry in boot.img system.transfer.list; do
        if unzip -l "${zip}" "${entry}" > /dev/null 2>&1; then ok "zip contains ${entry}"; else bad "zip lacks ${entry}"; fi
    done
fi

echo "== Vendor contents"
vendor="${OUT_DIR}/vendor"
for f in bin/gpsd etc/gps.xml lib/hw/gps.universal5420.so lib/libshim_gpsd.so \
         lib/sensors.universal5420.so etc/init/hw/init.target.rc etc/floating_feature.xml; do
    if [ -e "${vendor}/${f}" ]; then ok "vendor/${f}"; else bad "vendor/${f} missing"; fi
done
if [ -f "${vendor}/bin/gpsd" ] && grep -aq 'SSLv3_client_method' "${vendor}/bin/gpsd"; then
    bad "vendor/bin/gpsd still imports SSLv3_client_method"
fi

echo "== Build properties"
prop="${OUT_DIR}/system/build.prop"
if [ -f "${prop}" ]; then
    grep -E '^ro\.(product\.system\.device|build\.(fingerprint|version\.release|version\.security_patch))=' "${prop}" | sed 's/^/  /'
else
    warn "system/build.prop not found"
fi

echo
echo "Result: ${PASS} ok, ${WARN} warnings, ${FAIL} failures"
[ "${FAIL}" -eq 0 ]
