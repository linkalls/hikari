# ルートグループ (Route Groups)

Hikariでは `app.group()` を使って、共通のプレフィックスやミドルウェアを持つルートをグループ化できます。

## 基本的な使い方

```v
mut app := hikari.new()

// '/api/v1' プレフィックスのグループを作成
mut api := app.group('/api/v1')

api.get('/users', fn (mut ctx hikari.Context) !hikari.Response {
    return ctx.text('ユーザー一覧')
})

api.post('/users', fn (mut ctx hikari.Context) !hikari.Response {
    return ctx.text('ユーザー作成')
})

// 上記は以下と同じ:
// GET /api/v1/users
// POST /api/v1/users
```

## グループへのミドルウェア適用

グループ作成時にミドルウェアを指定すると、グループ内の全ルートに適用されます。

```v
fn auth_middleware(mut ctx hikari.Context, next hikari.Next) !hikari.Response {
    token := ctx.header('Authorization')
    if token != 'Bearer valid-token' {
        return hikari.http_error(401, 'Unauthorized')
    }
    return next(mut ctx)
}

// グループ作成時にミドルウェアを指定
mut admin := app.group('/admin', auth_middleware)

admin.get('/dashboard', fn (mut ctx hikari.Context) !hikari.Response {
    return ctx.text('管理ダッシュボード')
})

admin.delete('/users/:id', fn (mut ctx hikari.Context) !hikari.Response {
    id := ctx.param('id')
    return ctx.text('ユーザー ${id} を削除')
})
```

## グループに対して後からミドルウェアを追加

```v
mut api := app.group('/api')
api.use(logger_middleware)
api.use(rate_limit_middleware)

api.get('/data', handler)
```

## サポートされている HTTP メソッド

- `api.get(path, handler, ...middlewares)`
- `api.post(path, handler, ...middlewares)`
- `api.put(path, handler, ...middlewares)`
- `api.delete(path, handler, ...middlewares)`
- `api.patch(path, handler, ...middlewares)`
