###
# Generic answers that can be answered on most if not all unix platforms
###

::namespace eval ::nettool {}

###
# topic: 825cd25953c2cc896a96006b7f454e00
# title: Return pairings of MAC numbers to IP addresses on the local network
# description: Under unix, we call the arp command for arp table resolution
###
proc ::nettool::arp_table {} {
  set result {}
  set dat [exec arp -a]
  foreach line [split $dat \n] {
    set host [lindex $line 0]
    set ip [lindex $line 1]
    set macid [lindex $line 3]
    lappend result $macid [string range $ip 1 end-1]
  }
  return $result
}

