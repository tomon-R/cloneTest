#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status

LIB="$(dirname "$0")"
MAIN="$(dirname "$LIB")"
source "$LIB/log_utils.sh"

init_logging "$MAIN/log/delete_GD_file.log"

FOLDER_RESPONSE_LOG="$MAIN/log/response_delete_folders.log"
FILE_RESPONSE_LOG="$MAIN/log/response_delete_files.log"
TO_DELETE_FILE="$MAIN/temp/.files_to_delete"
FOLDERS_TO_DELETE_FILE="$MAIN/temp/.folders_to_delete"
ACCESS_TOKEN_FILE="$MAIN/secrets/ACCESS_TOKEN.json"

main() {
    local error_message=""

    log_message "Google Driveファイル削除プロセスを開始します。"

    # Wrap the main logic in a subshell to capture the error message
    error_message=$(
        {
            ACCESS_TOKEN=$(jq -r ".access_token" "$ACCESS_TOKEN_FILE")

            if [ -z "$ACCESS_TOKEN" ]; then
                echo "アクセストークンの読み込みに失敗しました。"
                return 1
            fi

            # Initialize response log files
            >"$FOLDER_RESPONSE_LOG"
            >"$FILE_RESPONSE_LOG"

            # Delete folders
            deleted_folders=()
            while read -r line; do
                folder_path=$(echo "$line" | awk '{print $1}')
                folder_id=$(echo "$line" | awk '{print $2}')
                if delete_gd_item "$folder_id" "フォルダ" "$FOLDER_RESPONSE_LOG"; then
                    deleted_folders+=("$folder_path")
                else
                    echo "フォルダの削除に失敗しました: $folder_path (ID: $folder_id)"
                    return 1
                fi
            done <"$FOLDERS_TO_DELETE_FILE"

            # Delete files
            while read -r line; do
                file_path=$(echo "$line" | awk '{print $1}')
                file_id=$(echo "$line" | awk '{print $3}')
                file_parent_folder=$(dirname "$file_path")

                # Check if the file's parent folder is in the list of deleted folders
                skip_file=false
                for deleted_folder in "${deleted_folders[@]}"; do
                    if [[ "$file_parent_folder" == "$deleted_folder"* ]]; then
                        skip_file=true
                        break
                    fi
                done

                if [ "$skip_file" = false ]; then
                    if ! delete_gd_item "$file_id" "ファイル" "$FILE_RESPONSE_LOG"; then
                        echo "ファイルの削除に失敗しました: $file_path (ID: $file_id)"
                        return 1
                    fi
                else
                    log_message "削除済みフォルダ内のファイルをスキップします: $file_path"
                fi
            done <"$TO_DELETE_FILE"

        } 2>&1
    ) || {
        echo "Google Driveファイル削除プロセス中にエラーが発生しました：$error_message"
        return 1
    }

    log_message "Google Driveファイル削除プロセスが完了しました。"
    return 0
}

delete_gd_item() {
    local item_id=$1
    local item_type=$2
    local response_log=$3

    log_message "${item_type}を削除中: ID $item_id"

    # Delete the item (file or folder)
    response=$(curl -s -w "\nHTTP_STATUS:%{http_code}\n" -X DELETE \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        "https://www.googleapis.com/drive/v3/files/$item_id")

    http_status=$(echo "$response" | grep "HTTP_STATUS" | awk -F: '{print $2}')
    response_body=$(echo "$response" | sed -n '1,/HTTP_STATUS:/p' | sed '$d')

    # Log the response to the appropriate log file
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${item_type}削除レスポンス (ID: $item_id):" >>"$response_log"
    echo "レスポンス: $response_body" >>"$response_log"
    echo "HTTPステータス: $http_status" >>"$response_log"
    echo "---" >>"$response_log"

    if [[ "$http_status" -ne 204 ]]; then
        log_error "${item_type}の削除に失敗しました: ID $item_id, HTTPステータス: $http_status"
        return 1
    else
        log_message "${item_type}を削除しました: ID $item_id"
        return 0
    fi
}

# Call the main function and capture its exit status
main
exit $?
