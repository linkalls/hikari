module hikari

// Simple, non-cached hello response. This avoids unsafe/global init complexity
// while still providing a minimal allocation path. For extreme performance we
// would pre-warm and reuse a buffer, but that requires careful safe init.
pub fn hello_response() Response {
    s := 'Hello, World!'
    return Response{
        body: s.bytes()
        body_str: s
        status: 200
        headers: {"Content-Type": "text/plain; charset=UTF-8"}
    }
}
