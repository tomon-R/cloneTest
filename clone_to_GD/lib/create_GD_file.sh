#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status

LIB="$(dirname "$0")"
MAIN="$(dirname "$LIB")"
source "$LIB/log_utils.sh"

init_logging "$MAIN/log/create_GD_file.log"

TO_CREATE_FILE="$MAIN/temp/.files_to_create"
FOLDERS_TO_CREATE_FILE="$MAIN/temp/.folders_to_create"
GD_FOLDERS="$MAIN/temp/.google_drive_folders"
ACCESS_TOKEN_FILE="$MAIN/secrets/ACCESS_TOKEN.json"
DRIVE_INFO_FILE="$MAIN/secrets/DRIVE_INFO.json"
LOCAL_INFO_FILE="$MAIN/secrets/LOCAL_INFO.json"
FOLDER_RESPONSE_LOG="$MAIN/log/response_create_folders.log"
FILE_RESPONSE_LOG="$MAIN/log/response_create_files.log"

main() {
    local error_message=""

    log_message "Google Driveへのファイル作成を開始します。"

    # Wrap the main logic in a subshell to capture the error message
    error_message=$(
        {
            ACCESS_TOKEN=$(jq -r ".access_token" "$ACCESS_TOKEN_FILE")
            TARGET_FOLDER_ID=$(jq -r ".target" "$DRIVE_INFO_FILE")
            TARGET_ROOT=$(jq -r ".target" "$LOCAL_INFO_FILE")

            if [ -z "$ACCESS_TOKEN" ] || [ -z "$TARGET_FOLDER_ID" ] || [ -z "$TARGET_ROOT" ]; then
                echo "必要な設定情報の読み込みに失敗しました。"
                return 1
            fi

            # Initialize response log files
            >"$FOLDER_RESPONSE_LOG"
            >"$FILE_RESPONSE_LOG"

            # Create folders
            while read -r line; do
                folder_path=$(echo "$line" | awk "{print \$1}")
                if ! create_folder "$folder_path"; then
                    echo "フォルダの作成に失敗しました: $folder_path"
                    return 1
                fi
            done <"$FOLDERS_TO_CREATE_FILE"

            # Create files
            while read -r line; do
                filePath=$(echo "$line" | awk "{print \$1}")
                if ! createFile "$filePath"; then
                    echo "ファイルの作成に失敗しました: $filePath"
                    return 1
                fi
            done <"$TO_CREATE_FILE"
        } 2>&1
    ) || {
        echo "Google Driveへのファイル作成中にエラーが発生しました：$error_message"
        return 1
    }

    log_message "Google Driveへのファイル作成が成功しました。"
    return 0
}

create_folder() {
    local folder_path=$1
    local folder_name=$(basename "$folder_path")
    local parent_folder=$(dirname "$folder_path")

    log_message "フォルダを作成中: $folder_name (親フォルダ: $parent_folder)"

    # Get the folder ID for the parent folder
    if [[ "$parent_folder" == "." || "$parent_folder" == "/" ]]; then
        PARENT_ID="$TARGET_FOLDER_ID"
    else
        PARENT_ID=$(grep "^$parent_folder " "$GD_FOLDERS" | awk '{print $2}')
    fi

    # Create the folder metadata
    metadata=$(jq -n \
        --arg name "$folder_name" \
        --arg parentId "$PARENT_ID" \
        '{name: $name, mimeType: "application/vnd.google-apps.folder", parents: [$parentId]}')

    # Create the folder
    response=$(curl -s -X POST \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$metadata" \
        "https://www.googleapis.com/drive/v3/files")

    # Log the response
    echo "$(date '+%Y-%m-%d %H:%M:%S') - フォルダ作成レスポンス ($folder_path): $response" >>"$FOLDER_RESPONSE_LOG"

    # Get the folder ID from the response
    folder_id=$(echo "$response" | jq -r '.id')

    if [ -z "$folder_id" ] || [ "$folder_id" == "null" ]; then
        log_error "フォルダの作成に失敗しました: $folder_name"
        return 1
    fi

    log_message "フォルダを作成しました。ID: $folder_id"

    # Save the folder ID to .gdFolders
    echo "$folder_path $folder_id" >>"$GD_FOLDERS"
    return 0
}

createFile() {
    local FILE_PATH=$1
    local FILE_NAME=$(basename "$FILE_PATH")
    local parent_folder=$(dirname "$FILE_PATH")

    log_message "ファイルを作成中: $FILE_NAME (親フォルダ: $parent_folder)"

    # Get the folder ID for the parent folder
    if [[ "$parent_folder" == "." || "$parent_folder" == "/" ]]; then
        PARENT_ID="$TARGET_FOLDER_ID"
    else
        PARENT_ID=$(awk -v folder="$parent_folder" '$1 == folder {print $2}' "$GD_FOLDERS")
    fi

    if [[ -z "$PARENT_ID" ]]; then
        log_error "親フォルダIDが見つかりません: $parent_folder"
        return 1
    fi

    # Get the MIME type of the file
    MIME_TYPE=$(file --mime-type -b "$TARGET_ROOT$FILE_PATH")

    # Upload the file
    response=$(curl -s -w "\nHTTP_STATUS:%{http_code}\n" -X POST \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -F "metadata={name:\"$FILE_NAME\",parents:[\"$PARENT_ID\"]};type=application/json;charset=UTF-8" \
        -F "file=@$TARGET_ROOT$FILE_PATH;type=$MIME_TYPE" \
        "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart")

    http_status=$(echo "$response" | grep "HTTP_STATUS" | awk -F: '{print $2}')
    response_body=$(echo "$response" | sed -n '1,/HTTP_STATUS:/p' | sed '$d')

    # Log the response
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ファイル作成レスポンス ($FILE_PATH): $response_body" >>"$FILE_RESPONSE_LOG"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - HTTPステータス: $http_status" >>"$FILE_RESPONSE_LOG"

    # Check if the file was created successfully
    if [[ "$http_status" -ne 200 && "$http_status" -ne 201 ]]; then
        log_error "ファイルの作成に失敗しました: $FILE_NAME, HTTPステータス: $http_status"
        return 1
    else
        fileId=$(echo "$response_body" | jq -r '.id')
        log_message "ファイルを作成しました。ID: $fileId"
    fi
    return 0
}

# Call the main function and capture its exit status
main
exit $?
