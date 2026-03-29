module main

import hikari

fn main() {
	mut app := hikari.new()

	app.get('/', fn (mut c hikari.Context) !hikari.Response {
		return c.json({
			'framework': 'Hikari'
			'language':  'V'
			'speed':     'Blazing Fast'
		})
	})

	app.fire(3000)
}
