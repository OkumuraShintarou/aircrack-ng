#!/bin/sh
# Airodump-ng: Test WPA3 (OWE) detection

if test ! -z "${CI}"; then exit 77; fi

# Load helper functions
. "${abs_builddir}/../test/int-test-common.sh"

# Check root
check_root

# Check all required tools are installed
check_airmon_ng_deps_present
is_tool_present screen
is_tool_present hostapd

# Check HostAPd version supports WPA3
HOSTAPD_VER="$(hostapd -v 2>&1 | grep hostapd | awk '{print $2}')"
if [ -z "${HOSTAPD_VER}" ]; then
	echo "Failed getting hostapd version, skipping"
	exit 1
elif [ "$(echo ${HOSTAPD_VER} | grep -v -E '^v((2\.[789])|(3.[0-9]))')" ]; then
	echo "hostapd version does not support WPA3, skipping"
	echo "v2.7+ required, got ${HOSTAPD_VER}"
	exit 77
fi

# Load mac80211_hwsim
load_module 1

# Check there are two radios
check_radios_present 1

# Get interfaces names
get_hwsim_interface_name 1
WI_IFACE=${IFACE}

# Start hostapd with WPA3
cat >> ${TEMP_HOSTAPD_CONF_FILE} << EOF
interface=${WI_IFACE}
ssid=test
channel=1
wpa=2
wpa_passphrase=password
wpa_key_mgmt=OWE
rsn_pairwise=CCMP
ieee80211w=2
# Airodump-ng test 3
EOF

# Start hostapd
run_hostapd ${TEMP_HOSTAPD_CONF_FILE}

# Start hwsim0
ip link set hwsim0 up

TEMP_FILE=$(mktemp -u)
screen -AmdS capture \
	timeout 4 \
		"${abs_builddir}/../airodump-ng" \
			hwsim0 \
			-c 1 \
			-w ${TEMP_FILE} \
			--background 1

# Wait a few seconds for it to finish
sleep 6

# Some cleanup
cleanup

# Check CSV
ENCRYPTION_SECTION="$(head -n 3 ${TEMP_FILE}-01.csv | tail -n 1 | gawk -F, '{print $6 $7 $8}')"
if [ -z "${ENCRYPTION_SECTION}" ]; then
	echo "Something failed with airodump-ng, did not get info from CSV"
	rm -f ${TEMP_FILE}-01.*
	exit 1
elif [ "$(echo ${ENCRYPTION_SECTION} | tr -d ' ')" != 'WPA3WPA2CCMPOWE' ]; then
	echo "Encryption section is not what is expected. Got ${ENCRYPTION_SECTION}"
	rm -f ${TEMP_FILE}-01.*
	exit 1
fi

# Check NetXML
if [ ! -f ${TEMP_FILE}-01.kismet.netxml ]; then
	echo "Kismet netxml file not found"
	rm -f ${TEMP_FILE}-01.*
	exit 1
fi
ENCRYPTION_SECTION="$(grep '<encryption>WPA+OWE</encryption>' ${TEMP_FILE}-01.kismet.netxml)"
if [ -z "${ENCRYPTION_SECTION}" ]; then
        echo "Failed to find OWE in the kismet netxml"
	rm -f ${TEMP_FILE}-01.*
        exit 1
fi

# Check Kismet CSV
if [ ! -f ${TEMP_FILE}-01.kismet.csv ]; then
	echo 'Kismet CSV not found'
	rm -f ${TEMP_FILE}-01.*
	exit 1
fi
ENCRYPTION_SECTION="$(tail -n 1 ${TEMP_FILE}-01.kismet.csv | gawk -F\; '{print $8}')"
if [ "x${ENCRYPTION_SECTION}" != 'xWPA3,AES-CCM,OWE' ]; then
	echo "Encryption section not found or invalid in Kismet CSV"
	echo "Expected 'OWE,AES-CCM,SAE', got ${ENCRYPTION_SECTION}"
	rm -f ${TEMP_FILE}-01.*
	exit 1
fi

# Cleanup
rm -f ${TEMP_FILE}-01.*

exit 0
