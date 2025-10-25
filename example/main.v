module main
import hikari

fn main() {
    mut app := hikari.new()
    app.get('/', fn (mut c hikari.Context) !hikari.Response {
        return hikari.hello_response()
    })

    app.get("/hello", fn (mut c hikari.Context) !hikari.Response {
        return c.json({"message": "Hello from /hello endpoint!"})
    })
    app.use(hikari.logger())

    // Let framework decide port/workers; you can still pass a port via CLI
    app.fire(3000) or { panic(err) }
}
