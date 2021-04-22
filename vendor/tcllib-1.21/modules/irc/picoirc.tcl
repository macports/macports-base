# Based upon the picoirc code by Salvatore Sanfillipo and Richard Suchenwirth
# See http://wiki.tcl.tk/13134 for the original standalone version.
#
#	This package provides a general purpose minimal IRC client suitable for
#	embedding in other applications. All communication with the parent
#	application is done via an application provided callback procedure.
#
# Copyright (c) 2004 Salvatore Sanfillipo
# Copyright (c) 2004 Richard Suchenwirth
# Copyright (c) 2007 Patrick Thoyts
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------

package require Tcl 8.6

# -------------------------------------------------------------------------

namespace eval ::picoirc {
    variable uid
    if {![info exists uid]} { set uid 0 }

    variable defaults {
        server   "irc.libera.chat"
        port     6667
        secure   0
        channels ""
        callback ""
        motd     {}
        users    {}
    }
    namespace export connect post
}

proc ::picoirc::Splituri {uri} {
    lassign {{} {} {} {}} secure server port channels
    if {![regexp {^irc(s)?://([^:/]+)(?::([^/]+))?(?:/([^ ]+))?} $uri -> secure server port channels]} {
        regexp {^(?:([^@]+)@)?([^:]+)(?::(\d+))?} $uri -> channels server port
    }
    set secure [expr {$secure eq "s"}]

    set channels [lmap x [split $channels ,] {
        # Filter out parameters that are special according to the IRC URL
        # scheme Internet-Draft.
        if {$x in {needkey needpass}} continue
        set x
    }]
    if {[llength $channels] == 1} {
        set channels [lindex $channels 0]
    }

    if {$port eq {}} { set port [expr {$secure ? 6697: 6667}] }
    return [list $server $port $channels $secure]
}

proc ::picoirc::connect {callback nick args} {
    if {[llength $args] > 2} {
        return -code error "wrong # args: must be \"callback nick ?passwd? url\""
    } elseif {[llength $args] == 1} {
        set url [lindex $args 0]
    } else {
	lassign $args passwd url
    }
    variable defaults
    variable uid
    set context [namespace current]::irc[incr uid]
    upvar #0 $context irc
    array set irc $defaults
    lassign [Splituri $url] server port channels secure
    if {[info exists channels] && $channels ne ""} {set irc(channels) $channels}
    if {[info exists server]   && $server   ne ""} {set irc(server)   $server}
    if {[info exists port]     && $port     ne ""} {set irc(port)     $port}
    if {[info exists secure]   && $secure}         {set irc(secure)   $secure}
    if {[info exists passwd]   && $passwd   ne ""} {set irc(passwd)   $passwd}
    set irc(callback) $callback
    set irc(nick) $nick
    set irc(is_registered) false
    Callback $context init
    if {$irc(secure)} {
        set irc(socket) [::tls::socket -async $irc(server) $irc(port)]
    } else {
        set irc(socket) [socket -async $irc(server) $irc(port)]
    }
    fileevent $irc(socket) readable [list [namespace origin Read] $context]
    fileevent $irc(socket) writable [list [namespace origin Write] $context]
    return $context
}

proc picoirc::Pop {varname {nth 0}} {
    upvar $varname args
    set r [lindex $args $nth]
    set args [lreplace $args $nth $nth]
    return $r
}

proc ::picoirc::Callback {context state args} {
    upvar #0 $context irc
    if {[llength $irc(callback)] > 0
        && [llength [info commands [lindex $irc(callback) 0]]] == 1} {
        if {[catch {eval $irc(callback) [list $context $state] $args} result]} {
            puts stderr "callback error: $result"
        } else {
            return $result
        }
    }
}

proc ::picoirc::Version {context} {
    if {[catch {Callback $context version} ver]} { set ver {} }
    if {$ver eq {}} {
        set ver "PicoIRC:[package provide picoirc]:Tcl [info patchlevel]"
    }
    return $ver
}

proc ::picoirc::Write {context} {
    upvar #0 $context irc
    fileevent $irc(socket) writable {}
    if {[set err [fconfigure $irc(socket) -error]] ne ""
        || $irc(secure) && [catch {while {![::tls::handshake $irc(socket)]} {}} err] != 0} {
        Callback $context close $err
        close $irc(socket)
        unset irc
        return
    }
    fconfigure $irc(socket) -blocking 0 -buffering line -translation crlf -encoding utf-8
    Callback $context connect
    set ver [join [lrange [split [Version $context] :] 0 1] " "]
    Send $context "USER $::tcl_platform(user) 0 * :$ver user"
    if {[info exists irc(passwd)] && [package provide SASL] ne {}} {
        Send $context "CAP REQ :sasl"
    } else {
        Register $context
    }
    return
}

proc ::picoirc::Register {context} {
    upvar #0 $context irc
    unset -nocomplain irc(sasl:challenge) irc(sasl:mechs)
    Send $context "NICK $irc(nick)"
    if {[info exists irc(passwd)] && !$irc(is_registered)} {
        Send $context "PASS $irc(passwd)"
    }
}

proc ::picoirc::Getnick {s} {
    set nick {}
    regexp {^([^!]*)!} $s -> nick
    return $nick
}

proc ::picoirc::ParseMsg {line} {
    set prefix ""
    if {[string match ":*" $line]} {
        set ndx [string first " " $line]
        set prefix [string range $line 1 [expr {$ndx - 1}]]
        set line [string range $line [expr {$ndx + 1}] end]
    }
    if {[set ndx [string first " :" $line]] != -1} {
        set parts [split [string range $line 0 [expr {$ndx - 1}]] " "]
        set rest [string range $line [expr {$ndx + 2}] end]
    } else {
        set parts [split $line " "]
        set rest ""
    }
    return [list $prefix $parts $rest]
}

proc ::picoirc::Read {context} {
    upvar #0 $context irc
    if {[eof $irc(socket)]} {
        fileevent $irc(socket) readable {}
        Callback $context close
        close $irc(socket)
        unset irc
        return
    }
    if {[gets $irc(socket) line] != -1} {
        if {[string match "PING*" $line]} {
            Send $context "PONG [info hostname] [lindex [split $line] 1]"
            return
        }
        # the callback can return -code break to prevent processing the read
        if {[catch {Callback $context debug read $line}] == 3} {
            return
        }
        if {[string match "AUTHENTICATE *" $line]} {
            # codes 903 for successful, 904/905/906 for fail
            set data [string range $line 13 end]
            if {$data eq "+"} {set data ""}
            append irc(sasl:challenge) $data ;# accumulate chunks
            if {[string length $data] != 400} {
                set challenge [binary decode base64 $irc(sasl:challenge)]
                set irc(sasl:challenge) ""
                if {![SASL::step $irc(sasl) $challenge]} {
                    set response [SASL::response $irc(sasl)]
                    if {$response eq ""} {
                        set response "+"
                    } else {
                        set response [binary encode base64 $response]
                    }
                    Send $context "AUTHENTICATE $response"
                }
            }
            return
        }
        lassign [ParseMsg $line] prefix parts rest
        if {[lindex $parts 0] eq "PRIVMSG"} {
            set nick [Getnick $prefix]
            set target [lindex $parts 1]
            set msg $rest
            set type ""
            if {[regexp {^\001(\S+)(?: (.*))?\001$} $msg -> ctcp data]} {
                switch -- $ctcp {
                    ACTION { set type ACTION ; set msg $data }
                    VERSION {
                        Send $context "NOTICE $nick :\001VERSION [Version $context]\001"
                        return
                    }
                    PING {
                        Send $context "NOTICE $nick :\001PING [lindex $data 0]\001"
                        return
                    }
                    TIME {
                        set time [clock format [clock seconds] \
                                      -format {%a %b %d %H:%M:%S %Y %Z}]
                        Send $context "NOTICE $nick :\001TIME $time\001"
                        return
                    }
                    default {
                        set err [string map [list \001 ""] $msg]
                        Send $context "NOTICE $nick :\001ERRMSG $err : unknown query\001"
                        return
                    }
                }
            }
            Callback $context chat $target $nick $msg $type
        } elseif {$prefix ne {}} {
            set server $prefix
	    lassign $parts code target fourth fifth
            switch -- $code {
                001 - 002 - 003 - 004 - 005 - 250 - 251 - 252 -
                254 - 255 - 265 - 266 { return }
                433 {
                    variable nickid ; if {![info exists nickid]} {set nickid 0}
                    set seqlen [string length [incr nickid]]
                    set irc(nick) [string range $irc(nick) 0 [expr 8-$seqlen]]$nickid
                    Send $context "NICK $irc(nick)"
                }
                353 { set irc(users) [concat $irc(users) $rest]; return }
                366 {
                    Callback $context userlist $fourth $irc(users)
                    set irc(users) {}
                    return
                }
                332 { Callback $context topic $fourth $rest; return }
                333 { return }
                375 { set irc(motd) {} ; return }
                372 { append irc(motd) $rest ; return}
                376 {
                    foreach channel $irc(channels) {
                        after idle [list [namespace origin Send] \
                                        $context "JOIN $channel"]
                    }
                    return
                }
                311 {
		    lassign $parts code target nick name host x
                    set irc(whois,$fourth) [list name $name host $host userinfo $rest]
                    return
                }
                301 - 312 - 317 - 320 - 330 - 338 { return }
                319 { lappend irc(whois,$fourth) channels $rest; return }
                318 {
                    if {[info exists irc(whois,$fourth)]} {
                        Callback $context userinfo $fourth $irc(whois,$fourth)
                        unset irc(whois,$fourth)
                    }
                    return
                }
                900 {
                    Callback $context system "" $rest
                    return
                }
                903 {
                    # sasl success
                    Send $context "CAP END"
                    set irc(is_registered) true
                    Callback $context system "" "SASL authentication succeeded"
                    Register $context
                    return
                }
                904 {
                    # sasl failed, if no mechanism left, non-sasl login
                    if {![info exists irc(sasl)]} {
                        Send $context "CAP END"
                        Callback $context system "" "SASL authentication failed"
                        Register $context
                    }
                    return
                }
                905 - 906 {
                    # sasl aborted
                    unset irc(sasl)
                    Send $context "CAP END"
                    Callback $context system "" "SASL authentication aborted"
                    Register $context
                    return
                }
                908 {
                    set provided [split $fourth ,]
                    while {$irc(sasl:mechs) ne {}} {
                        set mech [Pop irc(sasl:mechs)]
                        if {$mech in $provided} {
                            SASL::configure $irc(sasl) -mechanism $mech
                            Send $context "AUTHENTICATE $mech"
                            return
                        }
                    }
                    unset irc(sasl) ;# no more mechanisms
                    return
                }
                JOIN {
                    set nick [Getnick $server]
                    Callback $context traffic entered $target $nick
                    return
                }
                NICK {
                    set nick [Getnick $server]
                    if {$irc(nick) == $nick} {set irc(nick) $rest}
                    Callback $context traffic nickchange {} $nick $rest
                    return
                }
                QUIT - PART {
                    set nick [Getnick $server]
                    Callback $context traffic left $target $nick
                    return
                }
                MODE {
                    set nick [Getnick $server]
                    if {$fourth != ""} {
                        Callback $context mode $nick $target "$fourth $fifth"
                    } else {
                        Callback $context mode $nick $target $rest
                    }
                    return
                }
                NOTICE {
                    if {$target in [list $irc(nick) *]} {
                        set target {}
                    }
                    Callback $context chat $target [Getnick $server] $rest NOTICE
                    return
                }
                CAP {
                    if {$fourth eq "LS"} {
                        set irc(caps) [split $rest]
                    } elseif {$fourth eq "ACK" && $rest eq "sasl"} {
                        Callback $context system "" "SASL authentication supported"
                        set irc(sasl:mechs) [SASL::mechanisms client]
                        set irc(sasl:challenge) ""
                        set mech [Pop irc(sasl:mechs)]
                        set irc(sasl) [SASL::new -mechanism $mech \
                                           -callback [list [namespace origin SASLCallback] \
                                                          $context]]
                        Send $context "AUTHENTICATE $mech"
                    }
                    return
                }
            }
            Callback $context system "" "$parts $rest"
        } else {
            Callback $context system "" $line
        }
    }
}

proc ::picoirc::SASLCallback {Irc context command args} {
    upvar #0 $Irc irc
    switch -exact -- $command {
        login    { return $irc(nick) }
        username { return $irc(nick) }
        password { return $irc(passwd) }
        realm    { return "" }
        hostname { return [info host] }
        default  { return -code error unxpected }
    }
}

proc ::picoirc::post {context channel msg} {
    upvar #0 $context irc
    foreach line [split $msg \n] {
        if [regexp {^/([^ ]+) *(.*)} $line -> cmd msg] {
            regexp {^([^ ]+)?(?: +(.*))?} $msg -> first rest
            switch -- $cmd {
                me {
                    if {$channel eq ""} {
                        Callback $context system "" "not in channel"
                        continue
                    }
                    Send $context "PRIVMSG $channel :\001ACTION $msg\001"
                    Callback $context chat $channel $irc(nick) $msg ACTION
                }
                nick {Send $context "NICK $msg"}
                quit {Send $context "QUIT"}
                part {Send $context "PART $channel"}
                names {Send $context "NAMES $channel"}
                whois {Send $context "WHOIS $msg"}
                kick {Send $context "KICK $channel $first :$rest"}
                mode {Send $context "MODE $msg"}
                topic {Send $context "TOPIC $channel :$msg"}
                quote {Send $context $msg}
                join {Send $context "JOIN $msg"}
                version {Send $context "PRIVMSG $first :\001VERSION\001"}
                msg - notice {
                    set type [expr {$cmd == "msg" ? ""        : "NOTICE"}]
                    set cmd  [expr {$cmd == "msg" ? "PRIVMSG" : "NOTICE"}]
                    Send $context "$cmd $first :$rest"
                    Callback $context chat $first $irc(nick) $rest $type
                }
                default {Callback $context system $channel "unknown command /$cmd"}
            }
            continue
        }
        if {$channel eq ""} {
            Send $context $line
            continue
        }
        Send $context "PRIVMSG $channel :$line"
        Callback $context chat $channel $irc(nick) $line
    }
}

proc ::picoirc::Send {context line} {
    upvar #0 $context irc
    # the callback can return -code break to prevent writing to socket
    if {[catch {Callback $context debug write $line}] != 3} {
        puts $irc(socket) $line
    }
}

# -------------------------------------------------------------------------

package provide picoirc 0.13.0

# -------------------------------------------------------------------------
return
