module hikari

// Responseは内部でveb.Resultに変換（ユーザーからは見えない）
pub struct Response {
pub mut:
	body   []u8
	// cached string representation to avoid bytestr() at send time when available
	body_str string
	status int = 200
	headers map[string]string
}

pub type Next = fn () !Response
pub type Handler = fn (mut Context) !Response
pub type Middleware = fn (mut Context, Next) !Response
pub type Any = string | int | bool | f32 | f64 | []Any | map[string]Any
