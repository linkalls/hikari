module hikari

import os
import net.http.mime
import crypto.md5
import encoding.hex

// キャッシュ設定の構造体
pub struct StaticOptions {
pub:
	// Cache-Control の max-age（秒単位、デフォルト: 86400 = 1日）
	max_age int = 86400
	// ETag を付与するか（デフォルト: true）
	etag bool = true
}

pub fn static_handler(prefix string, root_dir string) Handler {
	return static_handler_with_options(prefix, root_dir, StaticOptions{})
}

pub fn static_handler_with_options(prefix string, root_dir string, options StaticOptions) Handler {
	return fn [prefix, root_dir, options] (mut ctx Context) !Response {
		mut path := ctx.req.path

		if path.starts_with(prefix) {
			path = path[prefix.len..]
		}

		if path == '' || path.ends_with('/') {
			path += 'index.html'
		}

		// Clean the path to prevent directory traversal
		clean_path := path.replace('..', '')

		file_path := os.join_path(root_dir, clean_path)

		if !os.exists(file_path) || !os.is_file(file_path) {
			return ctx.not_found()
		}

		content := os.read_file(file_path) or {
			mut res := Response{
				status:  500
				body:    'Internal Server Error'
				headers: ctx.headers.clone()
			}
			res.headers['Content-Type'] = 'text/plain; charset=utf-8'
			return res
		}

		ext := os.file_ext(file_path)
		mut mime_type := mime.get_mime_type(ext)
		if mime_type == '' {
			if ext == '.css' {
				mime_type = 'text/css; charset=utf-8'
			} else if ext == '.html' {
				mime_type = 'text/html; charset=utf-8'
			} else if ext == '.js' {
				mime_type = 'application/javascript; charset=utf-8'
			}
		}

		// ETag の計算
		if options.etag {
			hash := md5.sum(content.bytes())
			etag_val := '"${hex.encode(hash)}"'

			// If-None-Match チェック
			if_none_match := ctx.header('If-None-Match')
			if if_none_match == etag_val {
				mut not_modified := Response{
					status:  304
					body:    ''
					headers: ctx.headers.clone()
				}
				not_modified.headers['ETag'] = etag_val
				return not_modified
			}

			mut res := Response{
				status:  200
				body:    content
				headers: ctx.headers.clone()
			}

			if mime_type != '' {
				res.headers['Content-Type'] = mime_type
			} else {
				res.headers['Content-Type'] = 'application/octet-stream'
			}

			res.headers['ETag'] = etag_val
			if options.max_age > 0 {
				res.headers['Cache-Control'] = 'public, max-age=${options.max_age}'
			}

			return res
		}

		mut res := Response{
			status:  200
			body:    content
			headers: ctx.headers.clone()
		}

		if mime_type != '' {
			res.headers['Content-Type'] = mime_type
		} else {
			res.headers['Content-Type'] = 'application/octet-stream'
		}

		if options.max_age > 0 {
			res.headers['Cache-Control'] = 'public, max-age=${options.max_age}'
		}

		return res
	}
}
