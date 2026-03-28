module main

import hikari

fn main() {
	mut app := hikari.new()

	app.get('/', fn (mut c hikari.Context) !hikari.Response {
		return c.text('Welcome to Hikari Web Framework!')
	})

	app.get('/hello/:name', fn (mut c hikari.Context) !hikari.Response {
		name := c.param('name')
		return c.html('<h1>Hello, ${name}!</h1>')
	})

	app.get('/api/data', fn (mut c hikari.Context) !hikari.Response {
		return c.json({
			'framework': 'Hikari'
			'language':  'V'
			'speed':     'Blazing Fast'
		})
	})

	app.get('/error', fn (mut c hikari.Context) !hikari.Response {
		return error('Simulated internal server error')
	})

	app.fire(3000)
}
