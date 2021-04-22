# spf.tcl - Copyright (C) 2004 Pat Thoyts <patthoyts@users.sourceforge.net>
#
#                         Sender Policy Framework
#
#    http://www.ietf.org/internet-drafts/draft-ietf-marid-protocol-00.txt
#    http://spf.pobox.com/
#
# Some domains using SPF:
#   pobox.org       - mx, a, ptr
#   oxford.ac.uk    - include
#   gnu.org         - ip4
#   aol.com         - ip4, ptr
#   sourceforge.net - mx, a
#   altavista.com   - exists,  multiple TXT replies.
#   oreilly.com     - mx, ptr, include
#   motleyfool.com  - include (looping includes)
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------

package require Tcl 8.2;                # tcl minimum version
package require dns;                    # tcllib 1.3
package require logger;                 # tcllib 1.3
package require ip;                     # tcllib 1.7
package require struct::list;           # tcllib 1.7
package require uri::urn;               # tcllib 1.3

namespace eval spf {
    namespace export spf

    variable uid
    if {![info exists uid]} {set uid 0}

    variable log
    if {![info exists log]} {
        set log [logger::init spf]
        ${log}::setlevel warn
        proc ${log}::stdoutcmd {level text} {
            variable service
            puts "\[[clock format [clock seconds] -format {%H:%M:%S}]\
                $service $level\] $text"
        }
    }
}

# -------------------------------------------------------------------------
# ip     : ip address of the connecting host
# domain : the domain to match
# sender : full sender email address
#
proc ::spf::spf {ip domain sender} {
    variable log

    # 3.3: Initial processing
    # If the sender address has no local part, set it to postmaster
    set addr [split $sender @]
    if {[set len [llength $addr]] == 0} {
        return -code error -errorcode permanent "invalid sender address"
    } elseif {$len == 1} {
        set sender "postmaster@$sender"
    }

    # 3.4: Record lookup
    set spf [SPF $domain]
    if {[string equal $spf none]} {
        return $spf
    }

    return [Spf $ip $domain $sender $spf]
}

proc ::spf::Spf {ip domain sender spf} {
    variable log

    # 3.4.1: Matching Version
    if {![regexp {^v=spf(\d)\s+} $spf -> version]} {
        return none
    }

    ${log}::debug "$spf"

    if {$version != 1} {
        return -code error -errorcode permanent \
            "version mismatch: we only understand SPF 1\
            this domain has provided version \"$version\""
    }

    set result ?
    set seen_domains $domain
    set explanation {denied}

    set directives [lrange [split $spf { }] 1 end]
    foreach directive $directives {
        set prefix [string range $directive 0 0]
        if {[string equal $prefix "+"] || [string equal $prefix "-"]
            || [string equal $prefix "?"] || [string equal $prefix "~"]} {
            set directive [string range $directive 1 end]
        } else {
            set prefix "+"
        }

        set cmd [string tolower [lindex [split $directive {:/=}] 0]]
        set param [string range $directive [string length $cmd] end]

        if {[info commands ::spf::_$cmd] == {}} {
            # 6.1 Unrecognised directives terminate processing
            #     but unknown modifiers are ignored.
            if {[string match "=*" $param]} {
                continue
            } else {
                set result unknown
                break
            }
        } else {
            set r [catch {::spf::_$cmd $ip $domain $sender $param} res]
            if {$r} {
                if {$r == 2} {return $res};# deal with return -code return
                if {[string equal $res "none"]
                    || [string equal $res "error"]
                    || [string equal $res "unknown"]} {
                    return $res
                }
                return -code error "error in \"$cmd\": $res"
            }
            if {$res} { set result $prefix }
        }

        ${log}::debug "$prefix $cmd\($param) -> $result"
        if {[string equal $result "+"]} break
    }

    return $result
}

proc ::spf::loglevel {level} {
    variable log
    ${log}::setlevel $level
}

# get a guaranteed unique and non-present token id.
proc ::spf::create_token {} {
    variable uid
    set id [incr uid]
    while {[info exists [set token [namespace current]::$id]]} {
        set id [incr uid]
    }
    return $token
}

# -------------------------------------------------------------------------
#
#                      SPF MECHANISM HANDLERS
#
# -------------------------------------------------------------------------

# 4.1:	The "all" mechanism is a test that always matches.  It is used as the
#	rightmost mechanism in an SPF record to provide an explicit default
#
proc ::spf::_all {ip domain sender param} {
    return 1
}

# 4.2:	The "include" mechanism triggers a recursive SPF query.
#	The domain-spec is expanded as per section 8.
proc ::spf::_include {ip domain sender param} {
    variable log
    upvar seen_domains Seen

    if {![string equal [string range $param 0 0] ":"]} {
        return -code error "dubious parameters for \"include\""
    }
    set r ?
    set new_domain [Expand [string range $param 1 end] $ip $domain $sender]
    if {[lsearch $Seen $new_domain] == -1} {
        lappend Seen $new_domain
        set spf [SPF $new_domain]
        if {[string equal $spf none]} {
            return $spf
        }
        set r [Spf $ip $new_domain $sender $spf]
    }
    return [string equal $r "+"]
}

# 4.4:	This mechanism matches if <ip> is one of the target's
#	IP addresses.
#	e.g: a:smtp.example.com a:mail.%{d} a
#
proc ::spf::_a {ip domain sender param} {
    variable log
    foreach {testdomain bits} [ip::SplitIp [string trimleft $param :]] {}
    if {[string length $testdomain] < 1} {
        set testdomain $domain
    } else {
        set testdomain [Expand $testdomain $ip $domain $sender]
    }
    ${log}::debug "  fetching A for $testdomain"
    set dips [A $testdomain];           # get the IPs for the testdomain
    foreach dip $dips {
        ${log}::debug "  compare: ${ip}/${bits} with ${dip}/${bits}"
        if {[ip::equal $ip/$bits $dip/$bits]} {
            return 1
        }
    }
    return 0
}

# 4.5: This mechanism matches if the <sending-host> is one of the MX hosts
#      for a domain name.
#
proc ::spf::_mx {ip domain sender param} {
    variable log
    foreach {testdomain bits} [ip::SplitIp [string trimleft $param :]] {}
    if {[string length $testdomain] < 1} {
        set testdomain $domain
    } else {
        set testdomain [Expand $testdomain $ip $domain $sender]
    }
    ${log}::debug "  fetching MX for $testdomain"
    set mxs [MX $testdomain]

    foreach mx $mxs {
        set mx [lindex $mx 1]
        set mxips [A $mx]
        foreach mxip $mxips {
            ${log}::debug "  compare: ${ip}/${bits} with ${mxip}/${bits}"
            if {[ip::equal $ip/$bits $mxip/$bits]} {
                return 1
            }
        }
    }
    return 0
}

# 4.6: This mechanism tests if the <sending-host>'s name is within a
#      particular domain.
#
proc ::spf::_ptr {ip domain sender param} {
    variable log
    set validnames {}
    if {[catch { set names [PTR $ip] } msg]} {
        ${log}::debug "  \"$ip\" $msg"
        return 0
    }
    foreach name $names {
        set addrs [A $name]
        foreach addr $addrs {
            if {[ip::equal $ip $addr]} {
                lappend validnames $name
                continue
            }
        }
    }

    ${log}::debug "  validnames: $validnames"
    set testdomain [Expand [string trimleft $param :] $ip $domain $sender]
    if {$testdomain == {}} {
        set testdomain $domain
    }
    foreach name $validnames {
        if {[string match "*$testdomain" $name]} {
            return 1
        }
    }

    return 0
}

# 4.7: These mechanisms test if the <sending-host> falls into a given IP
#      network.
#
proc ::spf::_ip4 {ip domain sender param} {
    variable log
    foreach {network bits} [ip::SplitIp [string range $param 1 end]] {}
    ${log}::debug "  compare ${ip}/${bits} to ${network}/${bits}"
    if {[ip::equal $ip/$bits $network/$bits]} {
        return 1
    }
    return 0
}

# 4.6: These mechanisms test if the <sending-host> falls into a given IP
#      network.
#
proc ::spf::_ip6 {ip domain sender param} {
    variable log
    foreach {network bits} [ip::SplitIp [string range $param 1 end]] {}
    ${log}::debug "  compare ${ip}/${bits} to ${network}/${bits}"
    if {[ip::equal $ip/$bits $network/$bits]} {
        return 1
    }
    return 0
}

# 4.7: This mechanism is used to construct an arbitrary host name that is
#      used for a DNS A record query.  It allows for complicated schemes
#      involving arbitrary parts of the mail envelope to determine what is
#      legal.
#
proc ::spf::_exists {ip domain sender param} {
    variable log
    set testdomain [Expand [string range $param 1 end] $ip $domain $sender]
    ${log}::debug "   checking existence of '$testdomain'"
    if {[catch {A $testdomain}]} {
        return 0
    }
    return 1
}

# 5.1: Redirected query
#
proc ::spf::_redirect {ip domain sender param} {
    variable log
    set new_domain [Expand [string range $param 1 end] $ip $domain $sender]
    ${log}::debug ">> redirect to '$new_domain'"
    set spf [SPF $new_domain]
    if {![string equal $spf none]} {
        set spf [Spf $ip $new_domain $sender $spf]
    }
    ${log}::debug "<< redirect returning '$spf'"
    return -code return $spf
}

# 5.2: Explanation
#
proc ::spf::_exp {ip domain sender param} {
    variable log
    set new_domain [string range $param 1 end]
    set exp [TXT $new_domain]
    set exp [Expand $exp $ip $domain $sender]
    ${log}::debug "exp expanded to \"$exp\""
    # FIX ME: need to store this somehow.
}

# 5.3: Sender accreditation
#
proc ::spf::_accredit {ip domain sender param} {
    variable log
    set accredit [Expand [string range $param 1 end] $ip $domain $sender]
    ${log}::debug "  accreditation '$accredit'"
    # We are not using this at the moment.
    return 0
}


# 7: Macro expansion
#
proc ::spf::Expand {txt ip domain sender} {
    variable log
    set re {%\{[[:alpha:]](?:\d+)?r?[\+\-\.,/_=]*\}}
    set txt [string map {\[ \\\[ \] \\\]} $txt]
    regsub -all $re $txt {[ExpandMacro & $ip $domain $sender]} cmd
    set cmd [string map {%% % %_ \  %- %20} $cmd]
    return [subst -novariables $cmd]
}

proc ::spf::ExpandMacro {macro ip domain sender} {
    variable log
    set re {%\{([[:alpha:]])(\d+)?(r)?([\+\-\.,/_=]*)\}}
    set C {} ; set T {} ; set R {}; set D {}
    set r [regexp $re $macro -> C T R D]
    if {$R == {}} {set R 0} else {set R 1}
    set res $macro
    if {$r} {
        set enc [string is upper $C]
        switch -exact -- [string tolower $C] {
            s { set res $sender }
            l {
                set addr [split $sender @]
                if {[llength $addr] < 2} {
                    set res postmaster
                } else {
                    set res [lindex $addr 0]
                }
            }
            o {
                set addr [split $sender @]
                if {[llength $addr] < 2} {
                    set res $sender
                } else {
                    set res [lindex $addr 1]
                }
            }
            h - d { set res $domain }
            i {
                set res [ip::normalize $ip]
                if {[ip::is ipv6 $res]} {
                    # Convert 0000:0001 to 0.1
                    set t {}
                    binary scan [ip::Normalize $ip 6] c* octets
                    foreach octet $octets {
                        set hi [expr {($octet & 0xF0) >> 4}]
                        set lo [expr {$octet & 0x0F}]
                        lappend t [format %x $hi] [format %x $lo]
                    }
                    set res [join $t .]
                }
            }
            v {
                if {[ip::is ipv6 $ip]} {
                    set res ip6
                } else {
                    set res "in-addr"
                }
            }
            c {
                set res [ip::normalize $ip]
                if {[ip::is ipv6 $res]} {
                    set res [ip::contract $res]
                }
            }
            r {
                set s [socket -server {} -myaddr [info host] 0]
                set res [lindex [fconfigure $s -sockname] 1]
                close $s
            }
            t { set res [clock seconds] }
        }
        if {$T != {} || $R || $D != {}} {
            if {$D == {}} {set D .}
            set res [split $res $D]
            if {$R} {
                set res [struct::list::Lreverse $res]
            }
            if {$T != {}} {
                incr T -1
                set res [join [lrange $res end-$T end] $D]
            }
            set res [join $res .]
        }
        if {$enc} {
            # URI encode the result.
            set res [uri::urn::quote $res]
        }
    }
    return $res
}

# -------------------------------------------------------------------------
#
# DNS helper procedures.
#
# -------------------------------------------------------------------------

proc ::spf::Resolve {domain type resultproc} {
    if {[info commands $resultproc] == {}} {
        return -code error "invalid arg: \"$resultproc\" must be a command"
    }
    set tok [dns::resolve $domain -type $type]
    dns::wait $tok
    set errorcode NONE
    if {[string equal [dns::status $tok] "ok"]} {
        set result [$resultproc $tok]
        set code   ok
    } else {
        set result    [dns::error $tok]
        set errorcode [dns::errorcode $tok]
        set code      error
    }
    dns::cleanup $tok
    return -code $code -errorcode $errorcode $result
}

# 3.4: Record lookup
proc ::spf::SPF {domain} {
    set txt ""
    if {[catch {Resolve $domain SPF ::dns::result} spf]} {
        set code $::errorCode
        ${log}::debug "error fetching SPF record: $r"
        switch -exact -- $code {
            3 { return -code return [list - "Domain Does Not Exist"] }
            2 { return -code error -errorcode temporary $spf }
        }
        set txt none
    } else {
        foreach res $spf {
            set ndx [lsearch $res rdata]
            incr ndx
            if {$ndx != 0} {
                append txt [string range [lindex $res $ndx] 1 end]
            }
        }
    }
    return $txt
}

proc ::spf::TXT {domain} {
    set r [Resolve $domain TXT ::dns::result]
    set txt ""
    foreach res $r {
        set ndx [lsearch $res rdata]
        incr ndx
        if {$ndx != 0} {
            append txt [string range [lindex $res $ndx] 1 end]
        }
    }
    return $txt
}

proc ::spf::A {name} {
    return [Resolve $name A ::dns::address]
}


proc ::spf::AAAA {name} {
    return [Resolve $name AAAA ::dns::address]
}

proc ::spf::PTR {addr} {
    return [Resolve $addr A ::dns::name]
}

proc ::spf::MX {domain} {
    set r [Resolve $domain MX ::dns::name]
    return [lsort -index 0 $r]
}


# -------------------------------------------------------------------------

package provide spf 1.1.1

# -------------------------------------------------------------------------
# Local Variables:
#   indent-tabs-mode: nil
# End:
