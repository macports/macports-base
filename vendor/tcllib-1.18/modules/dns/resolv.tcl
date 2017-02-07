# resolv.tcl - Copyright (c) 2002 Emmanuel Frecon <emmanuel@sics.se>
#
# Original Author --  Emmanuel Frecon - emmanuel@sics.se
# Modified by Pat Thoyts <patthoyts@users.sourceforge.net>
#
#  A super module on top of the dns module for host name resolution.
#  There are two services provided on top of the regular Tcl library:
#  Firstly, this module attempts to automatically discover the default
#  DNS server that is setup on the machine that it is run on.  This
#  server will be used in all further host resolutions.  Secondly, this
#  module offers a rudimentary cache.  The cache is rudimentary since it
#  has no expiration on host name resolutions, but this is probably
#  enough for short lived applications.
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------

package require dns 1.0;                # tcllib 1.3

namespace eval ::resolv {
    namespace export resolve init ignore hostname

    variable R
    if {![info exists R]} {
        array set R {
            initdone   0
            dns        ""
            dnsdefault ""
            ourhost    ""
            search     {}
        }
    }
}

# -------------------------------------------------------------------------
# Command Name     --  ignore
# Original Author  --  Emmanuel Frecon - emmanuel@sics.se
#
# Remove a host name resolution from the cache, if present, so that the
# next resolution will query the DNS server again.
#
# Arguments:
#    hostname	- Name of host to remove from the cache.
#
proc ::resolv::ignore { hostname } {
    variable Cache
    catch {unset Cache($hostname)}
    return
}

# -------------------------------------------------------------------------
# Command Name     --  init
# Original Author  --  Emmanuel Frecon - emmanuel@sics.se
#
# Initialise this module with a known host name.  This host (not mandatory)
# will become the default if the library was not able to find a DNS server.
# This command can be called several times, its effect is double: actively
# looking for the default DNS server setup on the running machine; and
# emptying the host name resolution cache.
#
# Arguments:
#    defaultdns	- Default DNS server
#
proc ::resolv::init { {defaultdns ""} {search {}}} {
    variable R
    variable Cache

    # Clean the resolver cache
    catch {unset Cache}

    # Record the default DNS server and search list.
    set R(dnsdefault) $defaultdns
    set R(search) $search

    # Now do some intelligent lookup.  We do this on the current
    # hostname to get a chance to get back some (full) information on
    # ourselves.  A previous version was using 127.0.0.1, not sure
    # what is best.
    set res [catch [list exec nslookup [info hostname]] lkup]
    if { $res == 0 } {
	set l [split $lkup]
	set nl ""
	foreach e $l {
	    if { [string length $e] > 0 } {
		lappend nl $e
	    }
	}

        # Now, a lot of mixture to arrange so that hostname points at the
        # DNS server that we should use for any further request.  This
        # code is complex, but was actually tested behind a firewall
        # during the SITI Winter Conference 2003.  There, strangly,
        # nslookup returned an error but a DNS server was actually setup
        # correctly...
        set hostname ""
	set len [llength $nl]
	for { set i 0 } { $i < $len } { incr i } {
	    set e [lindex $nl $i]
	    if { [string match -nocase "*server*" $e] } {
		set hostname [lindex $nl [expr {$i + 1}]]
                if { [string match -nocase "UnKnown" $hostname] } {
                    set hostname ""
                }
		break
	    }
	}

	if { $hostname != "" } {
	    set R(dns) $hostname
	} else {
            for { set i 0 } { $i < $len } { incr i } {
                set e [lindex $nl $i]
                if { [string match -nocase "*address*" $e] } {
                    set hostname [lindex $nl [expr {$i + 1}]]
                    break
                }
            }
            if { $hostname != "" } {
                set R(dns) $hostname
            }
	}
    }

    if {$R(dns) == ""} {
        set R(dns) $R(dnsdefault)
    }


    # Start again to find our full name
    set ourhost ""
    if {$res == 0} {
        set dot [string first "." [info hostname]]
        if { $dot < 0 } {
            for { set i 0 } { $i < $len } { incr i } {
                set e [lindex $nl $i]
                if { [string match -nocase "*name*" $e] } {
                    set ourhost [lindex $nl [expr {$i + 1}]]
                    break
                }
            }
            if { $ourhost == "" } {
                if { ! [regexp {\d+\.\d+\.\d+\.\d+} $hostname] } {
                    set dot [string first "." $hostname]
                    set ourhost [format "%s%s" [info hostname] \
                                     [string range $hostname $dot end]]
                }
            }
        } else {
            set ourhost [info hostname]
        }
    }

    if {$ourhost == ""} {
        set R(ourhost) [info hostname]
    } else {
        set R(ourhost) $ourhost
    }


    set R(initdone) 1

    return $R(dns)
}

# -------------------------------------------------------------------------
# Command Name     --  resolve
# Original Author  --  Emmanuel Frecon - emmanuel@sics.se
#
# Resolve a host name to an IP address.  This is a wrapping procedure around
# the basic services of the dns library.
#
# Arguments:
#    hostname	- Name of host
#
proc ::resolv::resolve { hostname } {
    variable R
    variable Cache

    # Initialise if not already done. Auto initialisation cannot take
    # any known DNS server (known to the caller)
    if { ! $R(initdone) } { init }

    # Check whether this is not simply a raw IP address. What about
    # IPv6 ??
    # - We don't have sockets in Tcl for IPv6 protocols - [PT]
    #
    if { [regexp {\d+\.\d+\.\d+\.\d+} $hostname] } {
	return $hostname
    }

    # Look for hostname in the cache, if found return.
    if { [array names ::resolv::Cache $hostname] != "" } {
	return $::resolv::Cache($hostname)
    }

    # Scream if we don't have any DNS server setup, since we cannot do
    # anything in that case.
    if { $R(dns) == "" } {
	return -code error "No dns server provided"
    }

    set R(retries) 0
    set ip [Resolve $hostname]

    # And store the result of resolution in our cache for further use.
    set Cache($hostname) $ip

    return $ip
}

# Description:
#  Attempt to resolve hostname via DNS. If the name cannot be resolved then
#  iterate through the search list appending each domain in turn until we
#  get one that succeeds.
#
proc ::resolv::Resolve {hostname} {
    variable R
    set t [::dns::resolve $hostname -server $R(dns)]
    ::dns::wait $t;                       # wait with event processing
    set status [dns::status $t]
    if {$status == "ok"} {
        set ip [lindex [::dns::address $t] 0]
        ::dns::cleanup $t
    } elseif {$status == "error"
              && [::dns::errorcode $t] == 3 
              && $R(retries) < [llength $R(search)]} {
        ::dns::cleanup $t
        set suffix [lindex $R(search) $R(retries)]
        incr R(retries)
        set new [lindex [split $hostname .] 0].[string trim $suffix .]
        set ip [Resolve $new]
    } else {
        set err [dns::error $t]
        ::dns::cleanup $t
        return -code error "dns error: $err"
    }
    return $ip
}

# -------------------------------------------------------------------------

package provide resolv 1.0.3

# -------------------------------------------------------------------------
# Local Variables:
#   indent-tabs-mode: nil
# End:
