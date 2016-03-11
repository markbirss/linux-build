#!/bin/sh

set -e

URL="https://www.stdin.xyz/downloads/people/longsleep/pine64-images/linux/linux-pine64-latest.tar.xz"
PUBKEY="https://www.stdin.xyz/downloads/people/longsleep/longsleep.asc"
CURRENTFILE="/var/lib/misc/pine64_update_kernel.status"

if [ "$(id -u)" -ne "0" ]; then
	echo "This script requires root."
	exit 1
fi

TEMP=$(mktemp -d)

cleanup() {
	if [ -d "$TEMP" ]; then
		rm -rf "$TEMP"
	fi
}
trap cleanup EXIT

CURRENT=""
if [ -e "${CURRENTFILE}" ]; then
	CURRENT=$(cat $CURRENTFILE)
fi

echo "Checking for update ..."
ETAG=$(curl -I -H 'If-None-Match: "${CURRENT}' -s "${URL}"|grep ETag|awk -F'"' '{print $2}')

if [ "$ETAG" = "$CURRENT" ]; then
	echo "You are already on the latest version - no update required."
	exit 0
fi

FILENAME=$TEMP/$(basename ${URL})

downloadAndApply() {
	echo "Downloading Linux Kernel ..."
	curl "${URL}" --progress-bar --output "${FILENAME}"
	echo "Downloading signature ..."
	curl "${URL}.asc" --progress-bar --output "${FILENAME}.asc"
	echo "Downloading public key ..."
	curl "${PUBKEY}" --progress-bar --output "${TEMP}/pub.asc"

	echo "Verifying signature ..."
	gpg --homedir "${TEMP}" --yes -o "${TEMP}/pub.gpg" --dearmor "${TEMP}/pub.asc"
	gpg --homedir "${TEMP}" --status-fd 1 --no-default-keyring --keyring "${TEMP}/pub.gpg" --trust-model always --verify "${FILENAME}.asc" 2>/dev/null

	echo "Extracting ..."
	tar -C / --numeric-owner -xJf "${FILENAME}"
}

if [ "$1" != "--mark-only" ]; then
	downloadAndApply
	echo "Done - you should reboot now."
fi
echo $ETAG > "$CURRENTFILE"
