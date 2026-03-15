if {$::tcl_platform(platform) eq "windows"} {

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
# topic: 92ebbfa155883ad41c37d3f843392be4
# title: Return list of broadcast addresses for local networks
###
proc ::nettool::broadcast_list {} {
  set result {}
  lappend result 127.0.0.1
  foreach net [network_list] {
    if {$net in {224.0.0.0/4 127.0.0.0/8}} continue
    lappend result [::ip::broadcastAddress $net]
  }
  return [lsort -unique -dictionary $result]
}

###
# Provide a limited subset using data gleaned from exec
# These calls work in Windows NT 4 and above
###


proc ::nettool::IPINFO {} {
  if {![info exists ::nettool::ipinfo]} {
    set ::nettool::ipinfo [exec ipconfig /all]
  }
  return $::nettool::ipinfo
}

proc ::nettool::if_list {} {
  return [mac_list]
}

proc ::nettool::ip_list {} {
  set result {}
  foreach line [split [IPINFO] \n] {
    if {![regexp {IPv4 Address} $line]} continue
    set line [string range $line [string first ":" $line]+2 end]
    if {[scan $line %d.%d.%d.%d A B C D]!=4} continue
    lappend result $A.$B.$C.$D
  }
  return $result
}

proc ::nettool::mac_list {} {
  set result {}
  foreach line [split [IPINFO] \n] {
    if {![regexp {Physical Address} $line]} continue
    set line [string range $line [string first ":" $line]+2 end]
    if {[scan $line %02x-%02x-%02x-%02x-%02x-%02x A B C D E F] != 6} continue
    if {$A==0 && $B==0 && $C==0 && $D==0 && $E==0 && $F==0} continue
    lappend result [format %02x:%02x:%02x:%02x:%02x:%02x $A $B $C $D $E $F]
  }
  return $result
}

proc ::nettool::network_list {} {
  set masks {}
  foreach line [split [IPINFO] \n] {
    if {![regexp {Subnet Mask} $line]} continue
    set line [string range $line [string first ":" $line]+2 end]
    if {[scan $line %d.%d.%d.%d A B C D]!=4} continue
    lappend masks $A.$B.$C.$D
  }
  set result {}
  set idx -1
  foreach addr [ip_list] {
    set netmask [lindex $masks [incr idx]]
    set mask   [::ip::maskToInt $netmask]
    set addri [::ip::toInteger $addr]
    lappend result [ip::nativeToPrefix [list [expr {$addri & $mask}] $netmask] -ipv4]
  }
  return $result
}

proc ::nettool::status {} {
}

proc ::nettool::user_data_root {appname} {
  return [file join $::env(APPDATA) $appname]
}
}
