module hikari

import sync
import rand

const n_stripes = 32 // Number of stripes, can be tuned

struct PoolStripe {
mut:
	mu   sync.Mutex
	pool [][]u8
}

@[heap]
pub struct BufferPool {
mut:
	stripes  []&PoolStripe
	buf_size int
}

pub fn new_pool(buf_size int, count int) &BufferPool {
	mut stripes := []&PoolStripe{}
	for i := 0; i < n_stripes; i++ {
		stripes << &PoolStripe{
			pool: [][]u8{}
		}
	}

	mut p := &BufferPool{
		stripes: stripes
		buf_size: buf_size
	}

	// Distribute buffers evenly across stripes
	for i := 0; i < count; i++ {
		mut b := []u8{cap: buf_size}
		stripe_idx := i % n_stripes
		p.stripes[stripe_idx].pool << b
	}
	return p
}

pub fn (mut p BufferPool) rent() []u8 {
	// Use a random number to select a stripe. This provides good distribution
	// without any shared state.
	stripe_idx := rand.intn(n_stripes) or { 0 }
	mut stripe := p.stripes[stripe_idx]

	stripe.mu.lock()
	defer {
		stripe.mu.unlock()
	}

	if stripe.pool.len > 0 {
		buf := stripe.pool.pop()
		return buf
	}

	// If stripe is empty, create a new buffer.
	return []u8{cap: p.buf_size}
}

pub fn (mut p BufferPool) give(mut buf []u8) {
	// reset length but keep capacity
	unsafe {
		buf = buf[..0]
	}

	stripe_idx := rand.intn(n_stripes) or { 0 }
	mut stripe := p.stripes[stripe_idx]

	stripe.mu.lock()
	defer {
		stripe.mu.unlock()
	}
	stripe.pool << buf
}
