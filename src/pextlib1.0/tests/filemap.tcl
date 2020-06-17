# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# Test file for Pextlib's filemap.
# Requires r/w access to /tmp/
# Syntax:
# tclsh filemap.tcl <Pextlib name>

proc main {pextlibname} {
    load $pextlibname

    file delete -force "/tmp/macports-pextlib-testmap"

    filemap open testmap "/tmp/macports-pextlib-testmap"
    if {[filemap exists testmap "/foo/bar"]} {
        puts {[filemap exists testmap "/foo/bar"]}
        exit 1
    }
    filemap set testmap "/foo/bar" "foobar"
    if {![filemap exists testmap "/foo/bar"]} {
        puts {![filemap exists testmap "/foo/bar"]}
        exit 1
    }
    if {[filemap get testmap "/foo/bar"] ne "foobar"} {
        puts {[filemap get testmap "/foo/bar"] ne "foobar"}
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

    filemap open testmap2 "/tmp/macports-pextlib-testmap"
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
    if {[filemap get testmap2 "/bar/bar-3"] ne "somevalue"} {
        puts {[filemap get testmap2 "/bar/bar-3"] ne "somevalue"}
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

    # open it again, r/o
    filemap open testmap3 "/tmp/macports-pextlib-testmap" readonly

    # open it again, r/w
    filemap open testmap4 "/tmp/macports-pextlib-testmap"

    # put a key (r/w copy)
    filemap set testmap4 "/rw/foobar" "foobar"

    # save the r/w copy.
    filemap save testmap4

    # check the key is not there (r/o copy)
    # (remark: the r/o copy uses the old version)
    if {[filemap exists testmap3 "/rw/foobar"]} {
        puts {[filemap exists testmap3 "/rw/foobar"]}
        exit 1
    }

    # reload the r/o copy.
    filemap revert testmap3

    # check the key is here.
    if {![filemap exists testmap3 "/rw/foobar"]} {
        puts {![filemap exists testmap3 "/rw/foobar"]}
        exit 1
    }

    filemap close testmap4

    filemap close testmap3

    # concurrency bug test
    filemap open testmap7 "/tmp/macports-pextlib-testmap"
    filemap set testmap7 "/rw/foobar" "foobar"
    filemap save testmap7
    filemap close testmap7
    filemap open testmap6 "/tmp/macports-pextlib-testmap" readonly
    filemap open testmap8 "/tmp/macports-pextlib-testmap"
    filemap unset testmap8 "/rw/foobar"
    filemap save testmap8
    filemap close testmap8
    filemap close testmap6
    filemap open testmap9 "/tmp/macports-pextlib-testmap" readonly
    if {[filemap exists testmap9 "/rw/foobar"]} {
        puts {[filemap exists testmap9 "/rw/foobar"]}
        exit 1
    }
    filemap close testmap9

    file delete -force "/tmp/macports-pextlib-testmap"

    # delete the lock file as well.
    file delete -force "/tmp/macports-pextlib-testmap.lock"

    # create a RAM-based map.
    filemap create testmap5

    # add 1000 subnodes.
    for {set index 0} {$index < 1000} {incr index} {
        filemap set testmap5 "/many/foo-$index" "foo-$index"
    }

    # add another 1000 subnodes, lexicographically before.
    for {set index 0} {$index < 1000} {incr index} {
        filemap set testmap5 "/many/bar-$index" "foo-$index"
    }

    # check the 1000 subnodes.
    for {set index 0} {$index < 1000} {incr index} {
        if {[filemap get testmap5 "/many/foo-$index"] != "foo-$index"} {
            puts {[filemap get testmap5 "/many/foo-$index"] != "foo-$index"}
            puts $index
            puts [filemap get testmap5 "/many/foo-$index"]
            exit 1
        }
        if {[filemap get testmap5 "/many/bar-$index"] != "foo-$index"} {
            puts {[filemap get testmap5 "/many/bar-$index"] != "foo-$index"}
            puts $index
            puts [filemap get testmap5 "/many/bar-$index"]
            exit 1
        }
    }

    # close the virtual filemap.
    filemap close testmap5
}

main $argv
