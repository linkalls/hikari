# コンテキスト (Context)

`hikari.Context` はHTTPリクエストとレスポンスをカプセル化し、Honoライクで直感的なAPIを提供します。

## リクエスト取得メソッド

- `c.param(key string) string`: URLパスパラメータを取得します。
- `c.header(key string) string`: HTTPリクエストヘッダーを取得します（大文字・小文字を区別しません）。
- `c.body() string`: リクエストのボディ全体を文字列として取得します。
- `c.bind_json[T]() !T`: JSONリクエストボディを指定した構造体にパースして返します。
- `c.query_value(key string) string`: URLクエリパラメータを取得します（存在しない場合は空文字列）。
- `c.form_value(key string) string`: フォームデータの値を取得します。
- `c.file(key string) ?http.FileData`: アップロードされたファイルを1件取得します。
- `c.files(key string) []http.FileData`: アップロードされたファイルを全件取得します。

## クッキーメソッド

- `c.cookie(name string) string`: 指定した名前のリクエストクッキー値を取得します。
- `c.cookies() map[string]string`: リクエストの全クッキーを map として取得します。
- `c.set_cookie(name string, value string, options CookieOptions)`: レスポンスに Set-Cookie ヘッダーを追加します。複数回呼び出すと複数のクッキーを設定できます。

### CookieOptions

| フィールド | 型 | デフォルト | 説明 |
|---|---|---|---|
| `max_age` | `int` | `0` | Max-Age（秒単位）。0 の場合は省略 |
| `path` | `string` | `'/'` | Cookie の有効パス |
| `domain` | `string` | `''` | Cookie の有効ドメイン |
| `secure` | `bool` | `false` | HTTPS のみ送信するか |
| `http_only` | `bool` | `true` | JavaScript からアクセス不可にするか |
| `same_site` | `string` | `'Lax'` | SameSite 属性（`'Strict'`, `'Lax'`, `'None'`） |

```v
// ログイン時にセッションクッキーを設定
app.post('/login', fn (mut c hikari.Context) !hikari.Response {
    c.set_cookie('session', 'tok123', hikari.CookieOptions{
        max_age:   3600
        http_only: true
        same_site: 'Strict'
    })
    return c.redirect('/dashboard', 302)
})

// セッションクッキーを読み取る
app.get('/me', fn (mut c hikari.Context) !hikari.Response {
    session := c.cookie('session')
    if session == '' {
        return hikari.http_error(401, 'Unauthorized')
    }
    return c.text('Hello!')
})
```

## コンテキストストア

- `c.set(key string, val string)`: リクエストスコープのストアに値をセット（ミドルウェア間のデータ共有に使用）。
- `c.get(key string) string`: リクエストスコープのストアから値を取得。

## レスポンス・ヘルパー

- `c.text(body string) !Response`: `text/plain` として返却します。
- `c.html(body string) !Response`: `text/html` として返却します。
- `c.json[T](val T) !Response`: `application/json` として返却します。
- `c.not_found() !Response`: 404 レスポンスを返します。
- `c.send_status(status int, body string) !Response`: 任意のHTTPステータスコードでレスポンスを返します。
- `c.redirect(url string, status int) !Response`: HTTPリダイレクトレスポンスを返します。
