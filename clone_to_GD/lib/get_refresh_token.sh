#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status

LIB="$(dirname "$0")"
MAIN="$(dirname "$LIB")"
source "$LIB/log_utils.sh"

init_logging "$MAIN/log/get_refresh_token.log"

RESPONSE_LOG="$MAIN/log/response_refresh_token.log"
TOKEN_FILE="$MAIN/secrets/REFRESH_TOKEN.json"

CLIENT_SECRET_FILE="$MAIN/secrets/CLIENT_SECRET.json"
CLIENT_ID=$(jq -r ".client_id" "$CLIENT_SECRET_FILE")
CLIENT_SECRET=$(jq -r ".client_secret" "$CLIENT_SECRET_FILE")
REDIRECT_URI=$(jq -r ".redirect_uris[0]" "$CLIENT_SECRET_FILE")
AUTH_URL="https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_URL="https://www.googleapis.com/oauth2/v4/token"
SCOPE="https://www.googleapis.com/auth/drive"

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ] || [ -z "$REDIRECT_URI" ]; then
    log_error "クライアントシークレットの読み込み" "クライアントID、クライアントシークレット、またはリダイレクトURIが見つかりません。"
    exit 1
fi

log_message "以下のURLをブラウザで開いてアプリケーションを認証してください:"
AUTH_URI="$AUTH_URL?client_id=$CLIENT_ID&redirect_uri=$REDIRECT_URI&scope=$SCOPE&response_type=code&access_type=offline"
log_message "$AUTH_URI"
echo -n "認証コードを入力してください: "
read AUTH_CODE

REQUEST_URI="$TOKEN_URL"
REQUEST_PARAMS="code=$AUTH_CODE&redirect_uri=$REDIRECT_URI&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&scope=$SCOPE&grant_type=authorization_code"

# Use a temporary file to capture both stdout and stderr
TEMP_OUTPUT=$(mktemp)

# Run curl and capture its exit status
curl -s -X POST "$TOKEN_URL" --data "$REQUEST_PARAMS" >"$TEMP_OUTPUT" 2>&1
CURL_EXIT_CODE=$?

# Read the response
RESPONSE=$(cat "$TEMP_OUTPUT")

# Log the request URI, parameters, response, and curl exit code
{
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Refresh Token Request and Response:"
    echo "Request URI: $REQUEST_URI"
    echo "Request Parameters: $REQUEST_PARAMS"
    echo "Curl Exit Code: $CURL_EXIT_CODE"
    echo "Response:"
    echo "$RESPONSE"
} >"$RESPONSE_LOG"

# Check for curl errors
if [ $CURL_EXIT_CODE -ne 0 ]; then
    log_error "認証コードの交換とリフレッシュトークンの取得" "Curlコマンドがエラーで終了しました。終了コード: $CURL_EXIT_CODE\nエラーの詳細は $RESPONSE_LOG を確認してください。"
    rm "$TEMP_OUTPUT"
    exit 1
fi

# Check for a valid JSON response
if ! echo "$RESPONSE" | jq . >/dev/null 2>&1; then
    log_error "認証コードの交換とリフレッシュトークンの取得" "サーバーからの応答が無効なJSONフォーマットです。\n応答の詳細は $RESPONSE_LOG を確認してください。"
    rm "$TEMP_OUTPUT"
    exit 1
fi

# Check for the presence of refresh_token in the response
if [[ $(echo "$RESPONSE" | jq -r ".refresh_token") == "null" ]]; then
    log_error "認証コードの交換とリフレッシュトークンの取得" "リフレッシュトークンの取得に失敗しました。\n応答の詳細は $RESPONSE_LOG を確認してください。"
    rm "$TEMP_OUTPUT"
    exit 1
fi

# If we get here, the token was successfully retrieved
echo "$RESPONSE" >"$TOKEN_FILE"
log_message "リフレッシュトークンが正常に取得され、$TOKEN_FILEに保存されました。"
log_message "リクエストURIとレスポンスの詳細は$RESPONSE_LOGに保存されました。"

# Clean up
rm "$TEMP_OUTPUT"
