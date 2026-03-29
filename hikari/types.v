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

// HTTPステータスコード付きエラー型
// IError インターフェースを実装する
pub struct HttpError {
pub:
	status  int
	message string
}

pub fn (e &HttpError) msg() string {
	return e.message
}

pub fn (e &HttpError) code() int {
	return e.status
}

// HTTPステータスコード付きエラーを生成するヘルパー関数
pub fn http_error(status int, message string) IError {
	return &HttpError{
		status:  status
		message: message
	}
}
