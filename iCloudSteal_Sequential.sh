#!/usr/bin/env bash
# Source: https://github.com/thibaudbrg/iCloudSteal
# Inspired by https://gist.github.com/fay59/8f719cd81967e0eb2234897491e051ec

# Requirements: jq, curl, bc, md5sum
# Usage: See `show_help` function below for details.

# Default values
TARGET_FOLDER="./"
APPLE_MME_HOST="p23-sharedstreams.icloud.com"

# Check for required commands
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
command -v bc >/dev/null 2>&1 || { echo "bc is required" >&2; exit 1; }
command -v md5sum >/dev/null 2>&1 || { echo "md5sum is required" >&2; exit 1; }

# Validate URL format
function validate_url() {
    if [[ ! "${1}" =~ ^https://www\.icloud\.com/sharedalbum/# ]]; then
        echo "Invalid URL format" >&2
        exit 1
    fi
}

# Progress bar function
function progress_bar() {
    local current="${1}"
    local total="${2}"

    printf "Progress: %s%%\r" "$(echo "scale=2; 100 * ${current} / ${total}" | bc)"
}

# Fetch album metadata from iCloud shared album
function get_album_metadata() {
    local album_id="${1}"
    local filename="album_${album_id}_metadata.json"
    local apple_mme_host="${APPLE_MME_HOST}"
    local metadata
    local curl_exit_code

    # Fetch the metadata from the iCloud shared album
    metadata=$(curl -s -H "Content-Type: application/json" -X POST -d '{"streamCtag":null}' "https://${apple_mme_host}/${album_id}/sharedstreams/webstream")
    curl_exit_code="${?}"
    if [[ "${curl_exit_code}" -ne 0 ]]; then
        echo "Failed to fetch album metadata at ${apple_mme_host}. Exitcode ${curl_exit_code}" >&2
        exit 1
    fi

    # If the metadata contains a X-Apple-MMe-Host, we probably received HTTP status 330. Refetch the metadata from the correct host.
    apple_mme_host=$(echo "${metadata}" | jq -r '.["X-Apple-MMe-Host"] // empty')
    if [ -n "${apple_mme_host}" ]; then
        metadata=$(curl -s -H "Content-Type: application/json" -X POST -d '{"streamCtag":null}' "https://${apple_mme_host}/${album_id}/sharedstreams/webstream")
        curl_exit_code=$?
        if [[ "${curl_exit_code}" -ne 0 ]]; then
            echo "Failed to fetch album metadata at ${apple_mme_host}. Exitcode ${curl_exit_code}" >&2
            exit 1
        fi
    fi

    # Save the metadata to a file
    echo "${metadata}" | tee "${filename}"
}

# Show a summary of the metadata
show_metadata_summary() {
    local metadata="${1}"
    local stream_name
    local photo_count

    stream_name=$(echo "${metadata}" | jq -r '.streamName // "Unknown Album"')
    photo_count=$(echo "${metadata}" | jq '.photos | length')

    echo "Stream Name: '${stream_name}'"
    echo "Photo Count: ${photo_count}"
}

# Get high quality checksums from the metadata
get_uniq_high_quality_checksums() {
    local metadata="${1}"
    local photo_count
    local high_quality_checksums

    # Extract high quality checksums from the metadata
    high_quality_checksums=$(echo "${metadata}" | jq -r '.photos[] | [(.derivatives[] | {size: .fileSize | tonumber, value: .checksum})] | max_by(.size | tonumber).value')
    photo_count=$(echo "${metadata}" | jq '.photos | length')

    # Number of high quality checksums should match the number of photos
    if [[ $(echo "${high_quality_checksums}" | wc -l) -ne "${photo_count}" ]]; then
        echo "Error: Number of high quality checksums does not match the number of photos." >&2
        exit 1
    fi

    echo "${high_quality_checksums}" | sort | uniq
}

# Get URLs from the metadata
get_urls_from_metadata() {
    local album_id="${1}"
    local metadata="${2}"
    local apple_mme_host="${APPLE_MME_HOST}"
    local photo_guids
    local assetdata
    local curl_exit_code

    photo_guids=$(echo "$metadata" | jq -c "{photoGuids: [.photos[].photoGuid]}")

    # Fetch the assetdata from the iCloud shared album
    assetdata=$(echo "$photo_guids" | curl -s -H "Content-Type: application/json" -X POST -d "@-" "https://${apple_mme_host}/${album_id}/sharedstreams/webasseturls")
    curl_exit_code=$?
    if [[ "${curl_exit_code}" -ne 0 ]]; then
        echo "Failed to fetch album assetdata at ${apple_mme_host}. Exitcode ${curl_exit_code}" >&2
        exit 1
    fi

    # If the assetdata contains a X-Apple-MMe-Host, we probably received HTTP status 330. Refetch the assetdata from the correct host.
    apple_mme_host=$(echo "$assetdata" | jq -r '.["X-Apple-MMe-Host"] // empty')
    if [ -n "${apple_mme_host}" ]; then
        assetdata=$(echo "$photo_guids" | curl -s -H "Content-Type: application/json" -X POST -d "@-" "https://${apple_mme_host}/${album_id}/sharedstreams/webasseturls")
        curl_exit_code=$?
        if [[ "${curl_exit_code}" -ne 0 ]]; then
            echo "Failed to fetch album assetdata at ${apple_mme_host}. Exitcode ${curl_exit_code}" >&2
            exit 1
        fi
    fi

    echo "${assetdata}" | jq -r '.items | to_entries[] | "https://" + .value.url_location + .value.url_path + "&" + .key'
}

# Show help message
show_help() {
    echo -e "iCloudSteal -- iCloud Album Downloader\n" >&2
    echo "This script allows you to download all photos from a shared iCloud album." >&2
    echo "You can specify the directory to save the photos." >&2
    echo -e "\nUsage:" >&2
    echo "  ${0} --url <URL> [--folder <target folder>]" >&2
    echo -e "\nExample:" >&2
    echo "  ${0} --url 'https://www.icloud.com/sharedalbum/#AAAAAAAAAAAAAAA' --folder ./downloads" >&2
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case "${1}" in
        "--url") URL="${2}"; shift ;;
        "--folder") TARGET_FOLDER="${2}"; shift ;;
        "--help" | "-h") show_help; exit 1 ;;
        *) echo "Unknown option: ${1}" >&2; show_help; exit 1 ;;
    esac
    shift
done

# Check and validate
if [[ -z "${URL}" ]]; then
    echo "Syntax: ${0} --url <URL> [--folder <target folder>]" >&2
    exit 1;
fi

validate_url "${URL}"
ALBUM_ID="$(echo "$URL" | cut -d'#' -f2)"

echo "Downloading '${ALBUM_ID}' to '${TARGET_FOLDER}'..."

# Create the target folder if it doesn't exist
mkdir -p "${TARGET_FOLDER}"
pushd "${TARGET_FOLDER}" > /dev/null || exit 1

METADATA=$(get_album_metadata "$ALBUM_ID")
show_metadata_summary "${METADATA}"

HIGH_QUALITY_CHECKSUMS=$(get_uniq_high_quality_checksums "$METADATA")
HIGH_QUALITY_CHECKSUM_FILE="album_${ALBUM_ID}_high_quality_checksums.txt"
printf "%s\n" "${HIGH_QUALITY_CHECKSUMS}" > "${HIGH_QUALITY_CHECKSUM_FILE}"

URLS=$(get_urls_from_metadata "$ALBUM_ID" "$METADATA")
URL_FILE="album_${ALBUM_ID}_urls.txt"
printf "%s\n" "${URLS}" > "${URL_FILE}"

TOTAL_IMAGES=$(wc -l < "$HIGH_QUALITY_CHECKSUM_FILE")
CURRENT_IMAGE=0

echo "Total (unique) images to download: ${TOTAL_IMAGES}"

TMP_DIR=$(mktemp -d)

while read -r CHECKSUM; do
    FOUND=0
    while read -r URL; do
        if [[ "${URL}" == *"${CHECKSUM}"* ]]; then
            FOUND=1
            curl --output-dir "${TMP_DIR}" -sOJ "${URL}"
            CURL_EXIT_CODE=$?
            if [[ ${CURL_EXIT_CODE} -ne 0 ]]; then
                echo "Warning: Exitcode ${CURL_EXIT_CODE}. Failed to download ${URL}" >&2
                echo "${URL}" >> "album_${ALBUM_ID}_urls_failed.txt"
                continue
            fi

            # Move the downloaded file to the target folder
            for DOWNLOADED_FILE in "${TMP_DIR}"/*; do
                DOWNLOADED_FILENAME=$(basename "$DOWNLOADED_FILE")
                if [ ! -f "${TARGET_FOLDER}/${DOWNLOADED_FILENAME}" ]; then
                    mv "${DOWNLOADED_FILE}" "${TARGET_FOLDER}/${DOWNLOADED_FILENAME}"
                    break;
                fi;

                EXISTING_CHECKSUM=$(md5sum "$TARGET_FOLDER/$DOWNLOADED_FILENAME" | cut -d' ' -f1)
                NEW_CHECKSUM=$(md5sum "$DOWNLOADED_FILE" | cut -d' ' -f1)

                if [[ "${EXISTING_CHECKSUM}" != "${NEW_CHECKSUM}" ]]; then
                    echo "File ${DOWNLOADED_FILENAME} checksum found with different checksums, keeping both versions." >&2
                    mv "${DOWNLOADED_FILE}" "${TARGET_FOLDER}/${DOWNLOADED_FILENAME}.${NEW_CHECKSUM}"
                    break;
                fi

                echo "File ${DOWNLOADED_FILENAME} already exists with same checkum, skipping." >&2
                rm -f "${DOWNLOADED_FILE}"
            done

            CURRENT_IMAGE=$((CURRENT_IMAGE + 1))
            progress_bar "${CURRENT_IMAGE}" "${TOTAL_IMAGES}"
            break
        fi
    done < "${URL_FILE}"
    if [[ ${FOUND} -eq 0 ]]; then
        echo "Warning: Checksum ${CHECKSUM} not found in URLs." >&2
    fi
done < "${HIGH_QUALITY_CHECKSUM_FILE}"

rm -rf "${TMP_DIR}"

popd > /dev/null || exit 1
echo -e "\nDownload completed."
