# Performance Features

[English](performance_features_en.md) | [日本語](performance_features.md)

Hikari is designed with extreme performance and minimal resource consumption in mind. Here are the core architectural decisions that make it fast:

## 1. Zero-Allocation Radix Tree Router

Unlike many traditional web frameworks that rely on regular expressions or `string.split('/')`, Hikari uses a custom Radix Tree (Trie) router.
During path matching on the hot path, it only uses V's native string slicing (e.g., `path[start..end]`). Since string slicing in V does not allocate new memory, the router operates with **zero heap allocations**.

## 2. Picoev Event Loop

Hikari runs on top of `picoev`, an extremely fast, lightweight event loop written in C. It bypasses V's default networking overhead and communicates directly with the kernel's `epoll` (or `kqueue`), resulting in massive concurrency capabilities and low latency.

## 3. Picohttpparser Integration

HTTP parsing is performed by `picohttpparser`, widely considered one of the fastest HTTP parsers available (used by the H2O web server). It parses HTTP requests using SIMD instructions without allocating memory for individual headers.

## 4. Middleware Zero-Copy Optimization

When combining global middlewares and route-specific middlewares, Hikari avoids continuously cloning the middleware arrays. It conditionally creates a single execution chain slice only when necessary.

## 5. Direct Handler Call Optimization

If a route has no middlewares, Hikari bypasses the `MiddlewareChain` construction entirely and calls the handler directly. This completely eliminates heap allocations for simple endpoints, making them unbelievably fast.

## 6. Header Cache O(1) Lookup

Calling `ctx.header('User-Agent')` triggers a lazy cache build on the first access. Subsequent lookups in the same request are O(1) map lookups, preventing repeated linear scans of the raw header array.
