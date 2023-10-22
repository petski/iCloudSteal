#!/bin/bash

# Requirements: jq
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
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo -e "iCloudSteal -- iCloud Album Downloader\n"
    echo "This script allows you to download all photos from a shared iCloud album."
    echo "You can specify the directory to save the photos."
    echo -e "\nUsage:"
    echo "  $0 --url <URL> [--folder <target folder>]"
    echo -e "\nExample:"
    echo "  $0 --url https://www.icloud.com/sharedalbum/#AAAAAAAAAAAAAAA --folder ./downloads"
    exit 0;
fi

# Default values
TARGET_FOLDER="./"

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        "--url") URL="$2"; shift ;;
        "--folder") TARGET_FOLDER="$2"; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

# Check and validate
if [[ -z "$URL" ]]; then
    echo "Syntax: $0 --url <URL> [--folder <target folder>]" >&2
    exit 1;
fi

validate_url "$URL"

# Check for jq
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

# Create the target folder if it doesn't exist
mkdir -p "$TARGET_FOLDER"
pushd "$TARGET_FOLDER" > /dev/null || exit 4

# Main logic continues here
ALBUM="$(echo $URL | cut -d# -f2)"
BASE_API_URL="https://p23-sharedstreams.icloud.com/${ALBUM}/sharedstreams"

echo "Downloading album '$ALBUM' to '$TARGET_FOLDER'..."
STREAM=$(echo '{"streamCtag":null}' | curl_post_json "$BASE_API_URL/webstream")
CHECKSUMS=$(echo $STREAM | jq -r '.photos[] | .guid')

echo $STREAM \
| jq -c "{photoGuids: [.photos[].photoGuid]}" \
| curl_post_json "$BASE_API_URL/webasseturls" \
| jq -r '.items | to_entries[] | "https://" + .value.url_location + .value.url_path + "&" + .key' \
> urls.txt

TOTAL_IMAGES=$(wc -l < urls.txt)
CURRENT_IMAGE=0

while read -r url; do
    curl -sOJ "$url"
    CURRENT_IMAGE=$((CURRENT_IMAGE + 1))
    progress_bar $CURRENT_IMAGE $TOTAL_IMAGES
done < urls.txt

popd > /dev/null || exit 5
echo -e "\nDownload completed."
