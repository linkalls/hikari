# Route Groups

[English](route_groups_en.md) | [日本語](route_groups.md)

Route groups allow you to organize your API by grouping routes that share a common path prefix and middlewares. This reduces code duplication and improves maintainability.

## Creating a Group

Use `app.group(prefix, ...middlewares)` to create a new `RouteGroup`.

```v
mut app := hikari.new()

// Create an API v1 group
mut v1 := app.group('/api/v1')

// Add routes to the group
v1.get('/users', get_users_handler)
v1.post('/users', create_user_handler)
```
The routes above will be registered as `/api/v1/users`.

## Group-Level Middleware

You can apply middlewares that only execute for the routes within the group.

```v
// Apply basic auth only to the admin group
mut admin := app.group('/admin', hikari.basic_auth(hikari.BasicAuthOptions{
    username: 'admin'
    password: 'secret'
}))

admin.get('/dashboard', dashboard_handler) // Requires authentication
admin.get('/settings', settings_handler)   // Requires authentication

app.get('/public', public_handler)         // Does NOT require authentication
```
