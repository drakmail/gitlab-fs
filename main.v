module main

import os
import net.http
import json

struct AppContext {
	name string
	root Node
}

fn (ctx &AppContext) open(vpath string, fi &C.fuse_file_info) int {
	println("open $vpath ($ctx.name)")

	ctx.root.find(vpath) or {
		return -C.ENOENT
	}
	if (fi.flags & 3) != C.O_RDONLY {
		return -C.EACCES
	}

	return 0
}

fn (ctx &AppContext) read(vpath string) ?string {
	println("read $vpath ($ctx.name)")

	node := ctx.root.find(vpath) or {
		return none
	}
	if node.kind == .dir {
		return none
	}

	return node.content
}

fn (ctx &AppContext) getattr(vpath string, mut stbuf &C.stat) int {
	println("getattr $vpath ($ctx.name)")

	node := ctx.root.find(vpath) or {
		println("NOENT")
		return -C.ENOENT
	}

	if node.kind == .dir {
		println("DIR")
		stbuf.st_mode = u32(C.S_IFDIR) | u32(0o755)
		stbuf.st_nlink = 2
		return 0
	}
	if node.kind == .file {
		println("FILE")
		stbuf.st_mode = u32(C.S_IFREG) | u32(0o766)
		stbuf.st_nlink = 1
		stbuf.st_size = u64(node.content.len)
		return 0
	}

	return 0
}

fn (ctx &AppContext) readdir(vpath string) ?[]string {
	println("readdir $vpath")

	mut node := ctx.root.find(vpath) or {
		println("NOENT")
		return none
	}

	println("node: $node.iid")
	println("node: $node.iid")

	if node.children.len == 0 {
		println("children is empty... fetching")
		data := fetch_items(node.iid) ?
		for item in data {
			node.children << Node{parent: node, name: item.path, iid: item.id, kind: .dir}
		}
	}

	return node.children.map(it.name)
}

struct GitlabGroup {
	id int [required]
	path string [required]
}

fn fetch_items(id int) ?[]GitlabGroup {
	println("start fetching children nodes $id")

	url := "https://gitlab.com/api/v4/groups/$id/subgroups"

	mut req := http.new_request(.get, url, "") or {
		eprintln("error: $err")
		return none
	}
	res := req.do() or {
		eprintln("failed to do request: $err")
		return none
	}

	data := json.decode([]GitlabGroup, res.text) or {
		eprintln('Failed to decode json, error: $err')
		return none
	}

	println("fetched")

	return data
}

fn main() {
	mut root := Node{
		parent: 0,
		kind: .dir,
		name: "/",
		iid: 9970,
	}

	context := Fuse(AppContext{
		name: "example",
		root: root
	})
	context_ref := &context

	open_closure := fn [context_ref] (path &char, fi &C.fuse_file_info) int {
		return context_ref.fuse_open(path, fi)
	}
	read_closure := fn [context_ref] (path &char, mut buf &char, size u64, offset u64, fi &C.fuse_file_info) i64 {
		return context_ref.fuse_read(path, mut buf, size, offset, fi)
	}
	getattr_closure := fn [context_ref] (path &char, mut stbuf &C.stat) int {
		return context_ref.fuse_getattr(path, mut stbuf)
	}
	readdir_closure := fn [context_ref] (path &char, buf voidptr, filler FuseFillDirT, offset u64, fi &C.fuse_file_info) int {
		return context_ref.fuse_readdir(path, buf, filler, offset, fi)
	}

	hello_oper := C.fuse_operations{
		readdir: &readdir_closure,
		getattr: &getattr_closure,
		open: &open_closure,
		read: &read_closure,
	}

	C.fuse_main(os.args.len, os.args.map(it.str).data, &hello_oper, C.NULL)
}