#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status

LIB="$(dirname "$0")"
MAIN="$(dirname "$LIB")"
source "$LIB/log_utils.sh"

init_logging "$MAIN/log/update_GD_file.log"

FILE_RESPONSE_LOG="$MAIN/log/response_update_files.log"
TO_UPDATE_FILE="$MAIN/temp/.files_to_update"
ACCESS_TOKEN_FILE="$MAIN/secrets/ACCESS_TOKEN.json"
LOCAL_INFO_FILE="$MAIN/secrets/LOCAL_INFO.json"

main() {
    local error_message=""

    log_message "Google Driveファイル更新プロセスを開始します。"

    # Wrap the main logic in a subshell to capture the error message
    error_message=$(
        {
            ACCESS_TOKEN=$(jq -r ".access_token" "$ACCESS_TOKEN_FILE")
            TARGET_ROOT=$(jq -r ".target" "$LOCAL_INFO_FILE")

            if [ -z "$ACCESS_TOKEN" ] || [ -z "$TARGET_ROOT" ]; then
                echo "必要な設定情報の読み込みに失敗しました。"
                return 1
            fi

            # Initialize response log file
            >"$FILE_RESPONSE_LOG"

            while read -r line; do
                file_path=$(echo "$line" | awk "{print \$1}")
                file_id=$(echo "$line" | awk "{print \$3}")
                absolute_file_path="$TARGET_ROOT$file_path"
                log_message "更新するファイルパス: $absolute_file_path"
                if ! update_file "$absolute_file_path" "$file_id"; then
                    echo "ファイルの更新に失敗しました: $absolute_file_path"
                    return 1
                fi
            done <"$TO_UPDATE_FILE"
        } 2>&1
    ) || {
        echo "Google Driveファイル更新プロセス中にエラーが発生しました：$error_message"
        return 1
    }

    log_message "Google Driveファイル更新プロセスが完了しました。"
    return 0
}

update_file() {
    local FILE_PATH=$1
    local FILE_ID=$2
    local FILE_NAME=$(basename "$FILE_PATH")
    local PARENT_FOLDER=$(dirname "$FILE_PATH")

    # Remove the target root prefix to get the relative path
    local RELATIVE_PARENT_FOLDER=${PARENT_FOLDER#"$TARGET_ROOT"}

    log_message "ファイルを更新中: $FILE_NAME (親フォルダ: $RELATIVE_PARENT_FOLDER)"

    # Get the MIME type of the file
    MIME_TYPE=$(file --mime-type -b "$FILE_PATH")

    # Update the file
    response=$(curl -s -w "\nHTTP_STATUS:%{http_code}\n" -X PATCH \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -F "metadata={name:\"$FILE_NAME\"};type=application/json;charset=UTF-8" \
        -F "file=@$FILE_PATH;type=$MIME_TYPE" \
        "https://www.googleapis.com/upload/drive/v3/files/$FILE_ID?uploadType=multipart")

    http_status=$(echo "$response" | grep "HTTP_STATUS" | awk -F: '{print $2}')
    response_body=$(echo "$response" | sed -n '1,/HTTP_STATUS:/p' | sed '$d')

    # Log the response to the response log file
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ファイル更新レスポンス ($FILE_PATH):" >>"$FILE_RESPONSE_LOG"
    echo "レスポンス: $response_body" >>"$FILE_RESPONSE_LOG"
    echo "HTTPステータス: $http_status" >>"$FILE_RESPONSE_LOG"
    echo "---" >>"$FILE_RESPONSE_LOG"

    # Check if the file was updated successfully
    if [[ "$http_status" -ne 200 && "$http_status" -ne 201 ]]; then
        log_error "ファイルの更新に失敗しました: $FILE_NAME, HTTPステータス: $http_status"
        return 1
    else
        file_id=$(echo "$response_body" | jq -r '.id')
        log_message "ファイルを更新しました。ID: $file_id"
    fi
    return 0
}

# Call the main function and capture its exit status
main
exit $?
