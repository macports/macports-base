if {$::tcl_platform(platform) eq "windows" && ![catch {package require twapi}]} {
# TWAPI Based implementation

::namespace eval ::nettool {}

###
# topic: 825cd25953c2cc896a96006b7f454e00
# title: Return pairings of MAC numbers to IP addresses on the local network
# description: Under macosx, we call the arp command for arp table resolution
###
proc ::nettool::arp_table {} {
  set result {}
  catch {
  foreach element [::twapi::get_arp_table] {
    foreach {ifidx macid ipaddr type} {
      lappend result [string map {- :} $macid] $ipaddr
    }
  }
  }
  return $result
}


###
# topic: 57fdc331bc60c7bf2bd3f3214e9a906f
###
proc ::nettool::hwaddr_to_ipaddr args {
  return [::twapi::hwaddr_to_ipaddr {*}$args]
}



if {[info command ::twapi::get_netif_indices] ne {}} {
###
# topic: 4b87d977492bd10802bfc0327cd07ac2
# title: Return list of network interfaces
###
proc ::nettool::if_list {} {
  return [::twapi::get_netif_indices]
}


###
# topic: ac9d6815d47f60d45930f0c8c8ae8f16
# title: Return list of mac numbers for this computer (primary first)
###
proc ::nettool::mac_list {} {
  set result {}
  foreach iface [::twapi::get_netif_indices] {
    foreach {field value} [::twapi::get_netif_info $iface -physicaladdress] {
      if { $value eq {} } continue
      lappend result [string map {- :} $value]
    }
  }
  return $result
}

###
# topic: a43b6f42141820e0ba1094840d0f6fc0
###
proc ::nettool::network_list {} {
  set result {}
  foreach iface [::twapi::get_netif_indices] {
    set dat [::twapi::GetIpAddrTable $iface]
    foreach element $dat {
      foreach {addr ifindx netmask broadcast reamsize} $element break;
      set mask [::ip::maskToInt $netmask]
      set addri [::ip::toInteger $addr]
      lappend result [ip::nativeToPrefix [list [expr {$addri & $mask}] $netmask] -ipv4]
    }
  }
  return [lsort -unique $result]
}
} else {

if {[info commands ::twapi::get_network_adapters] ne {}} {
proc ::nettool::if_list {} {
  return [::twapi::get_network_adapters]
}
}

if {[info commands ::twapi::get_network_adapter_info] ne {}} {
proc ::nettool::mac_list {} {

  set result {}
  foreach iface [if_list] {
    set dat [::twapi::get_network_adapter_info $iface -physicaladdress]
    set addr [string map {- :} [lindex $dat 1]]
    if {[string length $addr] eq 0} continue
    if {[string range $addr 0 5] eq "00:00:"} continue
    lappend result $addr
  }
  return $result
}

proc ::nettool::network_list {} {
  set result {}
  foreach iface [if_list] {
    set dat [::twapi::get_network_adapter_info $iface -prefixes]
    foreach kvlist [lindex $dat 1] {
      if {![dict exists $kvlist -address]} continue
      if {![dict exists $kvlist -prefixlength]} continue
      set length [dict get $kvlist -prefixlength]
      if {$length>31} continue
      set address [dict get $kvlist -address]
      if {[string range $address 0 1] eq "ff"} continue
      lappend result $address/$length
    }
  }
  return [lsort -unique $result]
}

}
}

###
# topic: 417672d3f31b80d749588365af88baf6
# title: Return list of ip addresses for this computer (primary first)
###
set body {}
if {[info commands ::twapi::get_ip_addresses] ne {}} {
proc ::nettool::ip_list {} {
  set result [::twapi::get_ip_addresses]
  ldelete result 127.0.0.1
  return $result
}
} elseif {[info commands ::twapi::get_system_ipaddrs] ne {}} {
# They changed commands names on me...
if {[catch {::twapi::get_system_ipaddrs -version 4}]} {
# THEY CHANGED THE API ON ME!
proc ::nettool::ip_list {} {
  set result [::twapi::get_system_ipaddrs -ipversion 4]
  ldelete result 127.0.0.1
  return $result
}
} else {
proc ::nettool::ip_list {} {
  set result [::twapi::get_system_ipaddrs -version 4]
  ldelete result 127.0.0.1
  return $result
}
}
}


proc ::nettool::status {} {
  set result {}
  #dict set result load [::twapi::]
  set cpus [::twapi::get_processor_count]
  set usage 0
  for {set p 0} {$p < $cpus} {incr p} {
    if [catch {
    set pu  [lindex [::twapi::get_processor_info $p  -processorutilization] 1]
    while {$pu eq {}} {
      after 100 {set pause 0}
      vwait pause
      set pu  [lindex [::twapi::get_processor_info $p  -processorutilization] 1]
    }
    set usage [expr {$usage+$pu}]
    } err] {
      set usage -1
    }
  }
  dict set result cpus $cpus
  dict set result load [expr {$usage/$cpus}]
  dict set result uptime [::twapi::get_system_uptime]
}
}
