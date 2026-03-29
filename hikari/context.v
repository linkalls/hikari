module hikari

import picohttpparser
import net.urllib
import net.http
import json

pub struct Context {
pub mut:
	req            picohttpparser.Request
	res            picohttpparser.Response
	params         map[string]string
	query          map[string]string
	headers        map[string]string
	form           map[string]string
	uploaded_files map[string][]http.FileData
	parsed_form    bool
	store          map[string]string
}

// リクエストスコープのキー/バリューストアに値をセット
pub fn (mut c Context) set(key string, val string) {
	c.store[key] = val
}

// リクエストスコープのキー/バリューストアから値を取得
pub fn (mut c Context) get(key string) string {
	return c.store[key] or { '' }
}

pub fn (mut c Context) param(key string) string {
	return c.params[key] or { '' }
}

pub fn (mut c Context) header(key string) string {
	// First check the context headers map (e.g. set by tests or middlewares)
	if val := c.headers[key] {
		return val
	}

	key_lower := key.to_lower()
	for i in 0 .. c.req.num_headers {
		if string(c.req.headers[i].name).to_lower() == key_lower {
			return string(c.req.headers[i].value)
		}
	}
	return ''
}

pub fn (c Context) body() string {
	return c.req.body
}

pub fn (c Context) bind_json[T]() !T {
	return json.decode(T, c.body())
}

pub fn (mut c Context) parse_form() {
	if c.parsed_form {
		return
	}
	content_type := c.header('Content-Type')
	if content_type.starts_with('multipart/form-data') {
		boundary_idx := content_type.index('boundary=') or { return }
		boundary := content_type[boundary_idx + 9..]
		form_vals, files := http.parse_multipart_form(c.body(), boundary)
		c.form = form_vals.clone()
		c.uploaded_files = files.clone()
	} else if content_type.starts_with('application/x-www-form-urlencoded') {
		values := urllib.parse_query(c.body()) or { return }
		for k, v in values.to_map() {
			if v.len > 0 {
				c.form[k] = v[0]
			}
		}
	}
	c.parsed_form = true
}

pub fn (mut c Context) form_value(key string) string {
	c.parse_form()
	return c.form[key] or { '' }
}

pub fn (mut c Context) file(key string) ?http.FileData {
	c.parse_form()
	if files := c.uploaded_files[key] {
		if files.len > 0 {
			return files[0]
		}
	}
	return none
}

pub fn (mut c Context) files(key string) []http.FileData {
	c.parse_form()
	return c.uploaded_files[key] or { []http.FileData{} }
}

// DX features: returning responses
pub fn (mut c Context) text(body string) !Response {
	mut res := Response{
		status:  200
		body:    body
		headers: c.headers.clone()
	}
	res.headers['Content-Type'] = 'text/plain; charset=utf-8'
	return res
}

pub fn (mut c Context) html(body string) !Response {
	mut res := Response{
		status:  200
		body:    body
		headers: c.headers.clone()
	}
	res.headers['Content-Type'] = 'text/html; charset=utf-8'
	return res
}

pub fn (mut c Context) json[T](val T) !Response {
	encoded := json.encode(val)
	mut res := Response{
		status:  200
		body:    encoded
		headers: c.headers.clone()
	}
	res.headers['Content-Type'] = 'application/json; charset=utf-8'
	return res
}

pub fn (mut c Context) not_found() !Response {
	mut res := Response{
		status:  404
		body:    '404 Not Found'
		headers: c.headers.clone()
	}
	res.headers['Content-Type'] = 'text/plain; charset=utf-8'
	return res
}

// 任意のHTTPステータスコードでレスポンスを返す
pub fn (mut c Context) send_status(status int, body string) !Response {
	mut res := Response{
		status:  status
		body:    body
		headers: c.headers.clone()
	}
	res.headers['Content-Type'] = 'text/plain; charset=utf-8'
	return res
}

// HTTPリダイレクトレスポンスを返す
// status には 301, 302, 303, 307, 308 などを指定する
pub fn (mut c Context) redirect(url string, status int) !Response {
	mut res := Response{
		status:  status
		body:    ''
		headers: c.headers.clone()
	}
	res.headers['Location'] = url
	return res
}

// HTTP response configuration uses standard V types

pub fn (mut c Context) parse_query() {
	if c.req.path.contains('?') {
		parts := c.req.path.split('?')
		if parts.len > 1 {
			query_string := parts[1]
			values := urllib.parse_query(query_string) or { return }
			for k, v in values.to_map() {
				if v.len > 0 {
					c.query[k] = v[0]
				}
			}
		}
	}
}

