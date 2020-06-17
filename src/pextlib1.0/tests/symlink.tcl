# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# Test file for Pextlib's symlink.
# Requires r/w access to /tmp/
# Syntax:
# tclsh symlink.tcl <Pextlib name>

proc main {pextlibname} {
    load $pextlibname

    set root "/tmp/macports-pextlib-symlink"

    file delete -force $root

    file mkdir $root

    symlink foobar $root/test

    if {[catch {file type $root/test}] || [file type $root/test] ne "link" || [file readlink $root/test] ne "foobar"} {
        set message "symlink failed: "
        if {[catch {file type $root/test}]} {
            append message "symlink not created"
        } elseif {[file type $root/test] ne "link"} {
            append message "created [file type $root/test], not link"
        } else {
            append message "link to `[file readlink $root/test]', expected `foobar'"
        }
        file delete -force $root
        error $message
    }

    if {![catch {symlink barfoo $root/test}]} {
        file delete -force $root
        error "symlink did not raise error when file already exists"
    }

    file delete -force $root
}

main $argv
