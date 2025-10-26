module hikari

import regex

// Pattern + Route types and trie-based router implementation.
// These were split out of app.v to keep the file smaller and focused.

struct Pattern {
    raw_path string
mut:
    regex       regex.RE
    param_names []string
}

struct Route {
mut:
    pattern     Pattern
    middlewares []Middleware
    handler     ?Handler
}

pub struct TrieNode {
pub mut:
    children map[string]&TrieNode
    param_name string
    param_greedy bool
    param_regex string
    param_regex_compiled regex.RE
    param_regex_has bool
    handler     ?Handler
    middlewares []Middleware
}

fn new_trienode() &TrieNode {
    return &TrieNode{
        children: map[string]&TrieNode{}
        param_name: ''
        param_greedy: false
        param_regex: ''
        // compiled regex zero-value is acceptable; has flag tracks validity
        param_regex_has: false
    }
}

fn compile_pattern(path string) Pattern {
    mut param_names := []string{}
    mut regex_path := path
    mut re := regex.regex_opt(r':(\w+)') or { panic(err) }
    matches := re.find_all_str(path)
    for m in matches {
        param_name := m.replace(':', '')
        param_names << param_name
        regex_path = regex_path.replace(m, r'(\w+)')
    }
    return Pattern{
        raw_path: path
        regex: regex.regex_opt(regex_path + '$') or { panic(err) }
        param_names: param_names
    }
}

// add_route and handle_request are methods on Hikari but implemented
// here to keep router logic together.
pub fn (mut app Hikari) add_route(method string, path string, handler Handler, middlewares []Middleware) {
    route := Route{
        pattern: compile_pattern(path)
        middlewares: middlewares
        handler: handler
    }
    m := method.to_upper()

    if route.pattern.param_names.len == 0 {
        if m !in app.exact_routes {
            app.exact_routes[m] = map[string]Route{}
        }
        app.exact_routes[m][path] = route
        return
    }

    if m !in app.tries {
        app.tries[m] = new_trienode()
    }

    mut node := app.tries[m] or { new_trienode() }
    if m !in app.tries {
        app.tries[m] = node
    }

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
        if seg.len == 0 { continue }
        if seg[0] == `:` {
            mut param_name := ''
            mut greedy := false
            mut param_re := ''
            if seg.ends_with('...') {
                param_name = if seg.len > 4 { seg[1..seg.len-3] } else { '' }
                greedy = true
            } else if seg.contains('(') && seg.contains(')') {
                parts := seg.split('(')
                param_name = if parts[0].len > 1 { parts[0][1..] } else { '' }
                pat := seg.all_after('(').all_before(')')
                if pat != '' { param_re = '^' + pat + '$' }
            } else {
                param_name = if seg.len > 1 { seg[1..] } else { '' }
            }

            if ':' !in node.children {
                mut child := new_trienode()
                child.param_name = param_name
                child.param_greedy = greedy
                child.param_regex = param_re
                if param_re != '' {
                    if compiled := regex.regex_opt(param_re) {
                        child.param_regex_compiled = compiled
                        child.param_regex_has = true
                    }
                }
                node.children[':'] = child
            } else {
                mut child := node.children[':'] or { new_trienode() }
                if child.param_name == '' { child.param_name = param_name }
                if !child.param_greedy && greedy { child.param_greedy = true }
                if child.param_regex == '' && param_re != '' {
                    child.param_regex = param_re
                    if compiled := regex.regex_opt(param_re) {
                        child.param_regex_compiled = compiled
                        child.param_regex_has = true
                    }
                }
                node.children[':'] = child
            }
            node = node.children[':'] or { new_trienode() }
        } else {
            if seg !in node.children {
                node.children[seg] = new_trienode()
            }
            node = node.children[seg] or { new_trienode() }
        }
    }
    node.handler = handler
    node.middlewares = middlewares
}

pub fn (mut app Hikari) handle_request(mut ctx Context) !Response {
    method := ctx.request.method.to_upper()

    // 1. Exact match (fast path)
    if method in app.exact_routes {
        if m := app.exact_routes[method] {
            if route := m[ctx.request.path] {
                if handler := route.handler {
                    return handler(mut ctx)
                }
            }
        }
    }

    // 2. Trie match for parameterized routes
    if method in app.tries {
        mut node := app.tries[method] or { return ctx.not_found() }
        path := ctx.request.path

        if path != "/" {
            mut start := 1
            for {
                // if '/' is not found, 'end' becomes the length of the path.
                end := path.index_after('/', start) or { path.len }
                
                seg := path[start..end]

                if seg in node.children {
                    node = node.children[seg] or { return ctx.not_found() }
                } else if ":" in node.children {
                    mut child := node.children[":"] or { return ctx.not_found() }
                    if child.param_greedy {
                        ctx.params[child.param_name] = path[start..]
                        node = child
                        break // Greedy match is always last
                    }
                    if child.param_regex_has {
                        if !child.param_regex_compiled.matches_string(seg) {
                            return ctx.not_found()
                        }
                    }
                    ctx.params[child.param_name] = seg
                    node = child
                } else {
                    return ctx.not_found()
                }

                if end == path.len {
                    break
                }
                start = end + 1
            }
        }
        
        if handler := node.handler {
            return handler(mut ctx)
        }
    }

    return ctx.not_found()
}
