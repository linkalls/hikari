# エラーハンドリング (Error Handling)

Hikariでは、`!` 付きの戻り値 `!Response` を使用して、安全にエラーを伝播させることができます。ハンドラやミドルウェアから返されたエラーは、グローバルエラーハンドラーでまとめて処理することが可能です。

## グローバルエラーハンドラーの設定

`app.set_error_handler` を使って、アプリケーション全体のエラーを一元管理します。

```v
mut app := hikari.new()

app.set_error_handler(fn (err IError, mut ctx hikari.Context) !hikari.Response {
    // ログ記録など
    println('Caught an error: ${err.msg()}')

    // エラーメッセージとともにHTTP 500等のレスポンスを返す
    return ctx.json({
        'status': 'error'
        'message': err.msg()
    })
})
```

## エラーの発生

ルーティングの処理内で `return error('メッセージ')` とするだけで、エラーハンドラがインターセプトします。

```v
app.get('/crash', fn (mut ctx hikari.Context) !hikari.Response {
    return error('Something terribly wrong happened.')
})
```
