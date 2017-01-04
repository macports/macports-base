#!/usr/bin/env tclsh
## -*- tcl -*-

package require comm
package require tie

set id [lindex $argv 0]

array set sender {}
tie::tie  sender remotearray \
	server {comm::comm send} $id

proc ExecChanges {list} {
    if {![llength $list]} exit

    uplevel #0 [lindex $list 0]
    after 100 [list ExecChanges [lrange $list 1 end]]
}

after 2000 {ExecChanges {
    {set sender(a) 0}
    {set sender(a) 1}
    {set sender(b) .}
    {unset sender(a)}
    {array set sender {xa @ xb *}}
    {array unset sender x*}}}

vwait forever
