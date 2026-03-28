module hikari

import picohttpparser
import net.urllib
import json

pub struct Context {
pub mut:
	req     picohttpparser.Request
	res     picohttpparser.Response
	params  map[string]string
	query   map[string]string
	headers map[string]string
}

pub fn (mut c Context) param(key string) string {
	return c.params[key] or { '' }
}

pub fn (mut c Context) header(key string) string {
	key_lower := key.to_lower()
	for i in 0 .. c.req.num_headers {
		if string(c.req.headers[i].name).to_lower() == key_lower {
			return string(c.req.headers[i].value)
		}
	}
	return ''
}

// DX features: returning responses
pub fn (mut c Context) text(body string) !Response {
	return Response{
		status:  200
		body:    body
		headers: {
			'Content-Type': 'text/plain; charset=utf-8'
		}
	}
}

pub fn (mut c Context) html(body string) !Response {
	return Response{
		status:  200
		body:    body
		headers: {
			'Content-Type': 'text/html; charset=utf-8'
		}
	}
}

pub fn (mut c Context) json[T](val T) !Response {
	encoded := json.encode(val)
	return Response{
		status:  200
		body:    encoded
		headers: {
			'Content-Type': 'application/json; charset=utf-8'
		}
	}
}

pub fn (mut c Context) not_found() !Response {
	return Response{
		status:  404
		body:    '404 Not Found'
		headers: {
			'Content-Type': 'text/plain; charset=utf-8'
		}
	}
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
