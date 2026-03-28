module main

import hikari
import picohttpparser

fn global_mw(mut ctx hikari.Context, next hikari.Next) !hikari.Response {
    ctx.headers['X-Global'] = 'true'
    return next(mut ctx)
}

fn route_mw(mut ctx hikari.Context, next hikari.Next) !hikari.Response {
    ctx.headers['X-Route'] = 'true'
    return next(mut ctx)
}

fn test_middleware() {
    mut app := hikari.new()
    app.use(global_mw)

    app.get('/test', fn (mut ctx hikari.Context) !hikari.Response {
        return ctx.text('Hello Middleware')
    }, route_mw)

    mut ctx := hikari.Context{
        req: picohttpparser.Request{
            method: 'GET'
            path: '/test'
        }
        params: map[string]string{}
    }

    res := app.handle_request(mut ctx) or { panic(err) }
    assert res.status == 200
    assert res.headers['X-Global'] == 'true'
    assert res.headers['X-Route'] == 'true'
    assert res.body == 'Hello Middleware'
}
