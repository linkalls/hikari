module hikari

// Represents a node in the Radix Tree Router.
@[heap]
pub struct TrieNode {
pub mut:
	children     map[string]&TrieNode
	param_name   string
	param_greedy bool
	handler      ?Handler
	middlewares  []Middleware
}

pub fn new_trienode() &TrieNode {
	return &TrieNode{
		children:     map[string]&TrieNode{}
		param_name:   ''
		param_greedy: false
	}
}

pub fn (mut node TrieNode) add_route(path string, handler Handler, middlewares []Middleware) {
	mut curr := unsafe { node }
	mut trimmed := path
	if trimmed.len > 0 && trimmed[0] == `/` {
		trimmed = trimmed[1..]
	}
	segs := if trimmed == '' { []string{} } else { trimmed.split('/') }

	if segs.len == 0 {
		node.handler = handler
		node.middlewares = middlewares
		return
	}

	for _, seg in segs {
		if seg.len == 0 {
			continue
		}
		if seg[0] == `:` {
			mut param_name := ''
			mut greedy := false

			if seg.ends_with('...') {
				param_name = if seg.len > 4 { seg[1..seg.len - 3] } else { '' }
				greedy = true
			} else {
				param_name = if seg.len > 1 { seg[1..] } else { '' }
			}

			if ':' !in curr.children {
				mut child := new_trienode()
				child.param_name = param_name
				child.param_greedy = greedy
				curr.children[':'] = child
			} else {
				mut child := curr.children[':'] or { new_trienode() }
				if child.param_name == '' {
					child.param_name = param_name
				}
				if !child.param_greedy && greedy {
					child.param_greedy = true
				}
				curr.children[':'] = child
			}
			curr = unsafe { curr.children[':'] or { new_trienode() } }
		} else {
			if seg !in curr.children {
				curr.children[seg] = new_trienode()
			}
			curr = unsafe { curr.children[seg] or { new_trienode() } }
		}
	}
	curr.handler = handler
	curr.middlewares = middlewares
}

// Find a route matching the given path using the Radix Tree.
// Uses string slices (`path[start..end]`) to avoid memory allocations.
pub fn (node &TrieNode) find_route(path string, mut ctx Context) ?(&TrieNode, []Middleware) {
	mut curr := unsafe { node }
	mut middlewares := []Middleware{cap: 4}

	// Fast path for root
	if path == '/' || path == '' {
		if curr.handler != none {
			if curr.middlewares.len > 0 {
				middlewares << curr.middlewares
			}
			return curr, middlewares
		}
		return none
	}

	mut start := 1 // skip the leading '/'
	for {
		// End of string reached
		if start >= path.len {
			break
		}

		end := path.index_after('/', start) or { path.len }
		seg := path[start..end]

		if curr.middlewares.len > 0 {
			middlewares << curr.middlewares
		}

		if seg in curr.children {
			curr = unsafe { curr.children[seg] or { return none } }
		} else if ':' in curr.children {
			child := curr.children[':'] or { return none }
			if child.param_greedy {
				ctx.params[child.param_name] = path[start..]
				if child.middlewares.len > 0 {
					middlewares << child.middlewares
				}
				return child, middlewares
			}
			ctx.params[child.param_name] = seg
			curr = unsafe { child }
		} else {
			return none
		}

		if end == path.len {
			break
		}
		start = end + 1
	}

	if curr.middlewares.len > 0 {
		middlewares << curr.middlewares
	}

	if curr.handler != none {
		return curr, middlewares
	}

	return none
}
