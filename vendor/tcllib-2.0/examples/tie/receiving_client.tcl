#!/usr/bin/env tclsh
## -*- tcl -*-

package require comm
package require tie

set id [lindex $argv 0]

proc import {remotevar localvar} {
    global id
    comm::comm send $id [list \
	    tie::tie $remotevar remotearray \
	    $localvar {comm::comm send} [comm::comm self] \
	 ]
}

proc Track {args} {
    global receiver
    puts *\ \[[join $args "\] \["]\]\ ([dictsort [array get receiver]])
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

array set          receiver {}
trace add variable receiver {write unset} Track

import server receiver

puts "Waiting on $id"
vwait forever
