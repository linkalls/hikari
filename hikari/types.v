module hikari

pub type Handler = fn (mut Context) !Response

pub type Middleware = fn (mut Context, Next) !Response

pub type Next = fn (mut Context) !Response

pub type ErrorHandler = fn (err IError, mut ctx Context) !Response

pub struct Response {
pub mut:
	status  int
	body    string
	headers map[string]string
}

pub fn (res Response) text() string {
	return res.body
}
