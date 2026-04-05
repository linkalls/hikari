module hikari

import net.websocket

// ws mounts a WebSocket server endpoint on a specified port.
// This runs alongside the main Hikari HTTP server.
pub fn (mut app Hikari) ws(path string, port int, on_message fn (mut ws websocket.Client, msg &websocket.Message) !) {
	// Create a new websocket server on the specified port and route.
	mut s := websocket.new_server(.ip, port, path)

	// Accept all incoming client connections.
	s.on_connect(fn (mut sc websocket.ServerClient) !bool {
		return true
	}) or { panic(err) }

	// Register the provided callback to handle incoming messages.
	s.on_message(on_message)

	// Start listening for connections in a new thread.
	spawn fn (mut s websocket.Server) {
		s.listen() or { println('WebSocket server error: ${err}') }
	}(mut s)

	println('🌐 Hikari WebSocket started on port ${port} with route ${path}')
}
