module hikari

import sync

pub struct BufferPool {
pub mut:
	mu       sync.Mutex
	pool     [][]u8
	buf_size int
}

pub fn new_pool(buf_size int, count int) &BufferPool {
	mut p := &BufferPool{
		pool:     [][]u8{}
		buf_size: buf_size
	}
	for _ in 0 .. count {
		mut b := []u8{cap: buf_size}
		p.pool << b
	}
	return p
}

pub fn (mut p BufferPool) rent() []u8 {
	p.mu.lock()
	defer { p.mu.unlock() }
	if p.pool.len > 0 {
		buf := p.pool[p.pool.len - 1]
		p.pool.delete(p.pool.len - 1)
		return buf
	}
	return []u8{cap: p.buf_size}
}

pub fn (mut p BufferPool) give(mut buf []u8) {
	// reset length but keep capacity
	// Avoid cloning the slice here to prevent an extra allocation.
	// Reset length while preserving capacity. Use `unsafe` slice to avoid
	// an implicit clone warning from the compiler.
	unsafe {
		buf = buf[..0]
	}
	p.mu.lock()
	defer { p.mu.unlock() }
	p.pool << buf
}

// no global default here; consumers can create or use the pool as needed
