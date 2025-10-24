module hikari

import json
import veb

// HikariそっくりなContextAPI
pub struct Context {
	veb.Context
pub mut:
	// Hikariライクなプロパティ
	req    Request
	var    map[string]Any = map[string]Any{}
	// 内部パラメータ
	params map[string]string = map[string]string{}
}

pub struct Request {
pub:
	method string
	url    string
	path   string
	query  map[string]string
	header map[string]string
	body   string
}

// Hikariライクなレスポンスヘルパー
pub fn (c Context) text(text string, status ...int) Response {
	code := if status.len > 0 { status[0] } else { 200 }
	return Response{
		body: text
		status: code
		headers: {"Content-Type": "text/plain; charset=UTF-8"}
	}
}

pub fn (c Context) json[T](object T, status ...int) Response {
	code := if status.len > 0 { status[0] } else { 200 }
	json_str := json.encode(object)
	return Response{
		body: json_str
		status: code
		headers: {"Content-Type": "application/json; charset=UTF-8"}
	}
}

pub fn (c Context) html(html string, status ...int) Response {
	code := if status.len > 0 { status[0] } else { 200 }
	return Response{
		body: html
		status: code
		headers: {"Content-Type": "text/html; charset=UTF-8"}
	}
}

// Hikariの c.req.param() と同じ
pub fn (c Context) param(key string) string {
	return c.params[key] or { "" }
}

// Hikariの c.req.query() と同じ
pub fn (c Context) query(key string) ?string {
	if val := c.req.query[key] {
		return val
	}
	return none
}

// Hikariの c.req.header() と同じ
pub fn (c Context) header(key string) string {
	return c.req.header[key.to_lower()] or { "" }
}

// Hikariの c.req.json() と同じ
pub fn (c Context) json_body[T]() !T {
	return json.decode(T, c.req.body) or {
		return error("Failed to parse JSON: ${err}")
	}
}

// Hikariの c.set() / c.get() と同じ
pub fn (mut c Context) set(key string, value Any) {
	c.var[key] = value
}

pub fn (c Context) get[T](key string) ?T {
	if val := c.var[key] {
		if val is T {
			return val
		}
	}
	return none
}

// エラーレスポンス（Hikari風）
pub fn (c Context) not_found() Response {
	return c.text("Not Found", 404)
}

pub fn (c Context) redirect(location string, status ...int) Response {
	code := if status.len > 0 { status[0] } else { 302 }
	return Response{
		body: ""
		status: code
		headers: {"Location": location}
	}
}
