module main
import hikari
import json

struct User {
	id   int
	name string
	age  int
}

fn test_basic_routing() {
	mut app := hikari.new()
	app.get("/", fn (c hikari.Context) !hikari.Response {
		return c.text("Hello, World!")
	})

	mut ctx := hikari.Context{
		req: hikari.Request{
			method: "GET",
			path:   "/",
		},
	}
	res := app.handle_request(mut ctx) or { panic(err) }

	assert res.status == 200
	assert res.body == "Hello, World!"
}

fn test_json_response() {
	mut app := hikari.new()
	app.get("/user", fn (c hikari.Context) !hikari.Response {
		return c.json(User{
			id:   1,
			name: "V",
			age:  2,
		})
	})

	mut ctx := hikari.Context{
		req: hikari.Request{
			method: "GET",
			path:   "/user",
		},
	}
	res := app.handle_request(mut ctx) or { panic(err) }

	assert res.status == 200
	user := json.decode(User, res.body) or { panic(err) }
	assert user.id == 1
	assert user.name == "V"
	assert user.age == 2
}
