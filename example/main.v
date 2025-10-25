module main

import hikari

fn main() {
	mut app := hikari.new()
	app.get('/', fn (mut c hikari.Context) !hikari.Response {
		return c.text('hello world')
	})

	app.get('/hello', fn (mut c hikari.Context) !hikari.Response {
		return c.json({
			'message': 'Hello from /hello endpoint!'
		})
	})

	app.get('/:id', fn (mut c hikari.Context) !hikari.Response {
		id := c.param('id')
		// aa := c.param("aa")
		// Development log removed for perf testing:
		// println("Received ID: $id")
		return c.json({
			'message': 'Hello from /${id} endpoint!'
		})
	})

	app.get('/:id/:name', fn (mut c hikari.Context) !hikari.Response {
		id := c.param('id')
		aa := c.param('name')
		// Development log removed for perf testing:
		// println("Received ID: $id, Name: $aa")
		return c.json({
			'message': 'Hello from /${id}/${aa} endpoint!'
		})
	})

	app.get('/aa/:name/aa/:q', fn (mut c hikari.Context) !hikari.Response {
		name := c.param('name')
		q := c.param('q')
		// Development log removed for perf testing:
		// println("Received Name: $name, Query: $q")
		return c.json({
			'message': 'Hello from ${name} ${q} endpoint!'
		})
	})

	// logger disabled for high-load perf testing
	// app.use(hikari.logger())

	// Let framework decide port/workers; you can still pass a port via CLI
	app.fire(3000) or { panic(err) }
}
