module hikari

import picohttpparser
import net.urllib
import net.http
import json

pub struct Context {
pub mut:
	req                picohttpparser.Request
	res                picohttpparser.Response
	params             map[string]string
	query              map[string]string
	headers            map[string]string
	form               map[string]string
	uploaded_files     map[string][]http.FileData
	parsed_form        bool
	store              map[string]string
	set_cookies        []string
	req_header_cache   map[string]string
	header_cache_built bool
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

	// Build lowercase header cache on first access
	if !c.header_cache_built {
		for i in 0 .. c.req.num_headers {
			k := string(c.req.headers[i].name).to_lower()
			v := string(c.req.headers[i].value)
			c.req_header_cache[k] = v
		}
		c.header_cache_built = true
	}
	return c.req_header_cache[key.to_lower()] or { '' }
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
		status:      200
		body:        body
		headers:     if c.headers.len > 0 { c.headers.clone() } else { map[string]string{} }
		set_cookies: if c.set_cookies.len > 0 { c.set_cookies.clone() } else { []string{} }
	}
	res.headers['Content-Type'] = 'text/plain; charset=utf-8'
	return res
}

pub fn (mut c Context) html(body string) !Response {
	mut res := Response{
		status:      200
		body:        body
		headers:     if c.headers.len > 0 { c.headers.clone() } else { map[string]string{} }
		set_cookies: if c.set_cookies.len > 0 { c.set_cookies.clone() } else { []string{} }
	}
	res.headers['Content-Type'] = 'text/html; charset=utf-8'
	return res
}

pub fn (mut c Context) json[T](val T) !Response {
	encoded := json.encode(val)
	mut res := Response{
		status:      200
		body:        encoded
		headers:     if c.headers.len > 0 { c.headers.clone() } else { map[string]string{} }
		set_cookies: if c.set_cookies.len > 0 { c.set_cookies.clone() } else { []string{} }
	}
	res.headers['Content-Type'] = 'application/json; charset=utf-8'
	return res
}

// 事前エンコード済みの JSON 文字列をそのままレスポンスとして返す
// json.encode() の呼び出しを避け、静的・頻繁に呼ばれるエンドポイントの高速化に使う
pub fn (mut c Context) json_raw(body string) !Response {
	mut res := Response{
		status:      200
		body:        body
		headers:     if c.headers.len > 0 { c.headers.clone() } else { map[string]string{} }
		set_cookies: if c.set_cookies.len > 0 { c.set_cookies.clone() } else { []string{} }
	}
	res.headers['Content-Type'] = 'application/json; charset=utf-8'
	return res
}

pub fn (mut c Context) not_found() !Response {
	mut res := Response{
		status:      404
		body:        '404 Not Found'
		headers:     if c.headers.len > 0 { c.headers.clone() } else { map[string]string{} }
		set_cookies: if c.set_cookies.len > 0 { c.set_cookies.clone() } else { []string{} }
	}
	res.headers['Content-Type'] = 'text/plain; charset=utf-8'
	return res
}

// 任意のHTTPステータスコードで JSON レスポンスを返す
pub fn (mut c Context) json_status[T](status int, val T) !Response {
	encoded := json.encode(val)
	mut res := Response{
		status:      status
		body:        encoded
		headers:     if c.headers.len > 0 { c.headers.clone() } else { map[string]string{} }
		set_cookies: if c.set_cookies.len > 0 { c.set_cookies.clone() } else { []string{} }
	}
	res.headers['Content-Type'] = 'application/json; charset=utf-8'
	return res
}

// 任意のHTTPステータスコードで HTML レスポンスを返す
pub fn (mut c Context) html_status(status int, body string) !Response {
	mut res := Response{
		status:      status
		body:        body
		headers:     if c.headers.len > 0 { c.headers.clone() } else { map[string]string{} }
		set_cookies: if c.set_cookies.len > 0 { c.set_cookies.clone() } else { []string{} }
	}
	res.headers['Content-Type'] = 'text/html; charset=utf-8'
	return res
}

// 任意のHTTPステータスコードで text/plain レスポンスを返す
// send_status のエイリアスだが html_status/json_status と名前を揃えた版
pub fn (mut c Context) text_status(status int, body string) !Response {
	mut res := Response{
		status:      status
		body:        body
		headers:     if c.headers.len > 0 { c.headers.clone() } else { map[string]string{} }
		set_cookies: if c.set_cookies.len > 0 { c.set_cookies.clone() } else { []string{} }
	}
	res.headers['Content-Type'] = 'text/plain; charset=utf-8'
	return res
}

// 任意のHTTPステータスコードでレスポンスを返す
pub fn (mut c Context) send_status(status int, body string) !Response {
	mut res := Response{
		status:      status
		body:        body
		headers:     if c.headers.len > 0 { c.headers.clone() } else { map[string]string{} }
		set_cookies: if c.set_cookies.len > 0 { c.set_cookies.clone() } else { []string{} }
	}
	res.headers['Content-Type'] = 'text/plain; charset=utf-8'
	return res
}

// HTTPリダイレクトレスポンスを返す
// status には 301, 302, 303, 307, 308 などを指定する
pub fn (mut c Context) redirect(url string, status int) !Response {
	mut res := Response{
		status:      status
		body:        ''
		headers:     if c.headers.len > 0 { c.headers.clone() } else { map[string]string{} }
		set_cookies: if c.set_cookies.len > 0 { c.set_cookies.clone() } else { []string{} }
	}
	res.headers['Location'] = url
	return res
}

// HTTP response configuration uses standard V types

pub fn (mut c Context) parse_query() {
	path := c.req.path
	q_idx := path.index_u8(`?`)
	if q_idx < 0 {
		return
	}
	query_string := path[q_idx + 1..]
	values := urllib.parse_query(query_string) or { return }
	for k, v in values.to_map() {
		if v.len > 0 {
			c.query[k] = v[0]
		}
	}
}

// クエリパラメータを取得する便利メソッド（存在しない場合は空文字列）
pub fn (mut c Context) query_value(key string) string {
	return c.query[key] or { '' }
}

// リクエストの Cookie 値を取得する
pub fn (mut c Context) cookie(name string) string {
	cookie_header := c.header('Cookie')
	if cookie_header == '' {
		return ''
	}
	for part in cookie_header.split(';') {
		trimmed := part.trim(' ')
		eq_idx := trimmed.index_u8(`=`)
		if eq_idx < 0 {
			continue
		}
		k := trimmed[..eq_idx].trim(' ')
		if k == name {
			return trimmed[eq_idx + 1..]
		}
	}
	return ''
}

// リクエストの全 Cookie を map として取得する
pub fn (mut c Context) cookies() map[string]string {
	mut result := map[string]string{}
	cookie_header := c.header('Cookie')
	if cookie_header == '' {
		return result
	}
	for part in cookie_header.split(';') {
		trimmed := part.trim(' ')
		eq_idx := trimmed.index_u8(`=`)
		if eq_idx < 0 {
			continue
		}
		k := trimmed[..eq_idx].trim(' ')
		v := trimmed[eq_idx + 1..]
		result[k] = v
	}
	return result
}

// Cookie の設定オプション
pub struct CookieOptions {
pub:
	// Max-Age（秒単位）。0の場合は省略される
	max_age int
	// Cookie の有効パス（デフォルト: '/'）
	path string = '/'
	// Cookie の有効ドメイン（空文字列で省略）
	domain string
	// HTTPS のみ送信するか（デフォルト: false）
	secure bool
	// JavaScript からアクセス不可にするか（デフォルト: true）
	http_only bool = true
	// SameSite 属性（'Strict', 'Lax', 'None'、デフォルト: 'Lax'）
	same_site string = 'Lax'
}

// レスポンスに Set-Cookie ヘッダーを追加する
// 複数回呼び出すと複数のクッキーを設定できる
pub fn (mut c Context) set_cookie(name string, value string, options CookieOptions) {
	mut cookie := '${name}=${value}'
	if options.path != '' {
		cookie += '; Path=${options.path}'
	}
	if options.domain != '' {
		cookie += '; Domain=${options.domain}'
	}
	if options.max_age != 0 {
		cookie += '; Max-Age=${options.max_age}'
	}
	if options.secure {
		cookie += '; Secure'
	}
	if options.http_only {
		cookie += '; HttpOnly'
	}
	if options.same_site != '' {
		cookie += '; SameSite=${options.same_site}'
	}
	c.set_cookies << cookie
}
