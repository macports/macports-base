# urn-scheme.tcl - Copyright (C) 2001 Pat Thoyts <patthoyts@users.sf.net>
#
# extend the uri package to deal with URN (RFC 2141)
# see http://www.normos.org/ietf/rfc/rfc2141.txt
#
# Released under the tcllib license.
#
# $Id: urn-scheme.tcl,v 1.11 2005/09/28 04:51:24 andreas_kupries Exp $
# -------------------------------------------------------------------------

package require uri      1.1.2

namespace eval ::uri {}
namespace eval ::uri::urn {}

# -------------------------------------------------------------------------

# Description:
#   Called by uri::split with a url to split into its parts.
#
proc ::uri::SplitUrn {uri} {
    #@c Split the given uri into then URN component parts
    #@a uri: the URI to split without it's scheme part.
    #@r List of the component parts suitable for 'array set'

    upvar \#0 [namespace current]::urn::URNpart pattern
    array set parts {nid {} nss {}}
    if {[regexp -- ^$pattern $uri -> parts(nid) parts(nss)]} {
        return [array get parts]
    } else {
        error "invalid urn syntax: \"$uri\" could not be parsed"
    }
}


# -------------------------------------------------------------------------

proc ::uri::JoinUrn args {
    #@c Join the parts of a URN scheme URI
    #@a list of nid value nss value
    #@r a valid string representation for your URI
    variable urn::NIDpart

    array set parts [list nid {} nss {}]
    array set parts $args
    if {! [regexp -- ^$NIDpart$ $parts(nid)]} {
        error "invalid urn: nid is invalid"
    }
    set url "urn:$parts(nid):[urn::quote $parts(nss)]"
    return $url
}

# -------------------------------------------------------------------------

# Quote the disallowed characters according to the RFC for URN scheme.
# ref: RFC2141 sec2.2
proc ::uri::urn::quote {url} {
    variable trans
    
    set ndx 0
    set result ""
    while {[regexp -indices -- "\[^$trans\]" $url r]} {
        set ndx [lindex $r 0]

        set ch [string index $url $ndx]
        if {$ch eq "\0"} {
            error "invalid character: character $chr is not allowed"
        }

        # Decode into UTF-8 bytes.
        set rep {}
        foreach ch [split [encoding convertto utf-8 $ch] {}] {
            scan $ch %c chr
            append rep %[format %.2X $chr]
        }
        
        incr ndx -1
        append result [string range $url 0 $ndx] $rep
        incr ndx 2
        set url [string range $url $ndx end]
    }
    append result $url
    return $result
}

# -------------------------------------------------------------------------
# Perform the reverse of urn::quote.

if { [package vcompare [package provide Tcl] 8.3] < 0 } {
    # Before Tcl 8.3 we do not have 'regexp -start'. We simulate it by
    # using 'string range' and adjusting the match results.

    proc ::uri::urn::unquote {url} {
        set result ""
        set start 0
        while {[regexp -indices {%[0-9a-fA-F]{2}} [string range $url $start end] match]} {
            foreach {first last} $match break
            incr first $start ; # Make the indices relative to the true string.
            incr last  $start ; # I.e. undo the effect of the 'string range' on match results.
            append result [string range $url $start [expr {$first - 1}]]
            append result [format %c 0x[string range $url [incr first] $last]]
            set start [incr last]
        }
        append result [string range $url $start end]
        # Recode the array of utf-8 bytes to the proper internal rep.
        return [encoding convertfrom utf-8 $result]
    }
} else {
    proc ::uri::urn::unquote {url} {
        set result ""
        set start 0
        while {[regexp -start $start -indices {%[0-9a-fA-F]{2}} $url match]} {
            foreach {first last} $match break
            append result [string range $url $start [expr {$first - 1}]]
            append result [format %c 0x[string range $url [incr first] $last]]
            set start [incr last]
        }
        append result [string range $url $start end]
        # Recode the array of utf-8 bytes to the proper internal rep.
        return [encoding convertfrom utf-8 $result]
    }
}

# -------------------------------------------------------------------------

::uri::register {urn URN} {
	variable NIDpart {[a-zA-Z0-9][a-zA-Z0-9-]{0,31}}
        variable esc {%[0-9a-fA-F]{2}}
        variable trans {a-zA-Z0-9$_.+!*'(,):=@;-}
        variable NSSpart "($esc|\[$trans\])+"
        variable URNpart "($NIDpart):($NSSpart)"
        variable schemepart $URNpart
	variable url "urn:$NIDpart:$NSSpart"
}

# -------------------------------------------------------------------------

package provide uri::urn 1.0.3

# -------------------------------------------------------------------------
# Local Variables:
#   indent-tabs-mode: nil
# End:
