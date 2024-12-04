#!/bin/bash

# Get the directory of the current script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source slack_utils.sh using an absolute path
source "$SCRIPT_DIR/slack_utils.sh"

# Default log file location
DEFAULT_LOG_FILE="/tmp/script_log.log"

# Initialize log file
init_logging() {
    local log_file=${1:-$DEFAULT_LOG_FILE}
    export SCRIPT_LOG_FILE=$log_file
    echo "Log initialized at $(date '+%Y-%m-%d %H:%M:%S')" >"$SCRIPT_LOG_FILE"
}

# Function to log messages
log_message() {
    local log_file=${SCRIPT_LOG_FILE:-$DEFAULT_LOG_FILE}
    local message="$(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo -e "$message" | tee -a "$log_file"
}

# Function to log error messages
log_error() {
    local log_file=${SCRIPT_LOG_FILE:-$DEFAULT_LOG_FILE}
    local task_name="$1"
    local error_message="$2"
    local formatted_message="$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $task_name"
    echo -e "$formatted_message" >>"$log_file"
    echo -e "$error_message" >>"$log_file"

    # Escape special characters for JSON
    local escaped_json=$(jq -n --arg task "$task_name" --arg msg "$error_message" \
        '{text: ("<!channel>\n\nエラー🚨："  + "*" + $task + "*" + "\n\n```" + $msg + "```")}')

    # Send to Slack with proper JSON formatting
    send_slack_notification "$escaped_json"
}

# Function to log alert messages
log_alert() {
    local log_file=${SCRIPT_LOG_FILE:-$DEFAULT_LOG_FILE}
    local message="$(date '+%Y-%m-%d %H:%M:%S') - ALERT: $1"
    echo -e "$message" | tee -a "$log_file"
}

# Execute tasks
execute_task_with_logging() {
    local task_name="$1"
    local command="$2"
    log_message "$task_name"
    local output
    output=$($command 2>&1)
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        log_error "$task_name" "$output"
        return 1
    fi
    log_message "$task_name が成功しました。"
    return 0
}

# Function to log task completion with elapsed time
log_task_completion() {
    local task_name="$1"
    local start_time="$2"
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    local hours=$((elapsed / 3600))
    local minutes=$(((elapsed % 3600) / 60))
    local seconds=$((elapsed % 60))

    local time_string=""
    if [ $hours -eq 0 ]; then
        time_string="${minutes}分${seconds}秒"
    else
        time_string="${hours}時間${minutes}分${seconds}秒"
    fi

    log_message "${task_name}を正常に終了しました。（経過時間：${time_string}）"
}
