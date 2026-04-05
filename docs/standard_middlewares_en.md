# Standard Middlewares

[English](standard_middlewares_en.md) | [日本語](standard_middlewares.md)

Hikari provides essential standard middlewares out-of-the-box.

## 1. Logger (`hikari.logger()`)

Logs information about incoming HTTP requests to the standard output.

```v
app.use(hikari.logger())
```
**Output Example:**
`[INFO] GET /api/users - 200 OK - 1.2ms`

## 2. CORS (`hikari.cors()`)

Handles Cross-Origin Resource Sharing (CORS) headers.

```v
app.use(hikari.cors(hikari.CorsOptions{
    allow_origins: ['https://example.com', 'http://localhost:3000']
    allow_methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
    allow_headers: ['Content-Type', 'Authorization']
    max_age:       86400
}))
```
If you want to allow all origins (`*`), you can simply use the default options:
```v
app.use(hikari.cors(hikari.CorsOptions{ allow_origins: ['*'] }))
```

## 3. Recover (`hikari.recover()`)

Catches panics (runtime crashes) that occur within handlers or subsequent middlewares and converts them into a `500 Internal Server Error` response. This prevents the entire server from crashing when an unexpected error happens.

```v
app.use(hikari.recover())
```
*Note: Due to V language constraints, catching all types of low-level panics isn't always possible, but `recover()` provides a good safety net for standard application logic.*
