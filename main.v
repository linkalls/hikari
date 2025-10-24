module main
import hikari

fn main() {
    mut app := hikari.new()
    app.get('/', fn (c hikari.Context) !hikari.Response {
        return c.text('Hello, World!')
    })
    app.fire(3000) or { panic(err) }
}
