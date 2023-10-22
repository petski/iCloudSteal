# iCloudSteal

iCloudSteal is a Bash script that allows you to download all photos from a shared iCloud album. It supports both sequential and concurrent downloading for efficiency.

## Requirements

- Bash
- [jq](https://stedolan.github.io/jq/)
- [curl](https://curl.se/)
- [GNU Parallel](https://www.gnu.org/software/parallel/) (Only for concurrent downloads)

## Installation

1. Clone this repository:
    ```bash
    git clone https://github.com/thibaudbrg/iCloudSteal.git
    ```
2. Navigate to the directory:
    ```bash
    cd iCloudSteal
    ```
3. Make the scripts executable:
    ```bash
    chmod +x *.sh
    ```

## Usage

### Sequential Downloads

To download photos sequentially, run the following command:

```bash
./iCloudSteal_Sequential.sh --url https://www.icloud.com/sharedalbum/#YOUR_ALBUM_ID [--folder ./target_folder]
```

### Concurrent Downloads

To download photos with multiple concurrent downloads, run the following command:

```bash
./iCloudSteal_Concurrent.sh --url https://www.icloud.com/sharedalbum/#YOUR_ALBUM_ID [--folder ./target_folder] [--concurrent 25]
```

Replace `YOUR_ALBUM_ID` with the actual Album ID, and optionally specify a target folder and the number of concurrent downloads.
A reasonable starting point is 50. Use higher numbers at your own risk. Too many concurrent downloads may lead to network issues or rate limiting.

## Troubleshooting

If you encounter issues, ensure that:

- You have installed all the required tools.
- The URL is accessible and correctly formatted.
- You have not exceeded the rate limits set by the iCloud API.

## Progress Bar

Both versions of the script come with a simple progress bar to track the download process.

## Contributions

Feel free to contribute to this project by opening a pull request.

