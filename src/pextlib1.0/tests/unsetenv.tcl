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
}

main $argv
