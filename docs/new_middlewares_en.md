# New Middlewares

[English](new_middlewares_en.md) | [日本語](new_middlewares.md)

Hikari includes several new standard middlewares that enhance security, performance, and functionality. All middlewares are designed to be extremely lightweight and high-performance.

## 1. Timeout Middleware (`timeout`)

If a handler takes longer than the specified time, it aborts the execution and returns a `408 Request Timeout` response.

```v
import hikari

app.use(hikari.timeout(hikari.TimeoutOptions{
    timeout_ms: 5000 // 5 seconds
    message:    'Request Timeout'
}))
```

## 2. Request ID Middleware (`request_id`)

Assigns a unique identifier (UUID v4) to each request. If the client sends an `X-Request-Id` header, it uses that value; otherwise, it generates a new UUID. The ID is added to the response headers as `X-Request-Id`.

```v
app.use(hikari.request_id())
```

## 3. Rate Limit Middleware (`rate_limit`)

Limits the number of requests per IP address to prevent DDoS attacks and brute-force attacks.

```v
app.use(hikari.rate_limit(hikari.RateLimitOptions{
    max:       100      // Max 100 requests
    window_ms: 60000    // Per 1 minute (60,000ms)
    message:   'Too Many Requests'
}))
```

## 4. Secure Middleware (`secure`)

Automatically adds major security headers similar to Helmet in Node.js to protect the application from XSS, clickjacking, and other attacks.

```v
app.use(hikari.secure(hikari.SecureOptions{}))
```

## 5. ETag Middleware (`etag`)

Automatically calculates the `ETag` (SHA-1 hash) based on the response body. If it matches the `If-None-Match` header from the client, it returns a `304 Not Modified` response with an empty body, saving bandwidth.

```v
app.use(hikari.etag())
```

## 6. Compress Middleware (`compress`)

If the client's `Accept-Encoding` header includes `gzip`, it compresses the response body using Gzip and adds the `Content-Encoding: gzip` header.

```v
app.use(hikari.compress())
```

## 7. Basic Auth Middleware (`basic_auth`)

Adds Basic Authentication to specific routes or groups.

```v
app.use(hikari.basic_auth(hikari.BasicAuthOptions{
    username: 'admin'
    password: 'password123'
}))
```

## 8. JWT Auth Middleware (`jwt`)

Verifies the signature of a JSON Web Token (JWT) sent via the `Authorization: Bearer <token>` header using the HS256 algorithm. If the token is valid, its payload is decoded from Base64Url and stored as a JSON string in `ctx.store['jwt_payload']`.

```v
app.use(hikari.jwt(hikari.JwtOptions{
    secret: 'my_super_secret_key'
}))
```
