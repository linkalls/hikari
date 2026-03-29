# Hikari 🚀

Hikariは、V言語（vlang）で書かれた、**Honoライクで直感的に使える超高速なWebサーバーフレームワーク**です。

## 哲学 (Philosophy)

Hikariの開発は、**「究極のパフォーマンス」と「最高のDeveloper Experience (DX)」を両立させること**を目標にしています。

1. **Honoライクな直感的なAPI**: TypeScriptのHonoに影響を受けた洗練されたAPIを採用しています。コンテキスト（`c.text()`, `c.json()`, `c.param()`）を通じて、簡潔で読みやすいコードを記述できます。
2. **ゼロ・アロケーション (Zero-Allocation Routing)**: ルーティングのホットパス（実行時に最も頻繁に呼び出される部分）において、極限までメモリ割り当てを排除しました。`path.split('/')` は使用せず、V言語の非常に高速な文字列スライス機能（`path[start..end]`）を活用したRadix Tree（Trie木）ルーターを独自に実装しています。これにより、不要なガベージコレクションを抑え、安定した高スループットを実現します。
3. **Picoevによる爆速イベントループ**: バックエンドのI/OイベントループとHTTPパーサーに、世界最速クラスのC言語ライブラリ `picoev` と `picohttpparser` を直接利用することで、V言語ネイティブの強力なパフォーマンスを引き出しています。

## ベンチマーク (Benchmarks)

単一エンドポイントに対するJSONレスポンスのベンチマークにおいて、Hikariは**Go Fiberと同等の速度を記録**し、**Hono (with Bun) の約3.6倍のパフォーマンス**を叩き出しました。

*100コネクション, 100,000リクエスト, `bombardier`を使用（Intel Xeon 2.30GHz, 4 cores, 7.8Gi RAM）*

| Framework | Language | Reqs/sec (Avg) | Latency (Avg) | Throughput |
| :--- | :--- | :--- | :--- | :--- |
| **Hikari** | **VLang** | **84,097 req/s** | **1.18 ms** | 17.35 MB/s |
| Go Fiber | Go | 89,331 req/s | 1.14 ms | 19.14 MB/s |
| Hono | TypeScript (Bun) | 22,862 req/s | 4.38 ms | 5.15 MB/s |

---

## 機能一覧 (Features)

- ✅ **Radix Tree ルーター** — パスパラメータ・ワイルドカード対応
- ✅ **全 HTTP メソッド** — GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS
- ✅ **HEAD メソッド自動サポート** — GET ルートへのフォールバック
- ✅ **ルートグループ** — `app.group('/api')` でプレフィックスと共通ミドルウェアを適用
- ✅ **全 HTTP ステータスコード** — 200, 201, 204, 301, 302, 400, 401, 403, 429, 503 など
- ✅ **コンテキストストア** — `ctx.set()` / `ctx.get()` でミドルウェア間のデータ共有
- ✅ **リダイレクト** — `ctx.redirect(url, status)`
- ✅ **JSON レスポンス/パース** — `ctx.json()` / `ctx.bind_json()`
- ✅ **フォームパース** — multipart/form-data, application/x-www-form-urlencoded
- ✅ **ファイルアップロード** — `ctx.file()` / `ctx.files()`
- ✅ **静的ファイル配信** — ETag, Cache-Control 対応
- ✅ **HttpError 型** — HTTP ステータスコード付きエラー
- ✅ **グローバルエラーハンドリング** — `app.set_error_handler()`
- ✅ **標準ミドルウェア** — Logger, CORS, Recover, RateLimit, RequestID, Secure, ETag, BasicAuth, Compress

---

## 使い方 (Usage)

Hikariを使った簡単なアプリケーションの構築方法です。

### 1. アプリケーションの作成

```v
module main

import hikari

fn main() {
    mut app := hikari.new()

    // シンプルなテキストを返す
    app.get('/', fn (mut c hikari.Context) !hikari.Response {
        return c.text('Welcome to Hikari Web Framework!')
    })

    // パスパラメータを利用する
    app.get('/hello/:name', fn (mut c hikari.Context) !hikari.Response {
        name := c.param('name')
        return c.html('<h1>Hello, ${name}!</h1>')
    })

    // JSONレスポンスを返す
    app.get('/api/data', fn (mut c hikari.Context) !hikari.Response {
        return c.json({
            'framework': 'Hikari'
            'language':  'V'
            'speed':     'Blazing Fast'
        })
    })

    // ポートを指定してサーバーを起動
    app.fire(3000)
}
```

### 2. 実行

V言語のコンパイラを使用して、最適化オプション（`-prod`）を有効にしてコンパイル・実行します。

```bash
v -prod main.v
./main
```

### 3. POSTリクエストとJSONのパース

```v
struct User {
    name string
    age  int
}

app.post('/api/user', fn (mut c hikari.Context) !hikari.Response {
    // リクエストのJSONボディを構造体にマッピング
    user := c.bind_json[User]() or { return error('invalid json') }
    return c.json({
        'message': 'User created'
        'user':    user.name
    })
})
```

### 4. ミドルウェア (Middlewares)

グローバルミドルウェアやルートレベルのミドルウェアを使用できます。

```v
fn logger_mw(mut ctx hikari.Context, next hikari.Next) !hikari.Response {
    println('Request: ${ctx.req.method} ${ctx.req.path}')

    // カスタムヘッダーを追加
    ctx.headers['X-Custom'] = 'Hikari'

    // 次のミドルウェア（またはハンドラ）を実行
    return next(mut ctx)
}

// グローバルミドルウェアとして追加
app.use(logger_mw)

// ルート個別にミドルウェアを追加することも可能
app.get('/admin', fn (mut c hikari.Context) !hikari.Response {
    return c.text('Admin Area')
}, auth_mw)
```

### 5. グローバルなエラーハンドリング (Error Handling)

```v
app.set_error_handler(fn (err IError, mut ctx hikari.Context) !hikari.Response {
    println('Error intercepted: ${err.msg()}')
    ctx.headers['Content-Type'] = 'application/json'
    return ctx.json({ 'error': err.msg() })
})
```

### 6. 静的ファイルの配信 (Static File Serving)

Hikariは、組み込みで静的ファイルの配信機能を提供しています。`app.static(path, root_dir)` メソッドを使用して、指定したディレクトリ内のファイルを簡単に配信できます。

```v
import hikari

mut app := hikari.new()

// '/public' プレフィックスで './public' ディレクトリ内のファイルにアクセスできるようにします
app.static('/public', './public')
```

これによって、たとえば `./public/style.css` というファイルがある場合、クライアントは `/public/style.css` にアクセスしてファイルを取得できます。また、パスにファイル名が指定されていない場合（例: `/public/`）、自動的に `index.html` が検索されます。

### 7. ファイルアップロード (File Uploads)

`multipart/form-data` 形式のリクエストからファイルやフォームデータを簡単に取得できます。

```v
app.post('/upload', fn (mut c hikari.Context) !hikari.Response {
    // フォームデータの取得
    username := c.form_value('username')

    // アップロードされたファイルの取得
    file := c.file('avatar') or { return c.text('No file uploaded') }

    // ファイル情報の利用
    // file.filename (string)
    // file.content_type (string)
    // file.data (string - ファイルの中身)

    return c.text('Uploaded: ${file.filename} by ${username}')
})
```

### 8. 標準ミドルウェア (Standard Middlewares)

Hikariは、組み込みで `Logger`, `CORS`, `Recover` の標準ミドルウェアを提供しています。詳細は [docs/standard_middlewares.md](docs/standard_middlewares.md) を参照してください。

```v
// ロガー
app.use(hikari.logger())

// CORS
app.use(hikari.cors(hikari.CorsOptions{
    allow_origins: ['*']
}))

// リカバリー
app.use(hikari.recover())
```

### 9. ルートグループ (Route Groups)

共通のプレフィックスやミドルウェアを持つルートをグループ化できます。詳細は [docs/route_groups.md](docs/route_groups.md) を参照してください。

```v
// '/api/v1' プレフィックスのグループ
mut api := app.group('/api/v1')

api.get('/users', fn (mut c hikari.Context) !hikari.Response {
    return c.json(['Alice', 'Bob'])
})

api.post('/users', fn (mut c hikari.Context) !hikari.Response {
    return c.send_status(201, 'Created')
})
```

### 10. 新ミドルウェア (New Middlewares)

詳細は [docs/new_middlewares.md](docs/new_middlewares.md) を参照してください。

```v
// レートリミット: 1分間に100リクエストまで
app.use(hikari.rate_limit(hikari.RateLimitOptions{
    max:       100
    window_ms: 60000
}))

// リクエスト ID: 各リクエストに一意のIDを付与
app.use(hikari.request_id())

// セキュリティヘッダー: Helmet風の主要セキュリティヘッダーを自動付与
app.use(hikari.secure(hikari.SecureOptions{}))

// ETag: レスポンスの ETag を自動計算・304 Not Modified を返す
app.use(hikari.etag())

// Gzip 圧縮: Accept-Encoding: gzip を受け付けるクライアントへ圧縮レスポンス
app.use(hikari.compress())

// Basic 認証: ルートやグループに認証を追加
app.use(hikari.basic_auth(hikari.BasicAuthOptions{
    username: 'admin'
    password: 'secret'
}))
```

### 11. リダイレクトとカスタムステータスコード

```v
// リダイレクト
app.get('/old-path', fn (mut c hikari.Context) !hikari.Response {
    return c.redirect('/new-path', 301)
})

// カスタムステータスコード (201 Created)
app.post('/resource', fn (mut c hikari.Context) !hikari.Response {
    return c.send_status(201, 'Created')
})

// HttpError 型でエラーを返す（ステータスコードを自動適用）
app.get('/protected', fn (mut c hikari.Context) !hikari.Response {
    return hikari.http_error(403, 'Forbidden')
})
```

### 12. コンテキストストア

ミドルウェアとハンドラの間でデータを受け渡すことができます。

```v
fn auth_mw(mut ctx hikari.Context, next hikari.Next) !hikari.Response {
    // ユーザー情報をコンテキストに保存
    ctx.set('user_id', '42')
    ctx.set('user_role', 'admin')
    return next(mut ctx)
}

app.get('/profile', fn (mut ctx hikari.Context) !hikari.Response {
    user_id := ctx.get('user_id')
    return ctx.text('User ID: ${user_id}')
}, auth_mw)
```

## 今後の展望

- WebSocketのサポート
- HTTP/2 のサポート
- JWT 認証ミドルウェア
