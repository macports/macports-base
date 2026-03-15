#!/usr/bin/env tclsh
## -*- tcl -*-
# syntax: transmit FILE ?HOST?
# Run this after receive, it waits for our connection.

package require transfer::transmitter

set file [lindex $argv 0]
set host [lindex $argv 1]
if {$host eq {}} { set host localhost }

proc OK {f args} {
    puts "Done ($args) $f"
    exit
}

proc PR {f args} {
    puts "Progress ($args) $f"
    return
}

transfer::transmitter stream file $file $host 6789 \
    -command  [list OK $file] \
    -progress [list PR $file]
vwait forever
exit
