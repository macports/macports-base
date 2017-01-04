::namespace eval ::nettool {}

###
# topic: 825cd25953c2cc896a96006b7f454e00
# title: Return pairings of MAC numbers to IP addresses on the local network
###
proc ::nettool::arp_table {} {}

###
# topic: 92ebbfa155883ad41c37d3f843392be4
# title: Return list of broadcast addresses for local networks
###
proc ::nettool::broadcast_list {} {
  return 127.0.0.1
}

###
# topic: 15d9bc96ec6ce31d4c8f99a425a9c02c
# description: Return Processor utilization
###
proc ::nettool::busy {} {}

###
# topic: 187cfa1827097c5cdf1c40c656cedfcc
# description: Return time since booted
###
proc ::nettool::cpuinfo {} {}

###
# topic: 58295f2544f43827e855d09dc3ee625a
###
proc ::nettool::diskless_client {} {
  return 0
}

###
# topic: 57fdc331bc60c7bf2bd3f3214e9a906f
###
proc ::nettool::hwaddr_to_ipaddr {hwaddr args} {}

###
# topic: dd2e2c0810cea69909399808f2a68949
# title: Return a list of unique hardware ids
###
proc ::nettool::hwid_list {} {
  set result {}
  foreach mac [::nettool::mac_list] {
    lappend result 0x[string map {: {}} $mac]
  }
  if {[llength $result]} {
    return $result
  }
  return 0x010203040506
}

###
# topic: 4b87d977492bd10802bfc0327cd07ac2
# title: Return list of network interfaces
###
proc ::nettool::if_list {} {}

###
# topic: d2932eb0ea8cc9f6a865c1ab7cdd4572
# description:
#    Called on package load to build any static
#    structures to cache data that would be time
#    consuming to call on the fly
###
proc ::nettool::init {} {}

###
# topic: 417672d3f31b80d749588365af88baf6
# title: Return list of ip addresses for this computer (primary first)
###
proc ::nettool::ip_list {} {}

###
# topic: ac9d6815d47f60d45930f0c8c8ae8f16
# title: Return list of mac numbers for this computer (primary first)
###
proc ::nettool::mac_list {} {}

###
# topic: c42343f20e3afd2884a5dd1c219e4415
###
proc ::nettool::platform {} {
  variable platform
  return $platform
}

proc ::nettool::user_data_root {appname} {
  return [file join $::env(HOME) .$appname]
}

###
# Provide empty implementations
###

