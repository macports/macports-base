# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# Test file for Pextlib's unsetenv.
# tclsh <Pextlib name>

proc main {pextlibname} {
    load $pextlibname

    global env

    array unset env *
    if {[array size env] > 0} {
        puts "note: your TclUnsetEnv is broken... (need to use unsetenv too)"
    }
    unsetenv *
    if {[array size env] > 0} {
        error "env not empty as expected"
    }


    set env(CC) "gcc"

    array unset env CC
    if {[info exists env(CC)]} {
        puts "note: your TclUnsetEnv is broken... (need to use unsetenv too)"
    }
    unsetenv CC
    if {[info exists env(CC)]} {
        error "CC still set in env"
    }
}

main $argv
