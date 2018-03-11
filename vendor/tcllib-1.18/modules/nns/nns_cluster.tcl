# -*- tcl -*-
# ### ### ### ######### ######### #########
## Name Service - Cluster

# ### ### ### ######### ######### #########
## Requirements

package require Tcl 8.5
package require comm             ; # Generic message transport
package require interp           ; # Interpreter helpers.
package require logger           ; # Tracing internal activity
package require uuid
package require cron
package require nettool 0.4
package require udp

namespace eval ::comm {}
::namespace eval ::cluster {}

###
# This package implements an ad/hoc zero configuration
# like network of comm (and other) network connections
###

###
# topic: 5cffdc91e554c923ebe43df13fac77d5
###
proc ::cluster::broadcast {args} {
  if {$::cluster::config(debug)} {
    puts [list $::cluster::local_pid SEND $args]
  }
  while {[catch {
    set sock [listen]
    puts -nonewline $sock [list [pid] {*}$args]
    flush $sock
  } error]} {
    set ::cluster::broadcast_sock {}
    if {$::cluster::config(debug)} {
      puts "Broadcast ERR: $error - Reopening Socket"
      ::cluster::sleep 2000
    } else {
      # Double the delay
      ::cluster::sleep 250
    }
  }
}

###
# topic: 963e24601d0dc61580c9727a74cdba67
###
proc ::cluster::cname rawname {
  # Convert rawname to a canonical name
  if {[string first @ $rawname] < 0 } {
    return $rawname
  }
  lassign [split $rawname @] service host
  if {$host eq {}} {
    set host *
  }
  if {$host in {local localhost}} {
    set host [::cluster::self]
  }
  return $service@$host
}

###
# topic: 3f5f9e197cc9666dd7953d97fef34019
###
proc ::cluster::ipaddr macid {
  # Convert rawname to a canonical name
  if {$macid eq [::cluster::self]} {
    return 127.0.0.1
  }
  foreach {servname dat} [search [cname *@$macid]] {
    if {[dict exists $dat ipaddr]} {
      return [dict get $dat ipaddr]
    }
  }
  ###
  # Do a lookup
  ###
  error "Could not locate $macid"
}

###
# topic: e57db306f0e931d7febb5ad1f9cb2247
###
proc ::cluster::listen {} {
  variable broadcast_sock
  if {$broadcast_sock != {}} {
    return $broadcast_sock
  }
  variable discovery_port
  variable discovery_group
  set broadcast_sock [udp_open $discovery_port reuse]
  fconfigure $broadcast_sock -buffering none -blocking 0 \
    -mcastadd $discovery_group \
    -remote [list $discovery_group $discovery_port]
  fileevent $broadcast_sock readable [list [namespace current]::UDPPacket $broadcast_sock]
  ::cron::every cluster_heartbeat 30 ::cluster::heartbeat
  
  return $broadcast_sock
}

###
# topic: 2a33c825920162b0791e2cdae62e6164
###
proc ::cluster::UDPPacket sock {
  variable ptpdata
  set pid [pid]
  set packet [string trim [read $sock]]
  set peer [fconfigure $sock -peer]

  if {![string is ascii $packet]} return
  if {![::info complete $packet]} return

  set sender  [lindex $packet 0]
  if {$::cluster::config(debug)} {
    puts [list $::cluster::local_pid RECV $peer $packet]
  }
  if { $sender eq [pid] } {
    # Ignore messages from myself
    return
  }
  
  set messagetype [lindex $packet 1]
  set messageinfo [lrange $packet 2 end]
  switch -- [string toupper $messagetype] {
    -SERVICE {
      set serviceurl [lindex $messageinfo 0]
      set serviceinfo [lindex $messageinfo 1]
      dict set serviceinfo ipaddr [lindex $peer 0]
      dict set serviceinfo closed 1
      Service_Remove $serviceurl $serviceinfo
    }
    ~SERVICE {
      set ::cluster::recv_message 1
      set serviceurl [lindex $messageinfo 0]
      set serviceinfo [lindex $messageinfo 1]
      dict set serviceinfo ipaddr [lindex $peer 0]
      Service_Modified $serviceurl $serviceinfo
      set ::cluster::ping_recv($serviceurl) [clock seconds]
    }
    +SERVICE {
      set ::cluster::recv_message 1
      set serviceurl [lindex $messageinfo 0]
      set serviceinfo [lindex $messageinfo 1]
      dict set serviceinfo ipaddr [lindex $peer 0]
      Service_Add $serviceurl $serviceinfo
      set ::cluster::ping_recv($serviceurl) [clock seconds]
    }
    DISCOVERY {
      variable config
      ::cluster::heartbeat
      if {$config(local_registry)==1} {
        variable ptpdata
        # A local registry barfs back all data that is sees
        set now [clock seconds]
        foreach {url info} [array get ptpdata] {
          broadcast ~SERVICE $url $info 
        }
      }
    }
    LOG {
      set serviceurl [lindex $messageinfo 0]
      set serviceinfo [lindex $messageinfo 1]
      Service_Log $serviceurl $serviceinfo
    }
    ?WHOIS {
      set wmacid [lindex $messageinfo 0]
      if { $wmacid eq [::cluster::self] } {
        broadcast +WHOIS [::cluster::self]
      }
    }
    PONG {
      set serviceurl [lindex $messageinfo 0]
      set serviceinfo [lindex $messageinfo 1]
      Service_Modified $serviceurl $serviceinfo
      set ::cluster::ping_recv($serviceurl) [clock seconds]
    }
    PING {
      set serviceurl [lindex $messageinfo 0]
      foreach {url info} [search_local $serviceurl] {
        broadcast PONG $url $info
      }
    }
  }
}

proc ::cluster::ping {rawname} {
  set rcpt [cname $rawname]
  set ::cluster::ping_recv($rcpt) 0
  set starttime [clock seconds]
  set sleeptime 1
  while 1 {
    broadcast PING $rcpt
    update
    if {$::cluster::ping_recv($rcpt)} break
    if {([clock seconds] - $starttime) > 120} {
      error "Could not locate a local dispatch service"
    }
    sleep [incr sleeptime $sleeptime]
  }
}

proc ::cluster::publish {url infodict} {
  variable local_data
  dict set infodict macid [self]
  dict set infodict pid [pid]
  set local_data($url) $infodict
  broadcast +SERVICE $url $infodict
}

proc ::cluster::heartbeat {} {
  variable ptpdata
  variable config
  
  set now [clock seconds]
  foreach {item info} [array get ptpdata] {
    set remove 0
    if {[dict exists $info closed] && [dict get $info closed]} {
      set remove 1
    }
    if {[dict exists $info updated] && ($now - [dict get $info updated])>$config(discovery_ttl)} {
      set remove 1
    }
    if {$remove} {
      Service_Remove $item $info
    }
  }
  ###
  # Broadcast the status of our local services
  ###
  variable local_data
  foreach {url info} [array get local_data] {
    broadcast ~SERVICE $url $info
  }
  ###
  # Trigger any cluster events that haven't fired off
  ###
  foreach {eventid info} [array get ::cluster::events] {
    if {$info eq "-1"} {
      unset ::cluster::events($eventid)
    } else {
      lassign $info seconds ms
      if {$seconds < $now} {
        set ::cluster::events($eventid) -1
      }
    }
  }
}

proc ::cluster::info url {
  variable local_data
  return [array get local_data $url]
}

proc ::cluster::unpublish {url infodict} {
  variable local_data
  foreach {field value} $infodict {
    dict set local_data($url) $field $value
  }
  set info [lindex [array get local_data $url] 1]
  broadcast -SERVICE $url $info
  unset -nocomplain local_data($url)
}

proc ::cluster::configure {url infodict {send 1}} {
  variable local_data
  if {![::info exists local_data($url)]} return
  foreach {field value} $infodict {
    dict set local_data($url) $field $value
  }
  if {$send} {
    broadcast ~SERVICE $url $local_data($url)
    update
  }
}

proc ::cluster::get_free_port {{startport 50000}} {
  ::cluster::listen
  ::cluster::broadcast DISCOVERY
  after 10000 {set ::cluster::recv_message 0}
  # Wait for a pingback or timeout
  vwait ::cluster::recv_message
  cluster::sleep 2000
  
  set macid [::cluster::macid]
  set port $startport
  set conflict 1
  while {$conflict} {
    set conflict 0
    set port [::nettool::find_port $port]
    foreach {url info} [search *@[macid]] {
      if {[dict exists $info port] && [dict get $info port] eq $port} {
        incr port
        set conflict 1
        break
      }
    }
    update
  }
  return $port
}

proc ::cluster::log args {
  broadcast LOG {*}$args
}

proc ::cluster::LookUp {rawname} {
  set self [self]
  foreach {servname dat} [search [cname $rawname]] {
    # Ignore services in the process of closing
    if {[dict exists $dat macid] && [dict get $dat macid] eq $self} {
      set ipaddr 127.0.0.1
    } elseif {![dict exists $dat ipaddr]} {
      set ipaddr [ipaddr [lindex [split $servname @] 1]]
    } else {
      set ipaddr [dict get $dat ipaddr]
    }
    if {![dict exists $dat port]} continue
    if {[llength $ipaddr] > 1} {
      ## Sort out which ipaddr is proper later
      # for now take the last one
      set ipaddr [lindex [dict get $dat ipaddr] end]
    }
    set port [dict get $dat port]
    return [list $port $ipaddr]
  }
  return {}
}

###
# topic: 2c04e58c7f93798f9a5ed31a7f5779ab
###
proc ::cluster::resolve {rawname} {
  set result [LookUp $rawname]
  if { $result ne {} } {
    return $result
  }
  broadcast DISCOVERY
  sleep 250
  set result [LookUp $rawname]
  if { $result ne {} } {
    return $result
  }
  error "Could not locate $rawname"
}

###
# topic: 6c7a0a3a8cb2a7ae98ff0dba960c37a7
###
proc ::cluster::pid {} {
  variable local_pid
  return $local_pid
}

proc ::cluster::macid {} {
  variable local_macid
  return $local_macid
}

proc ::cluster::self {} {
  variable local_macid
  return $local_macid
}

###
# topic: f1b71ff12a8ac10373c67ac5d973cd81
###
proc ::cluster::send {service command args} {
  set commid [resolve $service]
  return [::comm::comm send $commid $command {*}$args]
}

proc ::cluster::throw {service command args} {
  set commid [LookUp $service]
  if { $commid eq {} } {
    return
  }
  if [catch {::comm::comm send -async $commid $command {*}$args} reply] {
    puts $stderr "ERR: SEND $service $reply"
  }
}

proc ::cluster::sleep ms {
  set eventid [incr ::cluster::eventcount]
  set ::cluster::event($eventid) [list [clock seconds] [expr {[clock milliseconds]+$ms}]]
  after $ms set ::cluster::event($eventid) -1
  vwait ::cluster::event($eventid)
}

###
# topic: c8475e832c912e962f238c61580b669e
###
proc ::cluster::search pattern {
  set result {}  
  variable ptpdata
  foreach {service dat} [array get ptpdata $pattern] {
    foreach {field value} $dat {
      dict set result $service $field $value
    }
  }
  variable local_data
  foreach {service dat} [array get local_data $pattern] {
    foreach {field value} $dat {
      dict set result $service $field $value
      dict set result $service ipaddr 127.0.0.1
    }
  }
  return $result
}

proc ::cluster::is_local pattern {
  variable local_data
  if {[array exists local_data $pattern]} {
    return 1
  }
  if {[array exists local_data [cname $pattern]]} {
    return 1
  }
  return 0
}

proc ::cluster::search_local pattern {
  set result {}  
  variable local_data
  foreach {service dat} [array get local_data $pattern] {
    foreach {field value} $dat {
      dict set result $service $field $value
    }
  }
  return $result
}

proc ::cluster::Service_Add {serviceurl serviceinfo} {
  # Code to register the presence of a service
  if {[dict exists $serviceinfo pid] && [dict get $serviceinfo pid] eq [pid] } {
    # Ignore attempts to overwrite locally managed services from the network
    return
  }
  variable ptpdata
  set ptpdata($serviceurl) $serviceinfo
  dict set ptpdata($serviceurl) updated [clock seconds]
}

proc ::cluster::Service_Remove {serviceurl serviceinfo} {
  # Code to register the loss of a service
  if {[dict exists $serviceinfo pid] && [dict get $serviceinfo pid] eq [pid] } {
    # Ignore attempts to overwrite locally managed services from the network
    return
  }
  variable ptpdata
  unset -nocomplain ptpdata($serviceurl)
}

proc ::cluster::Service_Modified {serviceurl serviceinfo} {
  # Code to register an update to a service
  if {[dict exists $serviceinfo pid] && [dict get $serviceinfo pid] eq [pid] } {
    # Ignore attempts to overwrite locally managed services from the network
    return
  }
  variable ptpdata
  foreach {field value} $serviceinfo {
    dict set ptpdata($serviceurl) $field $value
  }
  dict set ptpdata($serviceurl) updated [clock seconds]
}

proc ::cluster::Service_Log {service data} {
  # Code to register an event
}

###
# topic: d3e48e31cc4baf81395179f4097fee1b
###
namespace eval ::cluster {
  # Number of seconds to "remember" data
  variable config
  array set config {
    debug 0
    discovery_ttl 300
    local_registry 0
  }
  variable eventcount 0
  variable cache {}
  variable broadcast_sock {}
  variable cache_maxage 500
  variable discovery_port 38573
  # Currently an unassigned group in the
  # Local Network Control Block (224.0.0/24)
  # See: RFC3692 and http://www.iana.org
  variable discovery_group 224.0.0.200
  variable local_port {}
  variable local_macid [lindex [::nettool::mac_list] 0]
  variable local_pid   [::uuid::uuid generate]
}

package provide nameserv::cluster 0.2.3
