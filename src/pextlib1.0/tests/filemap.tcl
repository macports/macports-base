# Test file for Pextlib's filemap.
# Requires r/w access to /tmp/
# Syntax:
# tclsh filemap.tcl <Pextlib name>

proc main {pextlibname} {
	load $pextlibname
	
	file delete -force "/tmp/darwinports-pextlib-testmap"

	filemap open testmap "/tmp/darwinports-pextlib-testmap"
	if {[filemap exists testmap "/foo/bar"]} {
		puts {[filemap exists testmap "/foo/bar"]}
		exit 1
	}
	filemap set testmap "/foo/bar" "foobar"
	if {![filemap exists testmap "/foo/bar"]} {
		puts {![filemap exists testmap "/foo/bar"]}
		exit 1
	}
	if {[filemap get testmap "/foo/bar"] != "foobar"} {
		puts {[filemap get testmap "/foo/bar"] != "foobar"}
		exit 1
	}
	filemap unset testmap "/foo/bar"
	if {[filemap exists testmap "/foo/bar"]} {
		puts {[filemap exists testmap "/foo/bar"] (2)}
		exit 1
	}

	filemap set testmap "/foo/bar" "foobar-1"
	filemap set testmap "/foo/foo" "foobar-2"
	filemap set testmap "/bar/foo" "foobar-3"
	filemap set testmap "/foobar" "foobar-4"

	if {[filemap get testmap "/foo/foo"] != "foobar-2"} {
		puts {[filemap get testmap "/foo/foo"] != "foobar-2"}
		puts [filemap get testmap "/foo/foo"]
		exit 1
	}
	
	filemap save testmap

	filemap set testmap "/foo/bar-1" "somevalue"
	filemap set testmap "/foo/bar-2" "somevalue"
	filemap set testmap "/bar/bar-3" "somevalue"
	
	set theList [filemap list testmap "somevalue"]
	if {[llength $theList] != 3} {
		puts {[llength $theList] != 3}
		exit 1
	}
	if {[lindex $theList 0] != "/bar/bar-3"} {
		puts {[lindex $theList 2] != "/bar/bar-3"}
		exit 1
	}
	if {[lindex $theList 1] != "/foo/bar-1"} {
		puts {[lindex $theList 0] != "/foo/bar-1"}
		exit 1
	}
	if {[lindex $theList 2] != "/foo/bar-2"} {
		puts {[lindex $theList 1] != "/foo/bar-2"}
		exit 1
	}

	filemap set testmap "/a/b/c/d/e/f/g/foo.h" "foo"
	filemap set testmap "/a/b/c/d/e/f/g/foo/bar" "foo"

	# add 1000 subnodes.
	for {set index 0} {$index < 1000} {incr index} {
		filemap set testmap "/many/foo-$index" "foo-$index"
	}

	# add another 1000 subnodes, lexicographically before.
	for {set index 0} {$index < 1000} {incr index} {
		filemap set testmap "/many/bar-$index" "foo-$index"
	}

	# save again
	filemap save testmap
	
	# add some value that won't be saved.
	filemap set testmap "/unsaved" "unsaved"
	
	# revert the map.
	filemap revert testmap

	filemap close testmap

	filemap open testmap2 "/tmp/darwinports-pextlib-testmap"
	if {[filemap exists testmap2 "/foo/foobar"]} {
		puts {[filemap exists testmap2 "/foo/foobar"]}
		exit 1
	}
	if {![filemap exists testmap2 "/foo/bar"]} {
		puts {![filemap exists testmap2 "/foo/bar"]}
		exit 1
	}
	if {[filemap get testmap2 "/foo/bar"] != "foobar-1"} {
		puts {[filemap get testmap2 "/foo/bar"] != "foobar-1"}
		puts [filemap get testmap2 "/foo/bar"]
		exit 1
	}
	if {[filemap get testmap2 "/foo/foo"] != "foobar-2"} {
		puts {[filemap get testmap2 "/foo/foo"] != "foobar-2"}
		puts [filemap get testmap2 "/foo/foo"]
		exit 1
	}
	if {[filemap get testmap2 "/bar/foo"] != "foobar-3"} {
		puts {[filemap get testmap2 "/bar/foo"] != "foobar-3"}
		puts [filemap get testmap2 "/bar/foo"]
		exit 1
	}
	if {[filemap get testmap2 "/foobar"] != "foobar-4"} {
		puts {[filemap get testmap2 "/foobar"] != "foobar-4"}
		puts [filemap get testmap2 "/foobar"]
		exit 1
	}
	if {[filemap get testmap2 "/bar/bar-3"] != "somevalue"} {
		puts {[filemap get testmap2 "/bar/bar-3"] != "somevalue"}
		puts [filemap get testmap2 "/bar/bar-3"]
		exit 1
	}

	set theList [filemap list testmap2 "somevalue"]
	if {[llength $theList] != 3} {
		puts {[llength $theList] != 3}
		exit 1
	}
	if {[lindex $theList 0] != "/bar/bar-3"} {
		puts {[lindex $theList 2] != "/bar/bar-3"}
		exit 1
	}
	if {[lindex $theList 1] != "/foo/bar-1"} {
		puts {[lindex $theList 0] != "/foo/bar-1"}
		exit 1
	}
	if {[lindex $theList 2] != "/foo/bar-2"} {
		puts {[lindex $theList 1] != "/foo/bar-2"}
		exit 1
	}

	# check the 1000 subnodes.
	for {set index 0} {$index < 1000} {incr index} {
		if {[filemap get testmap2 "/many/foo-$index"] != "foo-$index"} {
			puts {[filemap get testmap2 "/many/foo-$index"] != "foo-$index"}
			puts $index
			puts [filemap get testmap2 "/many/foo-$index"]
			exit 1
		}
		if {[filemap get testmap2 "/many/bar-$index"] != "foo-$index"} {
			puts {[filemap get testmap2 "/many/bar-$index"] != "foo-$index"}
			puts $index
			puts [filemap get testmap2 "/many/bar-$index"]
			exit 1
		}
	}

	if {[filemap exists testmap2 "/unsaved"]} {
		puts {[filemap exists testmap2 "/unsaved"]}
		exit 1
	}

	filemap close testmap2

	file delete "/tmp/darwinports-pextlib-testmap"
}

main $argv