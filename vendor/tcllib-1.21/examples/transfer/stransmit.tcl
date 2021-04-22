#!/usr/bin/env tclsh
## -*- tcl -*-
# syntax: transmit FILE ?HOST?
# Run this after receive, it waits for our connection.

set selfdir [file dirname [info script]]
# Enable the commands below to run from a tcllib checkout
#source $selfdir/../../modules/transfer/copyops.tcl
#source $selfdir/../../modules/transfer/dsource.tcl
#source $selfdir/../../modules/transfer/connect.tcl
#source $selfdir/../../modules/transfer/transmitter.tcl

package require transfer::transmitter
package require tls

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

set    type transmitter
source $selfdir/tlssetup.tcl

transfer::transmitter stream file $file $host 6789 \
    -command  [list OK $file] \
    -progress [list PR $file] \
    -socketcmd tls::socket

vwait forever
exit
