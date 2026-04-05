# Error Handling

[English](error_handling_en.md) | [日本語](error_handling.md)

Hikari provides a robust and customizable error handling mechanism.

## Custom Error Types (HttpError)

By returning `hikari.http_error(status, message)`, you can safely abort processing and return a response with a specific HTTP status code. `HttpError` implements the `IError` interface in the V language.

```v
app.get('/protected', fn (mut c hikari.Context) !hikari.Response {
    if !is_authorized(c) {
        return hikari.http_error(403, 'Forbidden: You do not have access')
    }
    return c.text('Welcome!')
})
```

## Global Error Handler

You can define a centralized error handler using `app.set_error_handler()`. This handler intercepts any error returned by a handler or middleware and formats it into a uniform response (e.g., JSON).

```v
app.set_error_handler(fn (err IError, mut ctx hikari.Context) !hikari.Response {
    println('Error intercepted: ${err.msg()}')
    return ctx.json_status(500, {
        'error': err.msg()
    })
})
```

## Custom 404 Handler

You can customize the default `404 Not Found` response by setting a custom handler using `app.set_not_found_handler()`.

```v
app.set_not_found_handler(fn (mut c hikari.Context) !hikari.Response {
    return c.html_status(404, '<h1>404 - Page Not Found</h1><p>${c.req.path} does not exist.</p>')
})
```
