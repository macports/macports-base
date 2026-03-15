#!/usr/bin/env tclsh
## -*- tcl -*-
# Array server ...

package require comm
package require tie

puts "Listening on [comm::comm self]"

proc Track {args} {
    global server
    puts *\ \[[join $args "\] \["]\]\ ([dictsort [array get server]])
    return
}

proc dictsort {dict} {
    array set a $dict
    set out [list]
    foreach key [lsort [array names a]] {
	lappend out $key $a($key)
    }
    return $out
}

array set          server {}
trace add variable server {write unset} Track

vwait forever
