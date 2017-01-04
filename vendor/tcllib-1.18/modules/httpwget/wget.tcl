###
# Tool to download file from the web
# Enhacements to http
###
package provide http::wget 0.1
package require http

::namespace eval ::http {}

###
# topic: 1ed971e03ae89415e2f25d20e59b765c
# description: this proc contributed by Donal Fellows
###
proc ::http::_followRedirects {url args} {
    while 1 {
        set token [geturl $url -validate 1]
        set ncode [ncode $token]
        if { $ncode eq "404" } {
          error "URL Not found"
        }
        switch -glob $ncode {
            30[1237] {### redirect - see below ###}
            default  {cleanup $token ; return $url}
        }
        upvar #0 $token state
        array set meta [set ${token}(meta)]
        cleanup $token
        if {![info exists meta(Location)]} {
           return $url
        }
        set url $meta(Location)
        unset meta
    }
    return $url
}

###
# topic: fced7bc395596569ac225a719c686dcc
###
proc ::http::wget {url destfile {verbose 1}} {
    set tmpchan [open $destfile w]
    fconfigure $tmpchan -translation binary
    if { $verbose } {
        puts [list  GETTING [file tail $destfile] from $url]
    }
    set real_url [_followRedirects $url]
    set token [geturl $real_url -channel $tmpchan -binary yes]
    if {[ncode $token] != "200"} {
      error "DOWNLOAD FAILED"
    }
    cleanup $token
    close $tmpchan
}

