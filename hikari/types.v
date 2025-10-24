module hikari

// Responseは内部でveb.Resultに変換（ユーザーからは見えない）
pub struct Response {
pub mut:
	body   string
	status int = 200
	headers map[string]string
}

// Hikariライクな型定義（超シンプル）
pub type Next = fn () !Response
pub type Handler = fn (Context) !Response
pub type Middleware = fn (Context, Next) !Response
pub type Any = string | int | bool | f32 | f64 | []Any | map[string]Any
