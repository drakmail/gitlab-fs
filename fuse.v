module main

#flag -lfuse
#flag -pthread
#flag -D_FILE_OFFSET_BITS=64
#define FUSE_USE_VERSION 26
#include "fuse.h"
#include <sys/stat.h>

struct C.fuse_file_info {
	flags int
}
struct C.stat {
	mut:
	st_size  u64
	st_mode  u32
	st_mtime int
	st_nlink u64
}

type FuseFillDirT = fn (voidptr, &char, &C.stat, u64) int

type ReadDirFn = fn (&char, voidptr, FuseFillDirT, u64, &C.fuse_file_info) int
type GetAttrFn = fn (&char, &C.stat) int
type OpenFn = fn (&char, &C.fuse_file_info) int
type ReadFn = fn (&char, &char, u64, u64, &C.fuse_file_info) i64

struct C.fuse_operations {
	readdir &ReadDirFn
	getattr &GetAttrFn
	open &OpenFn
	read &ReadFn
}
fn C.fuse_main(int, &&char, &C.fuse_operations, voidptr)

interface Fuse {
	open(path string, fi &C.fuse_file_info) int
	read(path string) ?string
	getattr(path string, mut stbuf &C.stat) int
	readdir(path string) ?[]string
}

fn (f Fuse) fuse_open(path &char, fi &C.fuse_file_info) int {
	vpath := unsafe { cstring_to_vstring(path) }

	return f.open(vpath, fi)
}

fn (f Fuse) fuse_read(path &char, mut buf &char, size u64, offset u64, fi &C.fuse_file_info) i64 {
	vpath := unsafe { cstring_to_vstring(path) }
	mut vsize := i64(size)

	content := f.read(vpath) or {
		return -C.ENOENT
	}

	len := content.len

	println("len is $len, offset is $offset")

	if offset < len {
		if i64(offset) + i64(vsize) > i64(len) {
			vsize = i64(len) - i64(offset)
		}

		unsafe { C.memcpy(buf, content.str + offset, vsize) }
	}

	return vsize
}

fn (f Fuse) fuse_getattr(path &char, mut stbuf &C.stat) int {
	stbuf = &C.stat{}
	vpath := unsafe { cstring_to_vstring(path) }

	return f.getattr(vpath, mut stbuf)
}

fn (f Fuse) fuse_readdir(path &char, buf voidptr, filler FuseFillDirT, offset u64, fi &C.fuse_file_info) int {
	vpath := unsafe { cstring_to_vstring(path) }

	content := f.readdir(vpath) or {
		return -C.ENOENT
	}

	filler(buf, ".".str, C.NULL, 0)
	filler(buf, "..".str, C.NULL, 0)

	for item in content {
		filler(buf, item.str, C.NULL, 0)
	}

	return 0
}