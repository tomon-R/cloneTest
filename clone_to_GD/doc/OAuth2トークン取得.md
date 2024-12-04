GAS に関しては、すべて`Scriptapp.getOAuthToken()`で解決する。
https://developers.google.com/apps-script/reference/script/script-app?hl=ja#getoauthtoken
スコープの指定は`appsscript.json`に書き込む。
https://developers.google.com/apps-script/concepts/scopes?hl=ja#setting\_explicit\_scopes

ここにのってたわ

> https://developers.google.com/android-publisher/authorization?hl=ja

```json
{
    "web": {
        "client_id": "...apps.googleusercontent.com",
        "project_id": "...",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
        "client_secret": "...",
        "redirect_uris": "http://localhost",
        "javascript_origins": "http://localhost"
    }
}
```

client に与える権限リスト

> https://developers.google.com/identity/protocols/oauth2/scopes?hl=ja

scope を複数指定するには「+」でつなげればいけた。

scripts.run に必要な権限

> https://developers.google.com/apps-script/api/reference/rest/v1/scripts/run?hl=ja

authorization code request の例\
web ブラウザで検索する。

```sh
 https://accounts.google.com/o/oauth2/auth
 ?client_id=[client_id]
 &redirect_uri=[redirect_uri]
 &scope=[https://developers.google.com/identity/protocols/oauth2/scopes?hl=jaから選ぶ]
 &response_type=code
 &access_type=offline
```

authorization code response の例
web ブラウザで検索した結果の URL 欄をコピペ

```sh
http://localhost:8080/queryGenerator
?code=[...]
&scope=[...]
```

refresh token request の例

```sh
curl \
-X POST https://www.googleapis.com/oauth2/v4/token \
--data "code=[...]"
--data "redirect_uri=[redirect_uri]"
--data "client_id=[client_id]"
--data "client_secret=[client_secret]"
--data "scope=[scope]"
--data "grant_type=authorization_code"
```

refresh token response の例

```json
{
    "access_token": "...",
    "expires_in": 3599,
    "refresh_token": "...",
    "scope": "...",
    "token_type": "Bearer"
}
```
