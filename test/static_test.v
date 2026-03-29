module main

import os
import hikari
import picohttpparser

fn test_static_serving() {
	// Setup test directory and files
	os.mkdir('./test_public') or {}
	os.write_file('./test_public/index.html', '<h1>Index</h1>') or {}
	os.write_file('./test_public/style.css', 'body { color: red; }') or {}

	mut app := hikari.new()
	app.static('/public', './test_public')

	// Test specific file
	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/public/style.css'
		}
		params: map[string]string{}
	}

	mut res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 200
	assert res.body == 'body { color: red; }'
	assert res.headers['Content-Type'] == 'text/css; charset=utf-8'

	// Test index fallback
	mut ctx_index := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/public/'
		}
		params: map[string]string{}
	}

	mut res_index := app.handle_request(mut ctx_index) or { panic(err) }
	assert res_index.status == 200
	assert res_index.body == '<h1>Index</h1>'
	assert res_index.headers['Content-Type'] == 'text/html; charset=utf-8'

	// Test directory base route without trailing slash
	mut ctx_index2 := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/public'
		}
		params: map[string]string{}
	}

	mut res_index2 := app.handle_request(mut ctx_index2) or { panic(err) }
	assert res_index2.status == 200
	assert res_index2.body == '<h1>Index</h1>'
	assert res_index2.headers['Content-Type'] == 'text/html; charset=utf-8'

	// Test non-existent file
	mut ctx_404 := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/public/missing.js'
		}
		params: map[string]string{}
	}

	mut res_404 := app.handle_request(mut ctx_404) or { panic(err) }
	assert res_404.status == 404

	// Cleanup
	os.rmdir_all('./test_public') or {}
}
