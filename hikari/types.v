module hikari

// Responseは内部でveb.Resultに変換（ユーザーからは見えない）
pub struct Response {
pub mut:
	body []u8
	// cached string representation to avoid bytestr() at send time when available
	body_str string
	status   int = 200
	headers  map[string]string
}

pub type Next = fn () !Response

pub type Handler = fn (mut Context) !Response

pub type Middleware = fn (mut Context, Next) !Response

// Keep the numeric types limited to avoid V cgen sumtype issues on some
// V versions (mixing many numeric types can trigger a codegen error).
// Use `f64` for floats; remove `f32` to keep the sumtype simpler.
// Use a float alias to avoid json codegen conflicts between `int` and
// `f64` when generating decoding code for sumtypes on some V versions.
pub type Float = f64

pub type Any = string | int | bool | Float | []Any | map[string]Any
