# Test file for Pextlib's unsetenv.
# tclsh <Pextlib name>

proc main {pextlibname} {
    load $pextlibname
    
    global env
    puts [array get env]
    
    array unset env *
    puts [array get env]
    
    unsetenv *
    puts [array get env]


    set env(CC) "gcc"

    array unset env CC
    if {[info exists env(CC)]} {
        puts "note: your TclUnsetEnv is broken... (need to use unsetenv too)"
    }
    unsetenv CC
    if {[info exists env(CC)]} {
        exit 1
    }
}

main $argv
