module main

enum NodeKind {
	empty
	dir
	file
}

[heap]
struct Node {
	iid int
	parent &Node
	name string
	kind NodeKind
	mut:
	children []Node
	content string
}

fn (node Node) path() string {
	if node.parent == 0 {
		return "/"
	}

	if node.parent.path() == "/" {
		return "/$node.name"
	}

	return [node.parent.path(), node.name].join("/")
}

fn (node &Node) find(path string) ?&Node {
	if node.path() == path {
		return node
	}

	for child in node.children {
		if child.path() == path {
			return &child
		}

		child_result := child.find(path) or { &Node{parent: 0, kind: .empty} }
		if child_result.kind != .empty {
			return child_result
		}
	}

	return none
}