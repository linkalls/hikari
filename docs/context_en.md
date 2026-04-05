# Context

[English](context_en.md) | [日本語](context.md)

`hikari.Context` encapsulates the HTTP request and response, providing a Hono-like, intuitive API.

## Core Properties

- `req`: The HTTP request object (`picohttpparser.Request`).
- `res`: The HTTP response object (`picohttpparser.Response`).
- `params`: A map of path parameters (e.g., `/:id` -> `params['id']`).
- `query`: A map of parsed query string parameters.
- `headers`: A map of response headers.
- `store`: A map used to share data between middlewares and handlers.

## Methods

### Request Information

- `param(name string) string`: Gets the value of a path parameter. Returns an empty string if it doesn't exist.
- `query_value(name string) string`: Gets the value of a query parameter. Returns an empty string if it doesn't exist.
- `header(name string) string`: Gets the value of a request header. Lookups are optimized to O(1) via lazy cache building.
- `cookie(name string) string`: Gets the value of a cookie from the request.
- `cookies() map[string]string`: Parses the Cookie header and returns all cookies as a map.
- `bind_json[T]() !T`: Parses the JSON body of the request and maps it to a struct `T`.
- `form_value(name string) string`: Gets a form value from `multipart/form-data` or `application/x-www-form-urlencoded`.
- `file(name string) !net.http.FileData`: Retrieves an uploaded file from `multipart/form-data`.
- `files() map[string][]net.http.FileData`: Retrieves all uploaded files.

### Sending Responses

- `text(body string) !Response`: Returns a plain text response (`text/plain`).
- `json[T](data T) !Response`: Serializes data to JSON and returns a JSON response (`application/json`).
- `html(body string) !Response`: Returns an HTML response (`text/html`).
- `send_status(status int, body string) !Response`: Returns a response with a specified status code and body.
- `json_status[T](status int, data T) !Response`: Returns a JSON response with a specified status code.
- `html_status(status int, body string) !Response`: Returns an HTML response with a specified status code.
- `redirect(url string, status int) !Response`: Returns a redirect response to the specified URL. The status is usually 301 or 302.
- `not_found() !Response`: Returns a 404 Not Found response.

### Modifying the Response

- `set_header(key string, value string)`: Sets a response header.
- `set_cookie(name string, value string, options CookieOptions)`: Sets a `Set-Cookie` header.

### Context Store

- `set(key string, value string)`: Saves a value in the context. Useful for passing data from middleware to handlers.
- `get(key string) string`: Retrieves a value saved in the context. Returns an empty string if it doesn't exist.
