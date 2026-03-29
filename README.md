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

### 7. 標準ミドルウェア (Standard Middlewares)

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

## 今後の展望

- ファイルアップロードのサポート
