# -*- tcl -*-

set kc {}

foreach line [split [read stdin] \n] {
    if {$line eq {}} continue    
    lassign $line key code
    dict set kc $key $code
}

foreach k [lsort -dict [dict keys $kc]] {
    puts [list $k [dict get $kc $k]]
}

exit
