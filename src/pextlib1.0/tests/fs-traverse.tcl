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
        fs-traverse file $root {
            lappend output $file
        }
        check_output $output $trees(1)
        
        # Test starting with a symlink
        set output [list]
        fs-traverse file $root/a/c/a {
            lappend output $file
        }
        check_output $output $trees(sub1)
        
        # Test -depth
        set output [list]
        fs-traverse -depth file $root {
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
        if {![catch {fs-traverse file $root/does_not_exist {}}]} {
            error "fs-traverse did not raise an error for a missing directory"
        }
        
        # Test -ignoreErrors
        if {[catch {fs-traverse -ignoreErrors file $root/does_not_exist {}}]} {
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
        fs-traverse file $root {
            lappend output $file
            if {[string match */a $file]} {
                continue
            }
        }
        check_output $output $trees(5)
        
        # Test cutting the traversal short
        set output [list]
        fs-traverse file $root {
            lappend output $file
            if {[file type $file] eq "link"} {
                break
            }
        }
    } errMsg]
    set savedInfo $errorInfo
    
    # Clean up
    file delete -force $root
    
    # Re-raise error if one occurred in the test block
    if {$result} {
        error $errMsg $savedInfo
    }
}

proc check_output {output tree} {
    foreach file $output {entry typelist} $tree {
        set type [lindex $typelist 0]
        set link [lindex $typelist 1]
        if {$file ne $entry} {
            error "Found `$file', expected `$entry'"
        } elseif {[file type $file] ne $type} {
            error "File `$file' had type `[file type $file]', expected type `$type'"
        } elseif {$type eq "link" && [file readlink $file] ne $link} {
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
                exec /bin/ln -s $link $entry
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
        $root/a         directory
        $root/b         directory
        $root/b/a       directory
        $root/b/b       directory
        $root/b/c       directory
        $root/b/c/a     file
        $root/b/c/b     file
        $root/b/c/c     file
    "
    
    set trees(6) "
        $root           directory
        $root/a         directory
        $root/a/a       file
        $root/a/b       file
        $root/a/c       directory
        $root/a/c/a     {link ../d}
    "
}

main $argv