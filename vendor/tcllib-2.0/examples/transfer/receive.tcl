#!/usr/bin/env tclsh
## -*- tcl -*-
# syntax: receive FILE
# Run this before transmit, will wait for connection.

package require transfer::receiver

set file [lindex $argv 0]

proc OK {f args} {
    puts "\nDone ($args) $f"
    exit
}

proc PR {f args} {
    puts "Progress ($args) $f"
    return
}

transfer::receiver stream file $file {} 6789 \
    -command  [list OK $file] \
    -progress [list PR $file]

vwait forever
exit
