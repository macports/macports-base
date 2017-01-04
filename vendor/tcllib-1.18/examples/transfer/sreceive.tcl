#!/usr/bin/env tclsh
## -*- tcl -*-
# syntax: receive FILE
# Run this before transmit, will wait for connection.

set selfdir [file dirname [info script]]
# Enable the commands below to run from a tcllib checkout
#source $selfdir/../../modules/transfer/ddest.tcl
#source $selfdir/../../modules/transfer/connect.tcl
#source $selfdir/../../modules/transfer/receiver.tcl

package require transfer::receiver
package require tls

set file [lindex $argv 0]

proc OK {f args} {
    puts "\nDone ($args) $f"
    exit
}

proc PR {f args} {
    puts "Progress ($args) $f"
    return
}

set    type receiver
source $selfdir/tlssetup.tcl

transfer::receiver stream file $file {} 6789 \
    -command  [list OK $file] \
    -progress [list PR $file] \
    -socketcmd tls::socket

vwait forever
exit
