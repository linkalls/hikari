# Hikari 🚀

[English](README_en.md) | [日本語](README.md)

Hikari is a **blazing-fast, Hono-like, and intuitive web server framework** written in the V programming language (vlang).

## Philosophy

The development of Hikari aims to achieve **both 'ultimate performance' and 'the best Developer Experience (DX)'**.

1. **Hono-like Intuitive API**: Adopts a refined API inspired by TypeScript's Hono. You can write concise and readable code through the context (`c.text()`, `c.json()`, `c.param()`).
2. **Zero-Allocation Routing**: Eliminates memory allocation to the extreme in the routing hot path (the most frequently called part at runtime). Instead of using `path.split('/')`, it implements a custom Radix Tree (Trie) router utilizing V's extremely fast string slicing (`path[start..end]`). This suppresses unnecessary garbage collection and achieves stable, high throughput.
3. **Blazing-Fast Event Loop with Picoev**: Extracts V's powerful native performance by directly utilizing the world's fastest class C libraries `picoev` and `picohttpparser` for the backend I/O event loop and HTTP parser.

## Benchmarks

In a JSON response benchmark against a single endpoint, Hikari **recorded speeds comparable to Go Fiber** and **delivered about 3.6 times the performance of Hono (with Bun)**.

*100 connections, 100,000 requests, using `bombardier` (Intel Xeon 2.30GHz, 4 cores, 7.8Gi RAM)*

| Framework | Language | Reqs/sec (Avg) | Latency (Avg) | Throughput |
| :--- | :--- | :--- | :--- | :--- |
| **Hikari** | **VLang** | **84,097 req/s** | **1.18 ms** | 17.35 MB/s |
| Go Fiber | Go | 89,331 req/s | 1.14 ms | 19.14 MB/s |
| Hono | TypeScript (Bun) | 22,862 req/s | 4.38 ms | 5.15 MB/s |

---

## Features

- ✅ **Radix Tree Router** — Supports path parameters and wildcards
- ✅ **All HTTP Methods** — GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS
- ✅ **Auto HEAD Method Support** — Fallbacks to GET routes
- ✅ **Route Groups** — Apply prefixes and common middlewares with `app.group('/api')`
- ✅ **All HTTP Status Codes** — 200, 201, 204, 301, 302, 400, 401, 403, 429, 503, etc.
- ✅ **Context Store** — Share data between middlewares with `ctx.set()` / `ctx.get()`
- ✅ **Redirects** — `ctx.redirect(url, status)`
- ✅ **JSON Response/Parse** — `ctx.json()` / `ctx.json_status()` / `ctx.bind_json()`
- ✅ **HTML Response** — `ctx.html()` / `ctx.html_status()`
- ✅ **Form Parse** — multipart/form-data, application/x-www-form-urlencoded
- ✅ **File Uploads** — `ctx.file()` / `ctx.files()`
- ✅ **Static File Serving** — ETag, Cache-Control support
- ✅ **HttpError Type** — Errors with HTTP status codes
- ✅ **Global Error Handling** — `app.set_error_handler()`
- ✅ **Custom 404 Handler** — `app.set_not_found_handler()`
- ✅ **Standard Middlewares** — Logger, CORS, Recover, RateLimit, RequestID, Secure, ETag, BasicAuth, Compress, BodyLimit, **Timeout**
- ✅ **JWT Auth Middleware** — HS256 signature verification & `jwt_sign()` helper
- ✅ **Cookie Support** — `ctx.cookie()` / `ctx.cookies()` / `ctx.set_cookie()`
- ✅ **Query Parameters** — `ctx.query_value(key)` convenience method
- ✅ **Auto Content-Length** — HTTP/1.1 Keep-Alive efficiency optimization
- ✅ **Header Cache** — `ctx.header()` builds cache on first access for O(1) lookup
- ✅ **Zero-Copy Optimization** — Clones middleware slices only when necessary (hot path speedup)
- ✅ **Direct Handler Call Optimization** — Completely avoids `MiddlewareChain` heap allocation on routes without middlewares

---

## Usage

Here is how to build a simple application using Hikari.

### 1. Creating the Application

```v
module main

import hikari

fn main() {
    mut app := hikari.new()

    // Return simple text
    app.get('/', fn (mut c hikari.Context) !hikari.Response {
        return c.text('Welcome to Hikari Web Framework!')
    })

    // Use path parameters
    app.get('/hello/:name', fn (mut c hikari.Context) !hikari.Response {
        name := c.param('name')
        return c.html('<h1>Hello, ${name}!</h1>')
    })

    // Return JSON response
    app.get('/api/data', fn (mut c hikari.Context) !hikari.Response {
        return c.json({
            'framework': 'Hikari'
            'language':  'V'
            'speed':     'Blazing Fast'
        })
    })

    // Start server on specified port
    app.fire(3000)
}
```

### 2. Execution

Compile and run using the V compiler with the optimization option (`-prod`) enabled.

```bash
v -prod main.v
./main
```

### 3. POST Requests and JSON Parsing

```v
struct User {
    name string
    age  int
}

app.post('/api/user', fn (mut c hikari.Context) !hikari.Response {
    // Map JSON body from request to struct
    user := c.bind_json[User]() or { return error('invalid json') }
    return c.json({
        'message': 'User created'
        'user':    user.name
    })
})
```

### 4. Middlewares

You can use global middlewares or route-level middlewares.

```v
fn logger_mw(mut ctx hikari.Context, next hikari.Next) !hikari.Response {
    println('Request: ${ctx.req.method} ${ctx.req.path}')

    // Add custom header
    ctx.headers['X-Custom'] = 'Hikari'

    // Execute next middleware (or handler)
    return next(mut ctx)
}

// Add as global middleware
app.use(logger_mw)

// Middlewares can also be added per-route
app.get('/admin', fn (mut c hikari.Context) !hikari.Response {
    return c.text('Admin Area')
}, auth_mw)
```

### 5. Global Error Handling

```v
app.set_error_handler(fn (err IError, mut ctx hikari.Context) !hikari.Response {
    println('Error intercepted: ${err.msg()}')
    ctx.headers['Content-Type'] = 'application/json'
    return ctx.json({ 'error': err.msg() })
})
```

### 6. Static File Serving

Hikari provides built-in static file serving. You can easily serve files from a specified directory using the `app.static(path, root_dir)` method.

```v
import hikari

mut app := hikari.new()

// Make files in './public' accessible under the '/public' prefix
app.static('/public', './public')
```

With this, if there is a file like `./public/style.css`, clients can access it at `/public/style.css`. If no filename is provided (e.g., `/public/`), it automatically searches for `index.html`.

### 7. File Uploads

You can easily retrieve files and form data from `multipart/form-data` requests.

```v
app.post('/upload', fn (mut c hikari.Context) !hikari.Response {
    // Retrieve form data
    username := c.form_value('username')

    // Retrieve uploaded file
    file := c.file('avatar') or { return c.text('No file uploaded') }

    // Using file info
    // file.filename (string)
    // file.content_type (string)
    // file.data (string - file content)

    return c.text('Uploaded: ${file.filename} by ${username}')
})
```

### 8. Standard Middlewares

Hikari provides built-in standard middlewares like `Logger`, `CORS`, and `Recover`.For details, see [docs/standard_middlewares.md](docs/standard_middlewares_en.md) .

```v
// Logger
app.use(hikari.logger())

// CORS
app.use(hikari.cors(hikari.CorsOptions{
    allow_origins: ['*']
}))

// Recover
app.use(hikari.recover())
```

### 9. Route Groups

You can group routes that share a common prefix or middlewares.For details, see [docs/route_groups.md](docs/route_groups_en.md) .

```v
// Group with '/api/v1' prefix
mut api := app.group('/api/v1')

api.get('/users', fn (mut c hikari.Context) !hikari.Response {
    return c.json(['Alice', 'Bob'])
})

api.post('/users', fn (mut c hikari.Context) !hikari.Response {
    return c.send_status(201, 'Created')
})
```

### 10. New Middlewares

For details, see [docs/new_middlewares.md](docs/new_middlewares_en.md) .

```v
// Rate Limit: Up to 100 requests per minute
app.use(hikari.rate_limit(hikari.RateLimitOptions{
    max:       100
    window_ms: 60000
}))

// Request ID: Assigns a unique ID to each request
app.use(hikari.request_id())

// Secure Headers: Automatically adds Helmet-like major security headers
app.use(hikari.secure(hikari.SecureOptions{}))

// ETag: Automatically calculates response ETag and returns 304 Not Modified
app.use(hikari.etag())

// Gzip Compression: Compressed responses for clients accepting gzip
app.use(hikari.compress())

// Basic Auth: Add authentication to routes or groups
app.use(hikari.basic_auth(hikari.BasicAuthOptions{
    username: 'admin'
    password: 'secret'
}))

// JWT Auth: Verifies HS256 token and saves payload in ctx.store
app.use(hikari.jwt(hikari.JwtOptions{
    secret: 'your-secret-key'
}))
```

### 11. JWT Authentication

Verifies JWT tokens using the HS256 algorithm. The token's JSON payload can be retrieved with `ctx.get('jwt_payload')`.

```v
import hikari
import json

struct Claims {
    sub  string
    role string
}

// Login: Generate and return a JWT token
app.post('/login', fn (mut c hikari.Context) !hikari.Response {
    token := hikari.jwt_sign({
        'sub':  'user123'
        'role': 'admin'
    }, 'your-secret-key')
    return c.text(token)
})

// Protected route: Authenticate with JWT middleware
app.get('/profile', fn (mut c hikari.Context) !hikari.Response {
    payload_str := c.get('jwt_payload')
    // payload_str is a JSON string: {"sub":"user123","role":"admin"}
    return c.text('Hello, ${payload_str}')
}, hikari.jwt(hikari.JwtOptions{ secret: 'your-secret-key' }))
```

#### JwtOptions

| Field | Type | Default | Description |
|---|---|---|---|
| `secret` | `string` | — | Secret key used for signature verification (Required) |
| `scheme` | `string` | `'Bearer'` | Authorization header scheme |
| `unauthorized_message` | `string` | `'Unauthorized'` | Response body when authentication fails |

### 12. Cookie Support

```v
// Set session cookie on login
app.post('/login', fn (mut c hikari.Context) !hikari.Response {
    c.set_cookie('session', 'tok123', hikari.CookieOptions{
        max_age:   3600
        http_only: true
        same_site: 'Strict'
    })
    // Multiple cookies can also be set
    c.set_cookie('theme', 'dark', hikari.CookieOptions{
        http_only: false
    })
    return c.redirect('/dashboard', 302)
})

// Read request cookies
app.get('/me', fn (mut c hikari.Context) !hikari.Response {
    session := c.cookie('session')  // Get a single cookie
    if session == '' {
        return hikari.http_error(401, 'Unauthorized')
    }
    all_cookies := c.cookies()  // Get all cookies as a map
    return c.text('Hello! theme=${all_cookies['theme']}')
})
```

### 13. Redirects and Custom Status Codes

```v
// Redirects
app.get('/old-path', fn (mut c hikari.Context) !hikari.Response {
    return c.redirect('/new-path', 301)
})

// Custom status code (201 Created)
app.post('/resource', fn (mut c hikari.Context) !hikari.Response {
    return c.send_status(201, 'Created')
})

// Return error with HttpError type (auto-applies status code)
app.get('/protected', fn (mut c hikari.Context) !hikari.Response {
    return hikari.http_error(403, 'Forbidden')
})
```

### 14. Context Store and Query Parameters

Data can be passed between middlewares and handlers.

```v
fn auth_mw(mut ctx hikari.Context, next hikari.Next) !hikari.Response {
    // Save user info in context
    ctx.set('user_id', '42')
    ctx.set('user_role', 'admin')
    return next(mut ctx)
}

app.get('/profile', fn (mut ctx hikari.Context) !hikari.Response {
    user_id := ctx.get('user_id')
    return ctx.text('User ID: ${user_id}')
}, auth_mw)

// Retrieve query parameters (?q=hello&page=2)
app.get('/search', fn (mut c hikari.Context) !hikari.Response {
    q    := c.query_value('q')    // "hello"
    page := c.query_value('page') // "2"
    return c.text('q=${q}, page=${page}')
})
```

### 15. Custom 404 Handler

You can customize the default 404 response.

```v
app.set_not_found_handler(fn (mut c hikari.Context) !hikari.Response {
    return c.json_status(404, {
        'error': 'Not Found'
        'path':  c.req.path
    })
})
```

### 16. JSON/HTML Custom Status Responses

Using `ctx.json_status()` and `ctx.html_status()`, you can return JSON or HTML responses with any status code.

```v
// Return JSON with 201 Created
app.post('/resource', fn (mut c hikari.Context) !hikari.Response {
    return c.json_status(201, {
        'id':      '42'
        'message': 'Created'
    })
})

// Return HTML with 202 Accepted
app.post('/async-job', fn (mut c hikari.Context) !hikari.Response {
    return c.html_status(202, '<p>Job accepted. Processing...</p>')
})
```

### 17. Timeout Middleware

Returns `408 Request Timeout` if the handler does not complete within the specified time.

```v
// Set a 5-second timeout
app.use(hikari.timeout(hikari.TimeoutOptions{
    timeout_ms: 5000
    message:    'Request Timeout'
}))
```

For details, see [docs/new_middlewares.md](docs/new_middlewares_en.md) .

## Future Outlook

- ✅ WebSocket Support (supported via an additional port using the `app.ws` method)
- HTTP/2 Support (Currently, as `picoev`/`picohttpparser` are specialized for HTTP/1.x, we recommend supporting HTTP/2 via a reverse proxy such as Nginx or Caddy)