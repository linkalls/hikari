module hikari

import os
import net.http.mime

pub fn static_handler(prefix string, root_dir string) Handler {
	return fn [prefix, root_dir] (mut ctx Context) !Response {
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

		return res
	}
}
