::namespace eval ::nettool {}

###
# topic: 92ebbfa155883ad41c37d3f843392be4
# title: Return list of broadcast addresses for local networks
###
proc ::nettool::broadcast_list {} {
  set result {}
  lappend result 127.0.0.1
  foreach {iface info} [dump] {
    if {[dict exists $info ipv4 Bcast:]} {
      lappend result [dict get $info ipv4 Bcast:]
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
    set dat [cat /proc/meminfo]
    foreach line [split $dat \n] {
      switch [lindex $line 0] {
        MemTotal: {
          # Normalize to MB
          dict set cpuinfo memory [lindex $line 1]/1024
        }
      }
    }
    set cpus 0
    set dat [cat /proc/cpuinfo]
    foreach line [split $dat \n] {
      set idx [string first : $line]
      set field [string trim [string range $line 0 $idx-1]]
      set value [string trim [string range $line $idx+1 end]]
      switch $field {
        processor {
          incr cpus
        }
        {cpu family} {
          dict set cpuinfo family $value
        }
        model {
          dict set cpuinfo model $value
        }
        stepping {
          dict set cpuinfo stepping $value
        }
        vendor_id {
          dict set cpuinfo vendor $value          
        }
        {model name} {
          dict set cpuinfo brand $value                    
        }
        {cpu MHz} {
          dict set cpuinfo speed $value          
        }
        flags {
          dict set cpuinfo features $value
        }
      }
    }
    dict set cpuinfo cpus $cpus
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
      switch [lindex $line 0] {
        inet {
          foreach tuple [lrange $line 1 end] {
	    set idx [string first : $tuple]
            set field [string trim [string range $tuple 0 $idx]]
            set value [string trim [string range $tuple $idx+1 end]]
            dict set result $iface ipv4 [string trim $field] [string trim $value]
          }
        }
        inet6 {
          dict set result $iface ipv6 addr: [lindex $line 2]
          foreach tuple [lrange $line 3 end] {
	    set idx [string first : $tuple]
            set field [string trim [string range $tuple 0 $idx]]
            set value [string trim [string range $tuple $idx+1 end]]
            dict set result $iface ipv6 [string trim $field] [string trim $value]
          }
	}
      }
    } else {
      # Non-intended line - new iface
      set iface [lindex $line 0]
      set idx [lsearch $line HWaddr]
      if {$idx >= 0 } {
        dict set result $iface ether: [lindex $line $idx+1]
      }
    }
  }
  return $result
}

###
# topic: 417672d3f31b80d749588365af88baf6
# title: Return list of ip addresses for this computer (primary first)
###
proc ::nettool::ip_list {} {
  set result {}
  foreach {iface info} [dump] {
    if {[dict exists $info ipv4 addr:]} {
      lappend result [dict get $info ipv4 addr:]
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
    if {![dict exists $info ipv4 addr:]} continue
    if {![dict exists $info ipv4 Mask:]} continue
    #set mask [::ip::maskToInt $netmask]
    set addr [dict get $info ipv4 addr:]
    set mask [dict get $info ipv4 Mask:]
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
  set dat [cat /proc/loadavg]
  dict set result load_average    [lrange $dat 0 2]
  set cpus [cpuinfo cpus].0
  dict set result load [expr {[lindex $dat 0]/$cpus}]
  
  set processes [split [lindex $dat 3] /]
  dict set result processes_running [lindex $processes 0]
  dict set result processes_total [lindex $processes 1]

  set dat [cat /proc/meminfo]
  foreach line [split $dat \n] {
    switch [lindex $line 0] {
      MemTotal: {
        # Normalize to MB
        dict set result memory_total [expr {[lindex $line 1]/1024}]
      }
      MemFree: {
        # Normalize to MB
        dict set result memory_free [expr {[lindex $line 1]/1024}]
      }
    }
  }
  return $result
}

###
# topic: 59bf977ad7287b4d90346fad639aed34
###
proc ::nettool::uptime_report {} {
  set result {}
  set dat [split [exec uptime] ,]
  puts $dat
  dict set result time   [lindex [lindex $dat 0] 0]
  dict set result uptime [lrange [lindex $dat 0] 1 end]
  dict set result users  [lindex [lindex $dat 2] 0]
  dict set result load_1_minute  [lindex [lindex $dat 3] end]
  dict set result load_5_minute  [lindex [lindex $dat 4] end]
  dict set result load_15_minute  [lindex [lindex $dat 5] end]
  return $result
}

unset -nocomplain ::nettool::cpuinfo

