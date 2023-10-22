#!/bin/bash

# Requirements: jq, parallel
# Usage: See Help Section

# Function to validate URL format
function validate_url() {
    if [[ ! "$1" =~ ^https://www\.icloud\.com/sharedalbum/# ]]; then
        echo "Invalid URL format" >&2
        exit 1
    fi
}

# Function for POST requests with curl
function curl_post_json() {
    curl -sH "Content-Type: application/json" -X POST -d "@-" "$@"
}

# Progress bar function
function progress_bar() {
    local current=$1
    local total=$2
    local percentage=$(echo "scale=2; 100 * $current / $total" | bc)
    printf "Progress: %s%%\r" "$percentage"
}

# Help Section
if [[ "$1" == "-h" || "$1" == "--help" || "$1" == "-help" ]]; then
    echo -e "iCloudSteal -- iCloud Album Downloader\n"
    echo "This script allows you to download all photos from a shared iCloud album."
    echo "You can specify the directory to save the photos as well as control the number of concurrent downloads."
    echo -e "\nUsage:"
    echo "  $0 --url <URL> [--folder <target folder>] [--concurrent <concurrent downloads>]"
    echo -e "\nExample:"
    echo "  $0 --url https://www.icloud.com/sharedalbum/#AAAAAAAAAAAAAAA --folder ./downloads --concurrent 10"
    echo -e "\nConcurrent Downloads:"
    echo "  You can specify the number of concurrent downloads for efficiency."
    echo "  A reasonable starting point is 50. Use higher numbers at your own risk."
    echo "  Too many concurrent downloads may lead to network issues or rate limiting."
    exit 0;
fi

# Default values
TARGET_FOLDER="./"
CONCURRENT_DOWNLOADS=25

# Parse arguments
for arg in "$@"; do
  shift
  case "$arg" in
    "--url") set -- "$@" "-u" ;;
    "--folder") set -- "$@" "-f" ;;
    "--concurrent") set -- "$@" "-c" ;;
    *) set -- "$@" "$arg"
  esac
done

while getopts ":u:f:c:" opt; do
  case $opt in
    u) URL="$OPTARG" ;;
    f) TARGET_FOLDER="$OPTARG" ;;
    c) CONCURRENT_DOWNLOADS="$OPTARG" ;;
    \?) echo "Invalid option -$OPTARG" >&2; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
  esac
done

# Check and validate
if [[ -z "$URL" ]]; then
    echo "Syntax: $0 --url <URL> [--folder <target folder>] [--concurrent <concurrent downloads>]" >&2
    exit 1;
fi

validate_url "$URL"

# Check for jq and parallel
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }
command -v parallel >/dev/null 2>&1 || { echo "parallel is required" >&2; exit 3; }

# Assign variables
ALBUM="$(echo $URL | cut -d# -f2)"
BASE_API_URL="https://p23-sharedstreams.icloud.com/${ALBUM}/sharedstreams"

# Main program
echo "Downloading album '$ALBUM' to '$TARGET_FOLDER' with $CONCURRENT_DOWNLOADS concurrent downloads..."
# Create the target folder if it doesn't exist
mkdir -p "$TARGET_FOLDER"
pushd "$TARGET_FOLDER" > /dev/null || exit 4

STREAM=$(echo '{"streamCtag":null}' | curl_post_json "$BASE_API_URL/webstream")
CHECKSUMS=$(echo $STREAM | jq -r '.photos[] | .guid')

echo $STREAM \
| jq -c "{photoGuids: [.photos[].photoGuid]}" \
| curl_post_json "$BASE_API_URL/webasseturls" \
| jq -r '.items | to_entries[] | "https://" + .value.url_location + .value.url_path + "&" + .key' \
> urls.txt

TOTAL_IMAGES=$(wc -l < urls.txt)
CURRENT_IMAGE=0

cat urls.txt | parallel -j $CONCURRENT_DOWNLOADS 'curl -sOJ {} && echo Done' | while read -r _; do
    CURRENT_IMAGE=$((CURRENT_IMAGE + 1))
    progress_bar $CURRENT_IMAGE $TOTAL_IMAGES
done

popd > /dev/null || exit 5
echo -e "\nDownload completed."
