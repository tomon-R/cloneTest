#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status

# Set MAIN to the parent directory of the script's location
LIB="$(dirname "$0")"
MAIN="$(dirname "$LIB")"
source "$LIB/log_utils.sh"

init_logging "$MAIN/log/tree_ROOT.log"

main() {
    local error_message=""

    log_message "ローカルターゲットを取得しています。"

    # Wrap the main logic in a subshell to capture the error message
    error_message=$(
        {
            # Load configuration
            LOCAL_INFO_FILE="$MAIN/secrets/LOCAL_INFO.json"
            TARGET_ROOT=$(jq -r ".target" "$LOCAL_INFO_FILE")
            OUTPUT_FILE="$MAIN/temp/.ROOT_tree"
            FOLDERS_OUTPUT_FILE="$MAIN/temp/.ROOT_folders"

            if [ -z "$TARGET_ROOT" ]; then
                echo "TARGET_ROOTが設定されていません。LOCAL_INFO.jsonを確認してください。"
                return 1
            fi

            if [ ! -d "$TARGET_ROOT" ]; then
                echo "TARGET_ROOT ($TARGET_ROOT) が存在しないか、ディレクトリではありません。"
                return 1
            fi

            # Create temp directory if it doesn't exist
            mkdir -p "$(dirname "$OUTPUT_FILE")"

            # Generate file tree
            if ! find "$TARGET_ROOT" -type f -exec stat -c '%Y %n' {} \; |
                sed "s|$TARGET_ROOT||" |
                awk '{print $2, strftime("%Y-%m-%dT%H:%M:%S.000Z", $1)}' |
                sed '/^$/d' >"$OUTPUT_FILE"; then
                echo "ファイルツリーの生成中にエラーが発生しました。"
                return 1
            fi

            # Generate folder tree
            if ! find "$TARGET_ROOT" -type d -print |
                sed "s|$TARGET_ROOT||" |
                sed '/^$/d' >"$FOLDERS_OUTPUT_FILE"; then
                echo "フォルダツリーの生成中にエラーが発生しました。"
                return 1
            fi
        } 2>&1
    ) || {
        echo "ローカルターゲットの取得に失敗しました: $error_message"
        return 1
    }

    log_message "ローカルターゲットの取得が成功しました。"
    return 0
}

# Call the main function and capture its exit status
main
exit $?
