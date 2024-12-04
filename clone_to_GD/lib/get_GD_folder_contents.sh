#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status

LIB="$(dirname "$0")"
MAIN="$(dirname "$LIB")"
TEMP="$MAIN/temp"
source "$LIB/log_utils.sh"

init_logging "$MAIN/log/get_GD_folder_contents.log"

ACCESS_TOKEN_FILE="$MAIN/secrets/ACCESS_TOKEN.json"
RESPONSE_LOG="$MAIN/log/response_get_contents.log"
CONTENTS_LIST_FILE="$MAIN/temp/.GD_contents"
API_RESPONSE_FILE="$MAIN/temp/.api_response.json"

call_get_request() {
    local folder_id=$1
    local page_token=$2
    local access_token=$3

    local response=$(curl -s -X GET \
        -H "Authorization: Bearer $access_token" \
        "https://www.googleapis.com/drive/v3/files?q='$folder_id'+in+parents&fields=nextPageToken,files(id,name,modifiedTime,mimeType)&pageToken=$page_token")

    echo "$response" >>"$RESPONSE_LOG"
    echo "$response"
}

main() {
    local folder_id="$1"

    if [ -z "$folder_id" ]; then
        echo "フォルダIDが指定されていません。" >&2
        return 1
    fi

    access_token=$(jq -r ".access_token" "$ACCESS_TOKEN_FILE")
    if [ -z "$access_token" ]; then
        echo "アクセストークンの読み込みに失敗しました。" >&2
        return 1
    fi

    mkdir -p "$TEMP"

    # Initialize files
    >"$RESPONSE_LOG"
    >"$CONTENTS_LIST_FILE"
    >"$API_RESPONSE_FILE"

    # Initial fetch
    response=$(call_get_request "$folder_id" "" "$access_token")
    echo "$response" >"$API_RESPONSE_FILE"
    next_page_token=$(echo "$response" | jq -r ".nextPageToken")

    # Extract files and append to CONTENTS_LIST_FILE
    echo "$response" | jq -r ".files[] | \"\(.name) \(.id) \(.modifiedTime) \(.mimeType)\"" >>"$CONTENTS_LIST_FILE"

    # Fetch remaining pages
    while [ "$next_page_token" != "null" ] && [ -n "$next_page_token" ]; do
        response=$(call_get_request "$folder_id" "$next_page_token" "$access_token")
        next_page_token=$(echo "$response" | jq -r ".nextPageToken")

        # Extract files and append to CONTENTS_LIST_FILE
        echo "$response" | jq -r ".files[] | \"\(.name) \(.id) \(.modifiedTime) \(.mimeType)\"" >>"$CONTENTS_LIST_FILE"
    done

    if [ ! -s "$CONTENTS_LIST_FILE" ]; then
        echo "フォルダコンテンツの取得に失敗しました。" >&2
        return 1
    fi

    return 0
}

# Call the main function and capture its exit status
if ! main "$1"; then
    exit 1
fi
