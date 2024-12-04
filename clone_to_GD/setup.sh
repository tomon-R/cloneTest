#!/bin/bash

MAIN="$(dirname "$0")"
source "$MAIN/lib/log_utils.sh"

# Initialize logging
init_logging "$MAIN/setup.log"

# Install jq if not already installed
if ! execute_task_with_logging "jqのインストール確認" '
if ! command -v jq &>/dev/null; then
    echo "jq is not installed. Installing jq..."
    sudo apt-get update && sudo apt-get install -y jq
else
    echo "jq is already installed."
fi
'; then
    log_error "セットアップ" "jqのインストールに失敗しました。"
    exit 1
fi

# Set execute permissions for all files in MAIN_ROOT
if ! execute_task_with_logging "実行権限の設定" "find \"$MAIN\" -type f -exec chmod +x {} \\;"; then
    log_error "セットアップ" "実行権限の設定に失敗しました。"
    exit 1
fi

# Get refresh token
if ! execute_task_with_logging "リフレッシュトークンの取得" "$MAIN/lib/get_refresh_token.sh"; then
    log_error "セットアップ" "リフレッシュトークンの取得に失敗しました。"
    exit 1
fi

log_message "セットアップが完了しました。"
