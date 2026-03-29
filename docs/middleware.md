# ミドルウェア (Middlewares)

Hikariのミドルウェアは、リクエストの前後で処理を挟み込むことができます。グローバルにも、特定のルーティングにも登録できます。

## 定義方法

ミドルウェアは、以下のシグネチャを持つ関数として定義します。

```v
pub type Middleware = fn (mut ctx hikari.Context, next hikari.Next) !hikari.Response
```

`next(mut ctx)` を呼び出すことで、次のミドルウェア、あるいは最終的なハンドラへと処理を進めることができます。

## 使い方

```v
fn my_logger(mut ctx hikari.Context, next hikari.Next) !hikari.Response {
    println('Request Path: ${ctx.req.path}')
    // 必ず次を呼び出します
    return next(mut ctx)
}

fn main() {
    mut app := hikari.new()

    // アプリケーション全体に適用
    app.use(my_logger)

    // エンドポイントごとに適用
    app.get('/protected', fn (mut ctx hikari.Context) !hikari.Response {
        return ctx.text('You are allowed in!')
    }, my_auth_middleware)
}
```
