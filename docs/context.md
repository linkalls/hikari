# コンテキスト (Context)

`hikari.Context` はHTTPリクエストとレスポンスをカプセル化し、Honoライクで直感的なAPIを提供します。

## 主なメソッド

- `c.param(key string) string`: URLパスパラメータを取得します。
- `c.header(key string) string`: HTTPリクエストヘッダーを取得します。
- `c.body() string`: リクエストのボディ全体を文字列として取得します。
- `c.bind_json[T]() !T`: JSONリクエストボディを指定した構造体にパースして返します。

## レスポンス・ヘルパー

- `c.text(string)`: `text/plain` として返却します。
- `c.html(string)`: `text/html` として返却します。
- `c.json[T](T)`: `application/json` として返却します。
- `c.not_found()`: 404レスポンスを返します。
