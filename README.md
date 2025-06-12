# iCloudSteal

iCloudSteal is a Bash script that allows you to download all photos from a shared iCloud album. It supports both sequential and concurrent downloading for efficiency.

## Requirements

- Bash
- [jq](https://stedolan.github.io/jq/)
- [curl](https://curl.se/) version `7.68.0` or higher, for concurrent downloads

## Installation

1. Clone this repository:
    ```bash
    git clone https://github.com/thibaudbrg/iCloudSteal.git
    ```
2. Navigate to the directory:
    ```bash
    cd iCloudSteal
    ```

## Usage

```bash
./iCloudSteal.sh --url 'https://www.icloud.com/sharedalbum/#YOUR_ALBUM_ID' [--folder ./target_folder] [--concurrent 1]
```

Replace `YOUR_ALBUM_ID` with the actual Album ID, and optionally specify a target folder and the number of concurrent downloads.
A reasonable starting point is 50. Use higher numbers at your own risk. Too many concurrent downloads may lead to network issues or rate limiting.

As the url contains a `#` character, it must be enclosed in single quotes to prevent shell interpretation.

## Troubleshooting

If you encounter issues, ensure that:

- You have installed all the required tools.
- The URL is accessible and correctly formatted.
- You have not exceeded the rate limits set by the iCloud API.

## Contributions

Feel free to contribute to this project by opening a pull request.