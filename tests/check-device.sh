#!/bin/bash
#
# Functional checks on a running SM-T700 over adb.
#
# Usage: tests/check-device.sh [adb serial]
#
# Enable "Android debugging" and "Rooted debugging" (Developer options) for
# the most complete results. Writes a full report to klimtwifi-report-<date>/.
#

ADB=(adb)
[ -n "${1:-}" ] && ADB=(adb -s "$1")

PASS=0
FAIL=0
WARN=0

ok()   { echo "  [ OK ] $*"; PASS=$((PASS + 1)); }
bad()  { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }
warn() { echo "  [WARN] $*"; WARN=$((WARN + 1)); }
sh()   { "${ADB[@]}" shell "$@" 2>/dev/null | tr -d '\r'; }
prop() { sh getprop "$1"; }

if ! "${ADB[@]}" get-state > /dev/null 2>&1; then
    echo "No device found over adb."
    exit 1
fi
"${ADB[@]}" root > /dev/null 2>&1 && "${ADB[@]}" wait-for-device

REPORT="klimtwifi-report-$(date +%Y%m%d-%H%M%S)"
mkdir -p "${REPORT}"

echo "== System"
[ "$(prop ro.product.device)" = "klimtwifi" ] && ok "device klimtwifi" || warn "device is '$(prop ro.product.device)'"
[ "$(prop sys.boot_completed)" = "1" ] && ok "boot completed" || bad "boot not completed"
echo "  Android $(prop ro.build.version.release), $(prop ro.lineage.version), patch $(prop ro.build.version.security_patch)"
echo "  Kernel: $(sh uname -r)"
selinux="$(sh getenforce)"
[ "${selinux}" = "Enforcing" ] && ok "SELinux ${selinux}" || warn "SELinux ${selinux}"

echo "== Display"
size="$(sh wm size | awk '/Physical/{print $3}')"
[ "${size}" = "1600x2560" ] && ok "resolution ${size}" || bad "resolution '${size}'"
density="$(sh wm density | awk '/Physical/{print $3}')"
[ "${density}" = "320" ] && ok "density ${density}" || warn "density '${density}'"

echo "== Init services"
failed="$(sh getprop | grep -E '^\[init\.svc\.[^]]+\]: \[(restarting|stopped)\]' | grep -vE 'vcsFPService|bootanim|flash_recovery|vendor\.flash|adbd|console|dumpstate|vold_prepare|apexd-snapshotde|derive|odsign|update_verifier|boringssl|gsid|traced_perf|idmap2d|mdnsd|blank_screen|cameraserver|clear-bcb|vdc|storaged|heapprofd')"
if [ -z "${failed}" ]; then ok "no services stuck in restarting/stopped"; else bad "services not running:"; echo "${failed}" | sed 's/^/         /'; fi
for svc in gpsd vendor.gnss_service vendor.sensors-hal-1-0 vendor.wifi_hal_legacy vendor.audio-hal surfaceflinger; do
    state="$(prop "init.svc.${svc}")"
    case "${state}" in
        running) ok "${svc} running" ;;
        "") warn "${svc} not defined (name may differ)" ;;
        *) bad "${svc} ${state}" ;;
    esac
done

echo "== HALs"
sh lshal --neat > "${REPORT}/lshal.txt"
for hal in android.hardware.gnss@1.0::IGnss android.hardware.sensors android.hardware.wifi \
           android.hardware.bluetooth android.hardware.audio android.hardware.graphics.composer \
           android.hardware.camera.provider android.hardware.keymaster android.hardware.health \
           android.hardware.power android.hardware.light android.hardware.vibrator; do
    if grep -q "${hal}" "${REPORT}/lshal.txt"; then ok "${hal}"; else bad "${hal} not registered"; fi
done
sh service list > "${REPORT}/services.txt"
grep -qE 'android.hardware.(health|power|light|vibrator)' "${REPORT}/services.txt" && ok "AIDL HALs listed in service list"

echo "== Wi-Fi"
sh cmd wifi set-wifi-enabled enabled > /dev/null
sleep 3
if sh cmd wifi status | grep -qi 'wifi is enabled'; then ok "wifi enabled"; else bad "wifi does not enable"; fi
sh cmd wifi start-scan > /dev/null; sleep 6
n="$(sh cmd wifi list-scan-results | tail -n +2 | grep -c .)"
[ "${n}" -gt 0 ] && ok "wifi scan found ${n} networks" || bad "wifi scan found nothing"

echo "== Bluetooth"
sh cmd bluetooth_manager enable > /dev/null; sleep 4
state="$(sh dumpsys bluetooth_manager | awk -F': ' '/^ *state:/{print $2; exit}')"
[ "${state}" = "ON" ] && ok "bluetooth ON" || bad "bluetooth state '${state}'"

echo "== Sensors"
sh dumpsys sensorservice > "${REPORT}/sensors.txt"
for s in Accelerometer Gyroscope Magnetic Light Proximity; do
    grep -qi "${s}" "${REPORT}/sensors.txt" && ok "sensor ${s}" || bad "sensor ${s} missing"
done

echo "== GPS"
sh dumpsys location > "${REPORT}/location.txt"
grep -qi 'gps provider' "${REPORT}/location.txt" && ok "gps provider registered" || bad "gps provider missing"
sh ls -d /data/system/gps > /dev/null && ok "/data/system/gps exists" || warn "/data/system/gps missing"

echo "== Audio / Camera / Media"
sh dumpsys media.audio_flinger > "${REPORT}/audio.txt"
grep -q 'Output thread' "${REPORT}/audio.txt" && ok "audio output threads" || bad "no audio output thread"
sh dumpsys media.camera > "${REPORT}/camera.txt"
cams="$(grep -c 'Camera ID' "${REPORT}/camera.txt")"
[ "${cams}" -ge 2 ] && ok "${cams} cameras" || bad "${cams} cameras detected (expected 2)"
sh dumpsys media.player > /dev/null && ok "media.player alive"

echo "== Battery / Storage"
sh dumpsys battery | grep -E 'level|status|temperature|health' | sed 's/^ */  /'
sh df -h /data /system /vendor 2>/dev/null | sed 's/^/  /'

echo "== Stability"
sh logcat -b all -d > "${REPORT}/logcat.txt"
sh dmesg > "${REPORT}/dmesg.txt" 2>/dev/null
avc="$(grep -c 'avc:  denied' "${REPORT}/logcat.txt" "${REPORT}/dmesg.txt" | awk -F: '{s+=$2} END{print s+0}')"
[ "${avc}" -eq 0 ] && ok "no SELinux denials" || warn "${avc} SELinux denials (see ${REPORT}/)"
grep 'avc:  denied' "${REPORT}/logcat.txt" "${REPORT}/dmesg.txt" | grep -oE 'scontext=u:r:[a-z0-9_]+' | sort | uniq -c | sort -rn | head | sed 's/^/         /'
crashes="$(grep -cE 'FATAL EXCEPTION|Fatal signal|ANR in' "${REPORT}/logcat.txt")"
[ "${crashes}" -eq 0 ] && ok "no crashes/ANRs in logcat" || bad "${crashes} crashes/ANRs in logcat"
grep -E 'FATAL EXCEPTION|Fatal signal|ANR in' -A2 "${REPORT}/logcat.txt" | head -20 | sed 's/^/         /'
tomb="$(sh ls /data/tombstones 2>/dev/null | grep -c tombstone)"
[ "${tomb}" -eq 0 ] && ok "no tombstones" || warn "${tomb} tombstones in /data/tombstones"

echo
echo "Result: ${PASS} ok, ${WARN} warnings, ${FAIL} failures (logs in ${REPORT}/)"
[ "${FAIL}" -eq 0 ]
