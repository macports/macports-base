# gtoken.tcl - Copyright (C) 2006 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# This is an implementation of Google's X-GOOGLE-TOKEN authentication 
# mechanism. This actually passes the login details to the Google
# accounts server which gives us a short lived token that may be passed 
# over an insecure link.
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------

package require Tcl 8.2
package require SASL
package require http
package require tls

namespace eval ::SASL {
    namespace eval XGoogleToken {
        variable URLa https://www.google.com/accounts/ClientAuth
        variable URLb https://www.google.com/accounts/IssueAuthToken

        # Should use autoproxy and register autoproxy::tls_socket
        # Leave to application author?
        if {![info exists ::http::urlTypes(https)]} {
            http::register https 443 tls::socket
        }
    }
}

proc ::SASL::XGoogleToken::client {context challenge args} {
    upvar #0 $context ctx
    variable URLa
    variable URLb
    set reply ""
    set err ""

    if {$ctx(step) != 0} {
        return -code error "unexpected state: X-GOOGLE-TOKEN has only 1 step"
    }
    set username [eval $ctx(callback) [list $context username]]
    set password [eval $ctx(callback) [list $context password]]
    set query [http::formatQuery Email $username Passwd $password \
                   PersistentCookie false source googletalk]
    set tok [http::geturl $URLa -query $query -timeout 30000]
    if {[http::status $tok] eq "ok"} {
        foreach line [split [http::data $tok] \n] {
            array set g [split $line =]
        }
        if {![info exists g(Error)]} {
            set query [http::formatQuery SID $g(SID) LSID $g(LSID) \
                           service mail Session true]
            set tok2 [http::geturl $URLb -query $query -timeout 30000]

            if {[http::status $tok2] eq "ok"} {
                set reply "\0$username\0[http::data $tok2]"
            } else {
                set err [http::error $tok2]
            }
            http::cleanup $tok2
       } else {
           set err "Invalid username or password"
       }
    } else {
        set err [http::error $tok]
    }
    http::cleanup $tok
    
    if {[string length $err] > 0} {
        return -code error $err
    } else {
        set ctx(response) $reply
        incr ctx(step)
    }
    return 0
}

# -------------------------------------------------------------------------

# Register this SASL mechanism with the Tcllib SASL package.
#
if {[llength [package provide SASL]] != 0} {
    ::SASL::register X-GOOGLE-TOKEN 40 ::SASL::XGoogleToken::client
}

package provide SASL::XGoogleToken 1.0.1

# -------------------------------------------------------------------------
#
# Local variables:
# indent-tabs-mode: nil
# End:
