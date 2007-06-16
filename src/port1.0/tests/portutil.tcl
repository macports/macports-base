# Test file for Pextlib's fs-traverse
# Requires r/w access to /tmp
# MacPorts must be installed for this to work

package require macports
mportinit

# load the current copy of portutil instead of the installed one
source [file dirname [info script]]/../portutil.tcl

# end boilerplate

namespace eval tests {

proc test_delete {} {
    set root "/tmp/macports-portutil-delete"
    # use file delete -force to kill the test directory if it already exists
    # yeah I realize this will fail on 10.3 if it already exists. oh well.
    file delete -force $root
    
    try {
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
        
        # test deleting a symlink
        delete $root/a/c/b
        
        if {[file exists $root/a/c/b] || ![file exists $root/a/b]} {
            error "delete (symlink) failed"
        }
        
        # test multiple args
        delete $root/a $root/b
        
        if {[file exists $root/a] || [file exists $root/b]} {
            error "delete (multiple args) failed"
        }
    } finally {
        file delete -force $root
    }
}

proc test_depends_lib-delete {} {
    # tests depends_lib-delete
    # actually tests all option-deletes
    # but the bug was originally documented with depends_lib
    
    # depends_lib is intended to work from within a worker thread
    # so we shall oblige
    set workername [interp create]
    macports::worker_init $workername {} [macports::getportbuildpath {}] {} {}
    $workername alias scriptname info script
    set body {
        # load the current copy of portutil instead of the installed one
        source [file dirname [scriptname]]/../portutil.tcl
        package require port
        
        depends_lib port:foo port:bar port:blah
        depends_lib-delete port:blah port:bar
        array get PortInfo
    }
    if {[catch {$workername eval $body} result]} {
        interp delete $workername
        error $result $::errorInfo $::errorCode
    } else {
        interp delete $workername
    }
    array set temp $result
    if {$temp(depends_lib) ne "port:foo"} {
        error "depends_lib-delete did not delete properly"
    }
}

proc test_touch {} {
    set root "/tmp/macports-portutil-touch"
    file delete -force $root
    
    try {
        touch -c $root
        if {[file exists $root]} { error "touch failed" }
    
        touch $root
        if {![file exists $root]} { error "touch failed" }
    
        touch -a -t 199912010001.01 $root
        if {[file atime $root] != [clock scan 19991201T000101]} { error "touch failed" }
        if {[file mtime $root] == [clock scan 19991201T000101]} { error "touch failed" }
    
        touch -m -t 200012010001.01 $root
        if {[file atime $root] == [clock scan 20001201T000101]} { error "touch failed" }
        if {[file mtime $root] != [clock scan 20001201T000101]} { error "touch failed" }
    
        touch -a -m -t 200112010001.01 $root
        if {[file atime $root] != [clock scan 20011201T000101]} { error "touch failed" }
        if {[file mtime $root] != [clock scan 20011201T000101]} { error "touch failed" }
    
        touch -r ~ $root
        if {[file atime $root] != [file atime ~]} { error "touch failed" }
        if {[file mtime $root] != [file mtime ~]} { error "touch failed" }
    } finally {
        file delete -force $root
    }
}

proc test_ln {} {
    set root "/tmp/macports-portutil-ln"
    file delete -force $root
    
    file mkdir $root
    try {
        close [open $root/a w]
        ln -s a $root/b
        if {[catch {file type $root/b}] || [file type $root/b] ne "link"} {
            set message "ln failed: "
            if {[catch {file type $root/b}]} {
                append message "symlink not created"
            } elseif {[file type $root/b] ne "link"} {
                append message "created [file type $root/b], expected link"
            }
            error $message
        }
    
        close [open $root/c w]
        if {![catch {ln -s c $root/b}]} { error "ln failed" }
    
        ln -s -f c $root/b
        if {[catch {file type $root/b}] || [file type $root/b] ne "link"} { error "ln failed" }
    
        file delete $root/b
    
        ln $root/a $root/b
        if {[catch {file type $root/b}] || [file type $root/b] ne "file"} { error "ln failed" }
    
        file delete $root/b
        file mkdir $root/dir
        ln -s dir $root/b
        ln -s a $root/b
        if {[catch {file type $root/dir/a}] || [file type $root/dir/a] ne "link"} { error "ln failed" }
        file delete $root/dir/a
    
        ln -s -f -h a $root/b
        if {[catch {file type $root/b}] || [file type $root/b] ne "link" || [file readlink $root/b] ne "a"} { error "ln failed" }
    
        cd $root/dir
        ln -s ../c
        if {[catch {file type $root/dir/c}] || [file type $root/dir/c] ne "link"} { error "ln failed" }
    
        ln -s foobar $root/d
        if {[catch {file type $root/d}] || [file type $root/d] ne "link" || [file readlink $root/d] ne "foobar"} { error "ln failed" }
        
        ln -s -f -h z $root/dir
        if {[catch {file type $root/dir/z}] || [file type $root/dir/z] ne "link"} { error "ln failed" }
        
        # test combined flags
        ln -sf q $root/dir
        if {[catch {file type $root/dir/q}] || [file type $root/dir/q] ne "link"} { error "ln failed" }
    } finally {
        file delete -force $root
    }
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
