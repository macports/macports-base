# tk-sample.tcl - Copyright (C) 2002 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# Derived from Neil Madden's browser sig :)
#
# Note that this doesn't work for sites using virtual hosting and is dubious for
# multi-homed sites too. This is only to illustrate the resolver usage. What we
# should be doing is connecting a socket to the resolved address and then requesting
# the original URL. Useless if there is a proxy between you as well.
#
# $Id: tk_sample.tcl,v 1.2 2004/01/15 06:36:12 andreas_kupries Exp $

package require Tkhtml
package require http
package require dns

set Sample(URL) http://mini.net/tcl/976.html
set Sample(nameserver) localhost

# Description:
#  Construct a simple web browser interface.
#
proc gui {} {
    frame .f -bd 0 -relief flat
    label .f.l1 -text "Nameserver" -underline 0
    entry .f.e1 -textvariable ::Sample(nameserver)
    label .f.l2 -text "URL" -underline 0
    entry .f.e2 -textvariable ::Sample(URL)
    button .f.b -text Go -underline 0 -command {get $::Sample(URL)}
    button .f.x -text Exit -underline 1 -command {bye}
    
    scrollbar .v -orient v -command {.h yv}
    html .h -yscrollcommand {.v set}
    
    pack .f.l1 -side left -fill y
    pack .f.e1 -side left -fill both -expand 1
    pack .f.x -side right -fill y
    pack .f.b -side right -fill y
    pack .f.l2 -side left -fill y
    pack .f.e2 -side right -fill both -expand 1

    pack .f -side top -fill x
    pack .v -side right -fill y
    pack .h -fill both -expand 1
    
    bind .h.x <1> {eval get [.h href %x %y]}
}

proc bye {} {
    destroy .f .v .h
}

proc bgerror {args} {
}

# Description:
#  Rewrite the URL by looking up the domain name and replacing with the 
#  IP address.
#
proc resolve {url} {
    global Sample
    if {![catch {array set URL [uri::split $url]} msg]} {
        set tok [dns::resolve $URL(host) -server $Sample(nameserver)]
        if {[dns::status $tok] == "ok"} {
            set URL(host) [dns::address $tok]
            set url [eval uri::join [array get URL]]
        }
        dns::cleanup $tok
    }
    log::log debug "resolved to $url"
    return $url
}

# Description:
#  Fetch an HTTP URL and display.
#
proc get {url} {
    global Sample
    set url [resolve $url]
    set Sample(URL) $url
    set tok [http::geturl $url -headers $::auth]
    .h clear
    .h parse [http::data $tok]
    http::cleanup $tok
    .h configure -base $url
}

gui
get $::Sample(URL)
