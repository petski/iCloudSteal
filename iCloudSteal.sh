#!/bin/bash

# Description: A lightweight and efficient script to download shared photo albums from iCloud.
# 			   Built with Bash and designed for quick, parallelized downloads.
# Requirements: jq
# Usage: ./iCloudSteal.sh <URL> [<target folder>]
# Source: https://github.com/thibaudbrg/iCloudSteal/
# Author: ~thibaudbrg

# Function to validate URL format
validate_url() {
    if [[ ! "$1" =~ ^https://www\.icloud\.com/sharedalbum/# ]]; then
        echo "Invalid URL format" >&2
        exit 1
    fi
}

# Function for POST requests with curl
curl_post_json() {
    curl -sH "Content-Type: application/json" -X POST -d "@-" "$@"
}

# Simple progress bar function
progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local n=$((width * current / total))
    local percentage=$(printf "%.2f" "$(echo "scale=2; 100 * $current / $total" | bc)")

    printf "Progress: ["
    for i in $(seq 1 $n); do printf "#"; done
    for i in $(seq 1 $((width - n))); do printf " "; done
    printf "] %s%%\r" "$percentage"
}

# Check for required arguments and dependencies
if [[ -z "$1" ]]; then
    echo "Syntax: $0 <URL> [<target folder>]" >&2
    exit 1
fi

validate_url "$1"

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required" >&2
    exit 2
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl is required" >&2
    exit 3
fi

ALBUM="$(echo $1 | cut -d# -f2)"
BASE_API_URL="https://p23-sharedstreams.icloud.com/${ALBUM}/sharedstreams"
TARGET_FOLDER="${2:-.}"

echo "Downloading album '$ALBUM' to '$TARGET_FOLDER'..."
pushd "$TARGET_FOLDER" > /dev/null 2>&1 || exit 4

STREAM=$(echo '{"streamCtag":null}' | curl_post_json "$BASE_API_URL/webstream")
HOST=$(echo $STREAM | jq '.["X-Apple-MMe-Host"]' | tr -d '"')

if [ "$HOST" ]; then
    BASE_API_URL="https://$HOST/$(echo $1 | cut -d# -f2)/sharedstreams"
    STREAM=$(echo '{"streamCtag":null}' | curl_post_json "$BASE_API_URL/webstream")
fi

CHECKSUMS=$(echo $STREAM | jq -r '.photos[] | [(.derivatives[] | {size: .fileSize | tonumber, value: .checksum})] | max_by(.size | tonumber).value')

TOTAL_IMAGES=$(echo "$CHECKSUMS" | wc -l)
CURRENT_IMAGE=0

echo $STREAM \
| jq -c "{photoGuids: [.photos[].photoGuid]}" \
| curl_post_json "$BASE_API_URL/webasseturls" \
| jq -r '.items | to_entries[] | "https://" + .value.url_location + .value.url_path + "&" + .key' \
| while read -r URL; do
    for CHECKSUM in $CHECKSUMS; do
        if echo "$URL" | grep -q "$CHECKSUM"; then
            curl -sOJ "$URL" &
            CURRENT_IMAGE=$((CURRENT_IMAGE + 1))
            progress_bar $CURRENT_IMAGE $TOTAL_IMAGES
            break
        fi
    done
done

popd > /dev/null || exit 5
wait
echo "Download completed."
