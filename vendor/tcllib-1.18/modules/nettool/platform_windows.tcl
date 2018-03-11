package require twapi

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
# topic: 92ebbfa155883ad41c37d3f843392be4
# title: Return list of broadcast addresses for local networks
###
proc ::nettool::broadcast_list {} {
  set result {}
  lappend result 127.0.0.1
  foreach iface [::twapi::get_netif_indices] {
    set dat [::twapi::GetIpAddrTable $iface]
    foreach element $dat {
      foreach {addr ifindx netmask broadcast reamsize} $element break;
      lappend result [::ip::broadcastAddress $addr/$netmask]
    }
  }
  return [lsort -unique -dictionary $result]
}

###
# topic: 57fdc331bc60c7bf2bd3f3214e9a906f
###
proc ::nettool::hwaddr_to_ipaddr args {
  return [::twapi::hwaddr_to_ipaddr {*}$args]
}

###
# topic: dd2e2c0810cea69909399808f2a68949
# title: Return a list of unique hardware ids
###
proc ::nettool::hwid_list {} {
  # Use the serial number on the hard drive
  catch {exec {*}[auto_execok vol] c:} voldat
  set num [lindex [lindex [split $voldat \n] end] end]
  return 0x[string map {- {}} $num]
}

###
# topic: 4b87d977492bd10802bfc0327cd07ac2
# title: Return list of network interfaces
###
proc ::nettool::if_list {} {
  return [::twapi::get_netif_indices]
}

###
# topic: 417672d3f31b80d749588365af88baf6
# title: Return list of ip addresses for this computer (primary first)
###
set body {}
if {[::twapi::get_ip_addresses] ne {}} {
  set body {
  set result [::twapi::get_ip_addresses]
  ldelete result 127.0.0.1
  return $result
} 
} elseif {[info commands ::twapi::get_system_ipaddrs] ne {}} {
# They changed commands names on me...
  set body {
  set result [::twapi::get_system_ipaddrs]
  ldelete result 127.0.0.1
  return $result
}
}
proc ::nettool::ip_list {} $body
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

proc ::nettool::status {} {
  set result {}
  #dict set result load [::twapi::]
  set cpus [::twapi::get_processor_count]
  set usage 0
  for {set p 0} {$p < $cpus} {incr p} {
    set pu  [lindex [::twapi::get_processor_info $p  -processorutilization] 1]
    set usage [expr {$usage+$pu}]
  }
  dict set result cpus $cpus
  dict set result load [expr {$usage/$cpus}]
  dict set result uptime [::twapi::get_system_uptime]
}

proc ::nettool::user_data_root {appname} {
  return [file join $::env(APPDATA) $appname]
}
package provide nettool::platform::windows 0.2
