::namespace eval ::nettool {}

###
# topic: 825cd25953c2cc896a96006b7f454e00
# title: Return pairings of MAC numbers to IP addresses on the local network
# description: Under macosx, we call the arp command for arp table resolution
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

###
# topic: 92ebbfa155883ad41c37d3f843392be4
# title: Return list of broadcast addresses for local networks
###
proc ::nettool::broadcast_list {} {
  set result {}
  lappend result 127.0.0.1
  foreach {iface info} [dump] {
    if {[dict exists $info broadcast:]} {
      lappend result [dict get $info broadcast:]
    }
  }
  return [lsort -unique -dictionary $result]
}

###
# topic: 187cfa1827097c5cdf1c40c656cedfcc
# description: Return time since booted
###
proc ::nettool::cpuinfo args {
  variable cpuinfo
  if {![info exists cpuinfo]} {
    set cpuinfo {}
    dict set cpuinfo machine  [exec sysctl -n hw.machine]
    dict set cpuinfo cpus     [exec sysctl -n hw.ncpu]
    # Normalize to MB
    dict set cpuinfo memory   [expr {[exec sysctl -n hw.memsize] / 1048576}]
    
    dict set cpuinfo vendor   [exec sysctl -n machdep.cpu.vendor]
    dict set cpuinfo brand    [exec sysctl -n machdep.cpu.brand_string]
    
    dict set cpuinfo model    [exec sysctl -n machdep.cpu.model]
    dict set cpuinfo speed    [expr {[exec sysctl -n hw.cpufrequency]/1000000}]
    
    dict set cpuinfo family   [exec sysctl -n machdep.cpu.family]
    dict set cpuinfo stepping [exec sysctl -n machdep.cpu.stepping]
    dict set cpuinfo features [exec sysctl -n machdep.cpu.features]
    dict set cpuinfo diskless []
  }
  if {$args eq "<list>"} {
    return [dict keys $cpuinfo]
  }
  if {[llength $args]==0} {
    return $cpuinfo
  }
  if {[llength $args]==1} {
    return [dict get $cpuinfo [lindex $args 0]]
  }
  set result {}
  foreach item $args {
    if {[dict exists $cpuinfo $item]} {
      dict set result $item [dict get $cpuinfo $item]
    } else {
      dict set result $item {}
    }
  }
  return $result
}

###
# topic: aa8eda4fb59296a1a34d8d600ca54e28
# description: Dump interfaces
###
proc ::nettool::dump {} {
  set data [exec ifconfig]
  set iface {}
  set result {}
  foreach line [split $data \n] {
    if {[string index $line 0] in {" " "\t"} } {
      # Indented line appends the prior iface
      foreach {field value} $line {
        dict set result $iface [string trimright $field :]: $value
      }
    } else {
      # Non-intended line - new iface
      set iface [lindex $line 0]
    }
  }
  return $result
}

###
# topic: dd2e2c0810cea69909399808f2a68949
# title: Return a list of unique hardware addresses
###
proc ::nettool::hwid_list {} {
  variable cached_data
  set result {}
  if {![info exists cached_data]} {
    if {[catch {exec system_profiler SPHardwareDataType} hwlist]} {
      set cached_data {}
    } else {
      set cached_data $hwlist
      
    }
  }
  set serial {}
  set hwuuid {}
  set result {}
  catch {
  foreach line [split $cached_data \n] {
    if { [lindex $line 0] == "Serial" && [lindex $line 1] == "Number" } {
      set serial [lindex $line end]
    }
    if { [lindex $line 0] == "Hardware" && [lindex $line 1] == "UUID:" } {
      set hwuuid [lindex $line end]
    }
  }
  }
  if { $hwuuid != {} } {
    lappend result 0x[string map {- {}} $hwuuid]
  }
  # Blank serial number?
  if { $serial != {} } {
    set sn [binary scan $serial H* hash]
    lappend result 0x$hash
  }
  if {[llength $result]} {
    return $result
  }
  foreach mac [::nettool::mac_list] {
    lappend result 0x[string map {: {}} $mac]
  }
  if {[llength $result]} {
    return $result
  }
  return 0x010203040506
}

###
# topic: d2932eb0ea8cc9f6a865c1ab7cdd4572
# description:
#    Called on package load to build any static
#    structures to cache data that would be time
#    consuming to call on the fly
###
proc ::nettool::init {} {
  unset -nocomplain [namespace current]::cpuinfo
  
}

###
# topic: 417672d3f31b80d749588365af88baf6
# title: Return list of ip addresses for this computer (primary first)
###
proc ::nettool::ip_list {} {
  set result {}
  foreach {iface info} [dump] {
    if {[dict exists $info inet:]} {
      lappend result [dict get $info inet:]
    }
  }
  ldelete result 127.0.0.1
  return $result
}

###
# topic: ac9d6815d47f60d45930f0c8c8ae8f16
# title: Return list of mac numbers for this computer (primary first)
###
proc ::nettool::mac_list {} {
  set result {}
  foreach {iface info} [dump] {
    if {[dict exists $info ether:]} {
      lappend result [dict get $info ether:]
    }
  }
  return $result
}

###
# topic: a43b6f42141820e0ba1094840d0f6fc0
###
proc ::nettool::network_list {} {
  foreach {iface info} [dump] {
    if {![dict exists $info inet:]} continue
    if {![dict exists $info netmask:]} continue
    #set mask [::ip::maskToInt $netmask]
    set addr [dict get $info inet:]
    set mask [dict get $info netmask:]
    set addri [::ip::toInteger $addr]
    lappend result [ip::nativeToPrefix [list [expr {$addri & $mask}] $mask] -ipv4]    
  }
  return $result
}

###
# topic: e7db1ae1b5b98a1bb4384f0a4fe81f42
###
proc ::nettool::status {} {
  set result {}
  set loaddat [lindex [exec sysctl -n vm.loadavg] 0]
  set cpus [cpuinfo cpus]
  dict set result cpus $cpus
  dict set result load [expr {[lindex $loaddat 0]*100.0/$cpus}]
  dict set result load_average_1 [lindex $loaddat 0]
  dict set result load_average_5 [lindex $loaddat 1]
  dict set result load_average_15 [lindex $loaddat 2]

  set total [exec sysctl -n hw.memsize]
  dict set result memory_total [expr {$total / 1048576}]
  set used 0
  foreach {amt} [exec sysctl -n machdep.memmap] {
    incr used $amt
  }
  dict set result memory_free [expr {($total - $used) / 1048576}]

  return $result
}

proc ::nettool::user_data_root {appname} {
  return [file join $::env(HOME) Library {Application Support} $appname]
}
