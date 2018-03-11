::namespace eval ::nettool {}

###
# topic: fc6f8b9587dd5524f143f9df4be4755b63eb6cd5
###
proc ::nettool::allocate_port startingport {
  foreach {start end} $::nettool::blocks {
    if { $end <= $startingport } continue
    if { $start > $startingport } {
      set i $start
    } else {
      set i $startingport
    }
    for {} {$i <= $end} {incr i} {
      if {[string is true -strict [get ::nettool::used_ports($i)]]} continue
      if {[catch {socket -server NOOP $i} chan]} continue
      close $chan
      set ::nettool::used_ports($i) 1
      return $i
    }
  }
  error "Could not locate a port"
}

###
# topic: 3286fdbd0a3fdebbb26414475754bcf3dea67b0f
###
proc ::nettool::claim_port {port {protocol tcp}} {
  set ::nettool::used_ports($port) 1
}

###
# topic: 1d1f8a65a9aef8765c9b4f2b0ee0ebaf42e99d46
###
proc ::nettool::find_port startingport {
  foreach {start end} $::nettool::blocks {
    if { $end <= $startingport } continue
    if { $start > $startingport } {
      set i $start
    } else {
      set i $startingport
    }
    for {} {$i <= $end} {incr i} {
      if {[string is true -strict [get ::nettool::used_ports($i)]]} continue
      return $i
    }
  }
  error "Could not locate a port"
}

###
# topic: ded1c51260e009effb1f77044f8d0dec3d030b91
###
proc ::nettool::port_busy port {
  ###
  # Check our private list of used ports
  ###
  if {[string is true -strict [get ::nettool::used_ports($port)]]} {
    return 1
  }
  foreach {start end} $::nettool::blocks {
    if { $port >= $start && $port <= $end } {
      return 0
    }
  }
  return 1
}

###
# topic: b5407b084aa09f9efa4f58a337af6186418fddf2
###
proc ::nettool::release_port {port {protocol tcp}} {
  set ::nettool::used_ports($port) 0
}

