#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status

LIB_PATH="$(dirname "$0")"
MAIN_PATH="$(dirname "$LIB_PATH")"
source "$LIB_PATH/log_utils.sh"

init_logging "$MAIN_PATH/log/google_drive_tree.log"

DRIVE_CONFIG_FILE="$MAIN_PATH/secrets/DRIVE_INFO.json"
ROOT_FOLDER_ID=$(jq -r ".target" "$DRIVE_CONFIG_FILE")
GET_FOLDER_CONTENTS="$MAIN_PATH/lib/get_GD_folder_contents.sh"
GD_FILES_LIST="$MAIN_PATH/temp/.google_drive_files"
GD_FOLDERS_LIST="$MAIN_PATH/temp/.google_drive_folders"
API_RESPONSE_FILE="$MAIN_PATH/temp/.api_response.json"

main() {
    if [ -z "$ROOT_FOLDER_ID" ]; then
        echo "ルートフォルダIDが設定されていません。DRIVE_INFO.jsonを確認してください。" >&2
        return 1
    fi

    # Initialize files
    >"$GD_FILES_LIST"
    >"$GD_FOLDERS_LIST"
    >"$API_RESPONSE_FILE"

    if ! "$LIB_PATH/get_access_token.sh"; then
        echo "アクセストークンの取得に失敗しました。" >&2
        return 1
    fi

    if ! process_folder "$ROOT_FOLDER_ID" ""; then
        echo "ルートフォルダの処理中にエラーが発生しました。" >&2
        return 1
    fi

    if ! process_all_subfolders; then
        echo "サブフォルダの処理中にエラーが発生しました。" >&2
        return 1
    fi

    return 0
}

process_folder() {
    local current_folder_id="$1"
    local parent_path="$2"

    if ! "$GET_FOLDER_CONTENTS" "$current_folder_id"; then
        echo "フォルダコンテンツの取得に失敗しました: $parent_path" >&2
        return 1
    fi

    if [ ! -s "$API_RESPONSE_FILE" ]; then
        echo "API response file is empty for folder: $parent_path" >&2
        return 1
    fi

    jq -r --arg parent_path "$parent_path" '.files[] | select(.mimeType != "application/vnd.google-apps.folder") | "\($parent_path)/\(.name) \(.modifiedTime) \(.id)"' "$API_RESPONSE_FILE" >>"$GD_FILES_LIST"
    jq -r --arg parent_path "$parent_path" '.files[] | select(.mimeType == "application/vnd.google-apps.folder") | "\($parent_path)/\(.name) \(.id)"' "$API_RESPONSE_FILE" >>"$GD_FOLDERS_LIST"

    return 0
}

process_all_subfolders() {
    if [ ! -s "$GD_FOLDERS_LIST" ]; then
        return 0
    fi

    while read -r line; do
        folder_path=$(echo "$line" | awk '{print $1}')
        subfolder_id=$(echo "$line" | awk '{print $2}')
        if ! process_folder "$subfolder_id" "$folder_path"; then
            echo "フォルダの処理中にエラーが発生しました: $folder_path" >&2
            return 1
        fi
    done <"$GD_FOLDERS_LIST"

    return 0
}

# Call the main function and capture its exit status
if ! main; then
    exit 1
fi
