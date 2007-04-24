# Test file for Pextlib's fs-traverse
# Requires r/w access to /tmp
# MacPorts must be installed for this to work

catch {source /Library/Tcl/darwinports1.0/darwinports_fastload.tcl}
# load the current copy of portutil instead of the installed one
source [file dirname [info script]]/../portutil.tcl
package require darwinports

# boilerplate necessary for using the macports infrastructure
proc ui_isset {val} { return 0 }

# no global options
proc global_option_isset {val} { return 0 }

# UI callback
proc ui_prefix {priority} {
    switch $priority {
        debug {
            return "DEBUG: "
        }
        error {
            return "Error: "
        }
        warn {
            return "Warning: "
        }
        default {
            return ""
        }
    }
}

proc ui_channels {priority} {
    switch $priority {
        debug -
        info {
            return {}
        }
        msg {
            return {stdout}
        }
        error {
            return {stderr}
        }
        default {
            return {stdout}
        }
    }
}

array set ui_options {}
array set global_options {}
array set global_variations {}
dportinit ui_options global_options global_variations

# end boilerplate

namespace eval tests {

proc test_delete {} {
    set root "/tmp/macports-portutil-delete"
    # use file delete -force to kill the test directory if it already exists
    # yeah I realize this will fail on 10.3 if it already exists. oh well.
    file delete -force $root
    mtree $root {
        a               directory
        a/a             file
        a/b             file
        a/c             directory
        a/c/a           file
        a/c/b           {link ../b}
        a/c/c           {link ../../b}
        a/c/d           directory
        a/c/d/a         file
        a/c/d/b         directory
        a/c/d/c         file
        a/d             file
        b               directory
        b/a             file
        b/b             {link q}
        b/c             directory
        b/c/a           file
        b/c/b           file
        b/d             file
    }
    
    # test multiple args
    delete $root/a $root/b
    
    if {[file exists $root/a] || [file exists $root/b]} {
        file delete -force $root
        error "delete failed"
    }
    file delete -force $root
}

# Create a filesystem hierarchy based on the given specification
# The mtree spec consists of name/type pairings, where type can be
# one of directory, file or link. If type is link, it must be a
# two-element list containing the path as the second element
proc mtree {root spec} {
    foreach {entry typelist} $spec {
        set type [lindex $typelist 0]
        set link [lindex $typelist 1]
        set file [file join $root $entry]
        switch $type {
            directory {
                file mkdir $file
            }
            file {
                # touch
                close [open $file w]
            }
            link {
                # file link doesn't let you link to files that don't exist
                # so lets farm out to /bin/ln
                exec /bin/ln -s $link $file
            }
            default {
                return -code error "Unknown file map type: $typelist"
            }
        }
    }
}

# run all tests
foreach proc [info procs test_*] {
    $proc
}

# namespace eval tests
}
