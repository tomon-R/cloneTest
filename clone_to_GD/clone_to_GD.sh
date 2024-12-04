#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

MAIN="$(dirname "$0")"
source "$MAIN/lib/log_utils.sh"

mkdir -p "$MAIN/log"
init_logging "$MAIN/log/clone_to_GD.log"

# Main Job

LOCAL_INFO_FILE="$MAIN/secrets/LOCAL_INFO.json"
DRIVE_INFO_FILE="$MAIN/secrets/DRIVE_INFO.json"
REFRESH_TOKEN_FILE="$MAIN/secrets/REFRESH_TOKEN.json"

read_json_file() {
    local file="$1"
    local key="$2"
    local value

    if [ ! -f "$file" ]; then
        log_error "ファイル読み込みエラー" "ファイル $file が見つかりません。"
        return 1
    fi

    value=$(jq -r ".$key" "$file" 2>&1)
    if [ $? -ne 0 ]; then
        log_error "JSON解析エラー" "ファイル $file の解析に失敗しました: $value"
        return 1
    fi

    echo "$value"
}

# Safely read configuration files
TARGET_ROOT=$(read_json_file "$LOCAL_INFO_FILE" "target") || exit 1
TARGET_FOLDER=$(read_json_file "$DRIVE_INFO_FILE" "target") || exit 1
REFRESH_TOKEN=$(read_json_file "$REFRESH_TOKEN_FILE" "refresh_token") || exit 1

[ -z "$TARGET_ROOT" ] && {
    log_error "設定の検証" "LOCAL_INFOが指定されていません。"
    exit 1
}
[ -z "$TARGET_FOLDER" ] && {
    log_error "設定の検証" "DRIVE_INFOが指定されていません。"
    exit 1
}
[ -z "$REFRESH_TOKEN" ] && {
    log_error "設定の検証" "Refresh Tokenが取得されていません。setup.shからやり直してください。"
    exit 1
}

log_message "$TARGET_ROOT をGoogle Drive（$TARGET_FOLDER）にクローンします。"

# Execute tasks
if ! execute_task_with_logging "Google Driveターゲットの取得" "$MAIN/lib/tree_GD.sh"; then
    exit 1
fi

if ! execute_task_with_logging "ローカルターゲットの取得" "$MAIN/lib/tree_ROOT.sh"; then
    exit 1
fi

if ! execute_task_with_logging "アップロードファイルの整理" "$MAIN/lib/compare_trees.sh"; then
    exit 1
fi

if ! execute_task_with_logging "Google Driveターゲットへのファイル作成" "$MAIN/lib/create_GD_file.sh"; then
    exit 1
fi

if ! execute_task_with_logging "Google Driveターゲットへのファイルアップデート" "$MAIN/lib/update_GD_file.sh"; then
    exit 1
fi

if ! execute_task_with_logging "Google Drive上のファイル削除" "$MAIN/lib/delete_GD_file.sh"; then
    exit 1
fi

log_message "Google Driveへのクローン処理が完了しました。"

exit 0
