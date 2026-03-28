# 標準ミドルウェア (Standard Middlewares)

Hikariは、Webアプリケーション開発で頻繁に使用される標準的なミドルウェアを組み込みで提供しています。

## Logger (ロガー)

リクエストのメソッド、パス、レスポンスステータス、および処理時間をコンソールに出力します。

```v
import hikari

mut app := hikari.new()

// グローバルミドルウェアとしてLoggerを登録
app.use(hikari.logger())
```

## CORS (Cross-Origin Resource Sharing)

ブラウザからのクロスドメインリクエストを許可するためのCORSヘッダーを自動的に設定します。
`hikari.CorsOptions` を使用して柔軟に設定できます。

```v
import hikari

mut app := hikari.new()

// CORSの設定
cors_options := hikari.CorsOptions{
    allow_origins: ['http://localhost:3000', 'https://myapp.com']
    allow_methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
    allow_headers: ['Origin', 'Content-Type', 'Accept', 'Authorization']
    credentials:   true
}

app.use(hikari.cors(cors_options))
```

### デフォルト設定

`hikari.CorsOptions{}` のように初期化パラメータを省略した場合は、以下のデフォルト値が使用されます。
- `allow_origins`: `['*']`
- `allow_methods`: `['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']`
- `allow_headers`: `['Origin', 'Content-Type', 'Accept', 'Authorization']`
- `max_age`: `86400`
- `credentials`: `false`

## Recover (リカバリー)

ハンドラー内で発生したエラー（`!Response` として返されたエラー）をキャッチし、サーバーをクラッシュさせることなく、安全に `500 Internal Server Error` レスポンスを返します。

※ V言語の仕様上、`panic` によるプロセスの強制終了をミドルウェア内で完全に防ぐことは難しいため、可能な限りエラーは `return error(...)` で返すようにしてください。

```v
import hikari

mut app := hikari.new()

app.use(hikari.recover())

app.get('/unsafe', fn (mut ctx hikari.Context) !hikari.Response {
    // このエラーはRecoverミドルウェアによってキャッチされ、500エラーとして処理されます
    return error('Something went completely wrong!')
})
```
