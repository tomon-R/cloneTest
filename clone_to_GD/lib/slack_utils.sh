#!/bin/bash

LIB="$(dirname "$0")"
MAIN="$(dirname "$LIB")"

# Function to send a message to Slack
send_slack_notification() {
    local message_json="$1"

    # Load Slack configuration from a configuration file
    SLACK_CONFIG_FILE="$MAIN/secrets/SLACK_CONFIG.json"
    SLACK_WEBHOOK_URL="https://slack.com/api/chat.postMessage"
    SLACK_CHANNEL=$(jq -r ".channel" "$SLACK_CONFIG_FILE")
    SLACK_TOKEN=$(jq -r ".token" "$SLACK_CONFIG_FILE")

    if [ -z "$SLACK_CHANNEL" ]; then
        echo "Error: Slackチャンネルが設定されていません。SLACK_CONFIG.jsonを確認してください。"
        return 1
    fi

    if [ -z "$SLACK_TOKEN" ]; then
        echo "Error: Slack tokenが設定されていません。SLACK_CONFIG.jsonを確認してください。"
        return 1
    fi

    # Construct the full JSON payload
    local payload=$(echo "$message_json" | jq --arg channel "$SLACK_CHANNEL" '. + {channel: $channel}')

    curl -s -X POST "$SLACK_WEBHOOK_URL" \
        -H "Authorization: Bearer $SLACK_TOKEN" \
        -H 'Content-type: application/json' \
        --data "$payload"

    echo ""

    if [ $? -eq 0 ]; then
        echo "Slack通知を送信しました。"
    else
        echo "Slack通知の送信に失敗しました。"
    fi
}
