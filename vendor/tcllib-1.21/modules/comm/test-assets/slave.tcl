# -*- tcl -*-
catch {wm withdraw .}
##puts [set fh [open ~/foo w]] $argv ; close $fh

source [lindex $argv 0] ; # load 'snit'
source [lindex $argv 1] ; # load 'comm'
# and wait for commands. But first send our
# own server socket to the initiator
::comm::comm send [lindex $argv 2] [list slaveat [::comm::comm self]]
vwait forever
