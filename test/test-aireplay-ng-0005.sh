#!/bin/sh
# Aireplay-ng: Injection test with bitrate

if test ! -z "${CI}"; then exit 77; fi

# Load helper functions
. "${abs_builddir}/../test/int-test-common.sh"

# Check root
check_root

# Check all required tools are installed
check_airmon_ng_deps_present
is_tool_present hostapd

# Load mac80211_hwsim
load_module 2

# Check there are two radios
check_radios_present 2

# Get interfaces names
get_hwsim_interface_name 1
WI_IFACE=${IFACE}
get_hwsim_interface_name 2
WI_IFACE2=${IFACE}

# Set-up hostapd
SSID=thisrocks
CHANNEL=1
TEMP_HOSTAPD_CONF_FILE=$(mktemp)
cat <<EOF > ${TEMP_HOSTAPD_CONF_FILE} 
driver=nl80211
interface=${WI_IFACE}
channel=${CHANNEL}
hw_mode=g
ssid=${SSID}
# Aireplay-ng test 5
EOF

# Start HostAPd
run_hostapd ${TEMP_HOSTAPD_CONF_FILE}
[ $? -eq 0 ] && exit 1

# Put other interface in monitor mode
set_monitor_mode ${WI_IFACE2}
set_interface_channel ${WI_IFACE2} ${CHANNEL}

# Run actual test
OUTPUT_TEMP=$(mktemp)
"${abs_builddir}/../aireplay-ng${EXEEXT}" \
    -9 \
    -B \
    ${WI_IFACE2} \
	2>&1 > ${OUTPUT_TEMP}

# Some cleanup
cleanup

# Then checks
if [ -z "$(grep 'Injection is working!' ${OUTPUT_TEMP})" ]; then
	echo "Injection is not working"
	rm -f ${OUTPUT_TEMP}
	exit 1
fi

if [ -z "$(grep '30/30' ${OUTPUT_TEMP})" ]; then
	echo "AP not present or failure injecting"
	rm -f ${OUTPUT_TEMP}
	exit 1
fi

if [ -z "$(grep 'Probing at 54.0 Mbps:	30/30: 100%' ${OUTPUT_TEMP})" ]; then
	echo "Failed bitrate test"
	rm -f ${OUTPUT_TEMP}
	exit 1
fi

rm ${OUTPUT_TEMP}

exit 0
