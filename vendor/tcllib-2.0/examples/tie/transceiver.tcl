#!/usr/bin/env tclsh
## -*- tcl -*-

package require comm
package require tie

set id [lindex $argv 0]

array set local {}

proc export {localvar remotevar remoteid} {
    uplevel #0 [list tie::tie $localvar remotearray $remotevar {comm::comm send} $remoteid]
    return
}

proc import {remotevar remoteid localvar} {
    comm::comm send $remoteid [list \
	    tie::tie $remotevar remotearray \
	    $localvar {comm::comm send} [comm::comm self] \
	 ]
}

proc ExecChanges {list} {
    if {![llength $list]} return

    uplevel #0 [lindex $list 0]
    after 100 [list ExecChanges [lrange $list 1 end]]
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

export local server $id
import server $id local

trace add variable local {write unset} Track


comm::comm send $id {
    proc ExecChanges {list} {
	puts ($list)
	if {![llength $list]} return
	uplevel #0 [lindex $list 0]
	after 100 [list ExecChanges [lrange $list 1 end]]
    }
}

set changes {
    {set local(a) 0}
    {set local(a) 1}
    {set local(b) .}
    {unset local(a)}
    {array set local {xa @ xb *}}
    {array unset local x*}
}
lappend changes \
	[list comm::comm send $id [list ExecChanges {
    {set server(ZZ) foo}
    {set server(XX) bar}
}]]

after 2000 [list ExecChanges $changes]

vwait forever
