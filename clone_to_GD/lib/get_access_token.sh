#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status

LIB="$(dirname "$0")"
MAIN="$(dirname "$LIB")"
source "$LIB/log_utils.sh"

init_logging "$MAIN/log/get_access_token.log"

RESPONSE_LOG="$MAIN/log/response_access_token.log"
ACCESS_TOKEN_FILE="$MAIN/secrets/ACCESS_TOKEN.json"

main() {
    local error_message=""

    log_message "アクセストークンのリフレッシュを開始します。"

    # Wrap the main logic in a subshell to capture the error message
    error_message=$(
        {
            # Read client info and refresh token.
            CLIENT_SECRET_FILE="$MAIN/secrets/CLIENT_SECRET.json"
            REFRESH_TOKEN_FILE="$MAIN/secrets/REFRESH_TOKEN.json"
            CLIENT_ID=$(jq -r ".client_id" "$CLIENT_SECRET_FILE")
            CLIENT_SECRET=$(jq -r ".client_secret" "$CLIENT_SECRET_FILE")
            TOKEN_URL="https://www.googleapis.com/oauth2/v4/token"
            REFRESH_TOKEN=$(jq -r ".refresh_token" "$REFRESH_TOKEN_FILE")

            if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ] || [ -z "$REFRESH_TOKEN" ]; then
                echo "クライアントID、クライアントシークレット、またはリフレッシュトークンが見つかりません。"
                return 1
            fi

            # Use a temporary file to capture both stdout and stderr
            TEMP_OUTPUT=$(mktemp)

            # Run curl and capture its exit status
            if ! curl -s -X POST "$TOKEN_URL" \
                -d "client_id=$CLIENT_ID" \
                -d "client_secret=$CLIENT_SECRET" \
                -d "refresh_token=$REFRESH_TOKEN" \
                -d "grant_type=refresh_token" \
                >"$TEMP_OUTPUT" 2>&1; then
                echo "Curlコマンドがエラーで終了しました。"
                return 1
            fi

            RESPONSE=$(cat "$TEMP_OUTPUT")

            # Log the request and response
            {
                echo "$(date "+%Y-%m-%d %H:%M:%S") - Access Token Refresh Request and Response:"
                echo "Request URL: $TOKEN_URL"
                echo "Client ID: $CLIENT_ID"
                echo "Refresh Token: $REFRESH_TOKEN"
                echo "Response:"
                echo "$RESPONSE"
            } >"$RESPONSE_LOG"

            # Check for a valid JSON response
            if ! echo "$RESPONSE" | jq . >/dev/null 2>&1; then
                echo "サーバーからの応答が無効なJSONフォーマットです。"
                return 1
            fi

            # Check for the presence of access_token in the response
            if [[ $(echo "$RESPONSE" | jq -r ".access_token") == "null" ]]; then
                echo "アクセストークンの取得に失敗しました。"
                return 1
            fi

            # Save the full response to ACCESS_TOKEN_FILE
            echo "$RESPONSE" >"$ACCESS_TOKEN_FILE"

            # Clean up
            rm "$TEMP_OUTPUT"
        } 2>&1
    ) || {
        echo "アクセストークンのリフレッシュ中にエラーが発生しました：$error_message"
        return 1
    }

    log_message "アクセストークンのリフレッシュが成功しました。"
    return 0
}

# Call the main function and capture its exit status
main
exit $?
