# Middleware

[English](middleware_en.md) | [日本語](middleware.md)

Middleware in Hikari are functions that wrap handlers to execute code before and after the request is processed. They are useful for logging, authentication, adding headers, and error catching.

## Middleware Signature

A middleware must follow the `hikari.Middleware` type signature:
`fn (mut ctx hikari.Context, next hikari.Next) !hikari.Response`

## Creating Custom Middleware

```v
fn my_logger(mut ctx hikari.Context, next hikari.Next) !hikari.Response {
    // Before request (Downstream)
    println('--> ${ctx.req.method} ${ctx.req.path}')

    // Execute the next middleware or handler
    mut res := next(mut ctx) or { return err }

    // After request (Upstream)
    println('<-- Status: ${res.status}')

    return res
}
```

## Registering Middleware

### Global Middleware

Applied to all routes.
```v
app.use(my_logger)
```

### Route-Specific Middleware

Applied only to specific routes.
```v
app.get('/api/data', data_handler, auth_middleware, cache_middleware)
```

### Group Middleware

Applied to all routes within a group. See [Route Groups](route_groups_en.md) for details.
