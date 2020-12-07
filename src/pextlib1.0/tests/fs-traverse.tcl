# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# Test file for Pextlib's fs-traverse
# Requires r/w access to /tmp
# Syntax:
# tclsh fs-traverse.tcl <Pextlib name>

proc main {pextlibname} {
    global trees errorInfo

    load $pextlibname

    set root "/tmp/macports-pextlib-fs-traverse"

    file delete -force $root

    setup_trees $root

    # make the directory root structure
    make_root

    # perform tests
    set result [catch {
        # Basic fs-traverse test
        set output [list]
        fs-traverse file [list $root] {
            lappend output $file
        }
        check_output $output $trees(1)

        # Test starting with a symlink
        set output [list]
        fs-traverse file [list $root/a/c/a] {
            lappend output $file
        }
        check_output $output $trees(sub1)

        # Test starting with a slash-ended symlink
        set output [list]
        fs-traverse file [list $root/a/c/a/] {
            lappend output [string map {// /} $file]
        }
        check_output $output $trees(sub2)

        # Test -depth
        set output [list]
        fs-traverse -depth file [list $root] {
            lappend output $file
        }
        check_output $output $trees(2)

        # Test multiple sources
        set output [list]
        fs-traverse file [list $root/a $root/b] {
            lappend output $file
        }
        check_output $output $trees(3)

        # Test multiple sources with -depth
        set output [list]
        fs-traverse -depth file [list $root/a $root/b] {
            lappend output $file
        }
        check_output $output $trees(4)

        # Error raised for traversing directory that does not exist
        if {![catch {fs-traverse file [list $root/does_not_exist] {}}]} {
            error "fs-traverse did not raise an error for a missing directory"
        }

        # Test -ignoreErrors
        if {[catch {fs-traverse -ignoreErrors file [list $root/does_not_exist] {}}]} {
            error "fs-traverse raised an error despite -ignoreErrors"
        }

        # Test -ignoreErrors with multiple sources, make sure it still gets the sources after the error
        if {[catch {
            set output [list]
            fs-traverse -depth -ignoreErrors file [list $root/a $root/c $root/b] {
                lappend output $file
            }
            check_output $output $trees(4)
        }]} {
            error "fs-traverse raised an error despite -ignoreErrors"
        }

        # Test skipping parts of the tree
        set output [list]
        fs-traverse file [list $root] {
            if {[string match "*/a" $file]} {
                continue
            }
            lappend output $file
        }
        check_output $output $trees(5)

        # Test -tails option
        set output [list]
        fs-traverse -tails file [list $root] {
            lappend output $file
        }
        check_output $output $trees(6) $root

        # Test -tails option with trailing slash
        set output [list]
        fs-traverse -tails file [list $root/] {
            lappend output $file
        }
        check_output $output $trees(6) $root

        # Test -tails option with multiple paths
        # It should error out
        if {![catch {
            fs-traverse -tails file [list $root/a $root/b] {}
        }]} {
            error "fs-traverse did not error when using multiple paths with -tails"
        }

        # Test cutting the traversal short
        set output [list]
        fs-traverse file [list $root] {
            lappend output $file
            if {[file type $file] eq "link"} {
                break
            }
        }

        # Test using an array variable as varname
        # It should error out
        if {![catch {
            array set aryvar {}
            fs-traverse aryvar [list $root] {}
        }]} {
            error "fs-traverse did not error when setting the variable"
        }

        # Same test with -ignoreErrors
        if {[catch {
            array set aryvar {}
            fs-traverse -ignoreErrors aryvar [list $root] {}
        }]} {
            error "fs-traverse errored out when setting the variable despite -ignoreErrors"
        }

        # Test using a malformed target list
        if {![catch {fs-traverse file "$root/a \{$root/b" {}}]} {
            error "fs-traverse did not error with malformed target list"
        }

        # Test again with -ignoreErrors - this is the one case where it should still error
        if {![catch {fs-traverse -ignoreErrors file "$root/a \{$root/b" {}}]} {
            error "fs-traverse did not error with malformed target list using -ignoreErrors"
        }

        # Test wacky variable name called -depth
        set output [list]
        fs-traverse -- -depth [list $root] {
            lappend output ${-depth}
        }
        check_output $output $trees(1)

        # NOTE: This should be the last test performed, as it modifies the file tree
        # Test to make sure deleting files during traversal works as expected
        set output [list]
        fs-traverse file [list $root] {
            if {[string match "*/a" $file]} {
                # use /bin/rm because on 10.3 file delete doesn't work on directories properly
                exec -ignorestderr /bin/rm -rf $file
                continue
            }
            lappend output $file
        }
        check_output $output $trees(5)
    } errMsg]
    set savedInfo $errorInfo

    # Clean up
    file delete -force $root

    # Re-raise error if one occurred in the test block
    if {$result} {
        error $errMsg $savedInfo
    }
}

proc check_output {output tree {root ""}} {
    foreach file $output {entry typelist} $tree {
        set type [lindex $typelist 0]
        set link [lindex $typelist 1]
        if {$file ne $entry} {
            error "Found `$file', expected `$entry'"
        } elseif {[file type [file join $root $file]] ne $type} {
            error "File `$file' had type `[file type $file]', expected type `$type'"
        } elseif {$type eq "link" && [file readlink [file join $root $file]] ne $link} {
            error "File `$file' linked to `[file readlink $file]', expected link to `$link'"
        }
    }
}

proc make_root {} {
    global trees
    foreach {entry typelist} $trees(1) {
        set type [lindex $typelist 0]
        set link [lindex $typelist 1]
        switch $type {
            directory {
                file mkdir $entry
            }
            file {
                # touch
                close [open $entry w]
            }
            link {
                # file link doesn't let you link to files that don't exist
                # so lets farm out to /bin/ln
                exec -ignorestderr /bin/ln -s $link $entry
            }
            default {
                return -code error "Unknown file map type: $typelist"
            }
        }
    }
}

proc setup_trees {root} {
    global trees

    array set trees {}

    set trees(1) "
        $root           directory
        $root/a         directory
        $root/a/a       file
        $root/a/b       file
        $root/a/c       directory
        $root/a/c/a     {link ../d}
        $root/a/c/b     file
        $root/a/c/c     directory
        $root/a/c/d     file
        $root/a/d       directory
        $root/a/d/a     file
        $root/a/d/b     {link ../../b/a}
        $root/a/d/c     directory
        $root/a/d/d     file
        $root/a/e       file
        $root/b         directory
        $root/b/a       directory
        $root/b/a/a     file
        $root/b/a/b     file
        $root/b/a/c     file
        $root/b/b       directory
        $root/b/c       directory
        $root/b/c/a     file
        $root/b/c/b     file
        $root/b/c/c     file
    "

    set trees(sub1) "
        $root/a/c/a     {link ../d}
        $root/a/c/a/a   file
        $root/a/c/a/b   {link ../../b/a}
        $root/a/c/a/c   directory
        $root/a/c/a/d   file
    "

    set trees(sub2) "
        $root/a/c/a/     {link ../d}
        $root/a/c/a/a   file
        $root/a/c/a/b   {link ../../b/a}
        $root/a/c/a/c   directory
        $root/a/c/a/d   file
    "

    set trees(2) "
        $root/a/a       file
        $root/a/b       file
        $root/a/c/a     {link ../d}
        $root/a/c/b     file
        $root/a/c/c     directory
        $root/a/c/d     file
        $root/a/c       directory
        $root/a/d/a     file
        $root/a/d/b     {link ../../b/a}
        $root/a/d/c     directory
        $root/a/d/d     file
        $root/a/d       directory
        $root/a/e       file
        $root/a         directory
        $root/b/a/a     file
        $root/b/a/b     file
        $root/b/a/c     file
        $root/b/a       directory
        $root/b/b       directory
        $root/b/c/a     file
        $root/b/c/b     file
        $root/b/c/c     file
        $root/b/c       directory
        $root/b         directory
        $root           directory
    "

    set trees(3) "
        $root/a         directory
        $root/a/a       file
        $root/a/b       file
        $root/a/c       directory
        $root/a/c/a     {link ../d}
        $root/a/c/b     file
        $root/a/c/c     directory
        $root/a/c/d     file
        $root/a/d       directory
        $root/a/d/a     file
        $root/a/d/b     {link ../../b/a}
        $root/a/d/c     directory
        $root/a/d/d     file
        $root/a/e       file
        $root/b         directory
        $root/b/a       directory
        $root/b/a/a     file
        $root/b/a/b     file
        $root/b/a/c     file
        $root/b/b       directory
        $root/b/c       directory
        $root/b/c/a     file
        $root/b/c/b     file
        $root/b/c/c     file
    "

    set trees(4) "
        $root/a/a       file
        $root/a/b       file
        $root/a/c/a     {link ../d}
        $root/a/c/b     file
        $root/a/c/c     directory
        $root/a/c/d     file
        $root/a/c       directory
        $root/a/d/a     file
        $root/a/d/b     {link ../../b/a}
        $root/a/d/c     directory
        $root/a/d/d     file
        $root/a/d       directory
        $root/a/e       file
        $root/a         directory
        $root/b/a/a     file
        $root/b/a/b     file
        $root/b/a/c     file
        $root/b/a       directory
        $root/b/b       directory
        $root/b/c/a     file
        $root/b/c/b     file
        $root/b/c/c     file
        $root/b/c       directory
        $root/b         directory
    "

    set trees(5) "
        $root           directory
        $root/b         directory
        $root/b/b       directory
        $root/b/c       directory
        $root/b/c/b     file
        $root/b/c/c     file
    "

    set trees(6) "
        .               directory
        a               directory
        a/a             file
        a/b             file
        a/c             directory
        a/c/a           {link ../d}
        a/c/b           file
        a/c/c           directory
        a/c/d           file
        a/d             directory
        a/d/a           file
        a/d/b           {link ../../b/a}
        a/d/c           directory
        a/d/d           file
        a/e             file
        b               directory
        b/a             directory
        b/a/a           file
        b/a/b           file
        b/a/c           file
        b/b             directory
        b/c             directory
        b/c/a           file
        b/c/b           file
        b/c/c           file
    "
}

main $argv
