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

namespace eval ::picoirc {
    variable uid
    if {![info exists uid]} { set uid 0 }

    variable defaults {
        server   "irc.freenode.net"
        port     6667
        channel  ""
        callback ""
        motd     {}
        users    {}
    }
    namespace export connect send post splituri
}

proc ::picoirc::splituri {uri} {
    foreach {server port channel} {{} {} {}} break
    if {![regexp {^irc://([^:/]+)(?::([^/]+))?(?:/([^,]+))?} $uri -> server port channel]} {
        regexp {^(?:([^@]+)@)?([^:]+)(?::(\d+))?} $uri -> channel server port
    }
    if {$port eq {}} { set port 6667 }
    return [list $server $port $channel]
}

proc ::picoirc::connect {callback nick args} {
    if {[llength $args] > 2} {
        return -code error "wrong # args: must be \"callback nick ?passwd? url\""
    } elseif {[llength $args] == 1} {
        set url [lindex $args 0]
    } else {
        foreach {passwd url} $args break 
    }
    variable defaults
    variable uid
    set context [namespace current]::irc[incr uid]
    upvar #0 $context irc
    array set irc $defaults
    foreach {server port channel} [splituri $url] break
    if {[info exists channel] && $channel ne ""} {set irc(channel) $channel}
    if {[info exists server] && $server ne ""} {set irc(server) $server}
    if {[info exists port] && $port ne ""} {set irc(port) $port}
    if {[info exists passwd] && $passwd ne ""} {set irc(passwd) $passwd}
    set irc(callback) $callback
    set irc(nick) $nick
    Callback $context init
    set irc(socket) [socket -async $irc(server) $irc(port)]
    fileevent $irc(socket) readable [list [namespace origin Read] $context]
    fileevent $irc(socket) writable [list [namespace origin Write] $context]
    return $context
}

proc ::picoirc::Callback {context state args} {
    upvar #0 $context irc
    if {[llength $irc(callback)] > 0
        && [llength [info commands [lindex $irc(callback) 0]]] == 1} {
        if {[catch {eval $irc(callback) [list $context $state] $args} err]} {
            puts stderr "callback error: $err"
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
    if {[set err [fconfigure $irc(socket) -error]] ne ""} {
        Callback $context close $err
        close $irc(socket)
        unset irc
        return
    }
    fconfigure $irc(socket) -blocking 0 -buffering line -translation crlf -encoding utf-8
    Callback $context connect
    if {[info exists irc(passwd)]} {
        send $context "PASS $irc(passwd)"
    }
    set ver [join [lrange [split [Version $context] :] 0 1] " "]
    send $context "NICK $irc(nick)"
    send $context "USER $::tcl_platform(user) 0 * :$ver user"
    if {$irc(channel) ne {}} {
        after idle [list [namespace origin send] $context "JOIN $irc(channel)"]
    }
    return
}

proc ::picoirc::Splitirc {s} {
    foreach v {nick flags user host} {set $v {}}
    regexp {^([^!]*)!([^=]*)=([^@]+)@(.*)} $s -> nick flags user host
    return [list $nick $flags $user $host]
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
            send $context "PONG [info hostname] [lindex [split $line] 1]"
            return
        }
        # the callback can return -code break to prevent processing the read
        if {[catch {Callback $context debug read $line}] == 3} {
            return
        }
        if {[regexp {:([^!]*)![^ ].* +PRIVMSG ([^ :]+) +:(.*)} $line -> \
                 nick target msg]} {
            set type ""
            if {[regexp {\001(\S+)(.*)?\001} $msg -> ctcp data]} {
                switch -- $ctcp {
                    ACTION { set type ACTION ; set msg $data }
                    VERSION {
                        send $context "NOTICE $nick :\001VERSION [Version $context]\001"
                        return 
                    }
                    PING {
                        send $context "NOTICE $nick :\001PING [lindex $data 0]\001"
                        return
                    }
                    TIME {
                        set time [clock format [clock seconds] \
                                      -format {%a %b %d %H:%M:%S %Y %Z}]
                        send $context "NOTICE $nick :\001TIME $time\001"
                        return
                    }
                    default {
                        set err [string map [list \001 ""] $msg]
                        send $context "NOTICE $nick :\001ERRMSG $err : unknown query\001"
                        return
                    }
                }
            }
            if {[lsearch -exact {ijchain wubchain} $nick] != -1} {
                if {$type eq "ACTION"} {
                    regexp {(\S+) (.+)} $msg -> nick msg 
                } else {
                    regexp {<([^>]+)> (.+)} $msg -> nick msg
                }
            }
            Callback $context chat $target $nick $msg $type
        } elseif {[regexp {^:((?:([^ ]+) +){1,}?):(.*)$} $line -> parts junk rest]} {
            foreach {server code target fourth fifth} [split $parts] break
            switch -- $code {
                001 - 002 - 003 - 004 - 005 - 250 - 251 - 252 - 
                254 - 255 - 265 - 266 { return }
                433 {
                    variable nickid ; if {![info exists nickid]} {set nickid 0}
                    set seqlen [string length [incr nickid]]
                    set irc(nick) [string range $irc(nick) 0 [expr 8-$seqlen]]$nickid
                    send $context "NICK $irc(nick)"
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
                376 { return }
                311 {
                    foreach {server code target nick name host x} [split $parts] break
                    set irc(whois,$fourth) [list name $name host $host userinfo $rest]
                    return
                }
                301 - 312 - 317 - 320 { return }
                319 { lappend irc(whois,$fourth) channels $rest; return }
                318 {
                    if {[info exists irc(whois,$fourth)]} {
                        Callback $context userinfo $fourth $irc(whois,$fourth)
                        unset irc(whois,$fourth)
                    }
                    return
                }
                JOIN {
                    foreach {n f u h} [Splitirc $server] break
                    Callback $context traffic entered $rest $n
                    return
                }
                NICK {
                    foreach {n f u h} [Splitirc $server] break
                    Callback $context traffic nickchange {} $n $rest
                    return
                }
                QUIT - PART {
                    foreach {n f u h} [Splitirc $server] break
                    Callback $context traffic left $target $n
                    return
                }
            }
            Callback $context system "" "[lrange [split $parts] 1 end] $rest"
        } else {
            Callback $context system "" $line
        }
    }
}

proc ::picoirc::post {context channel msg} {
    upvar #0 $context irc
    set type ""
    if [regexp {^/([^ ]+) *(.*)} $msg -> cmd msg] {
        regexp {^([^ ]+)?(?: +(.*))?} $msg -> first rest
 	switch -- $cmd {
 	    me {set msg "\001ACTION $msg\001";set type ACTION}
 	    nick {send $context "NICK $msg"; set $irc(nick) $msg}
 	    quit {send $context "QUIT" }
            part {send $context "PART $channel" }
 	    names {send $context "NAMES $channel"}
            whois {send $context "WHOIS $channel $msg"}
            kick {send $context "KICK $channel $first :$rest"}
            mode {send $context "MODE $msg"}
            topic {send $context "TOPIC $channel :$msg" }
 	    quote {send $context $msg}
 	    join {send $context "JOIN $msg" }
            version {send $context "PRIVMSG $first :\001VERSION\001"}
 	    msg {
 		if {[regexp {([^ ]+) +(.*)} $msg -> target querymsg]} {
 		    send $context "PRIVMSG $target :$querymsg"
 		    Callback $context chat $target $target $querymsg ""
 		}
 	    }
 	    default {Callback $context system $channel "unknown command /$cmd"}
 	}
 	if {$cmd ne {me} || $cmd eq {msg}} return
    }
    foreach line [split $msg \n] {send $context "PRIVMSG $channel :$line"}
    Callback $context chat $channel $irc(nick) $msg $type
}

proc ::picoirc::send {context line} {
    upvar #0 $context irc
    # the callback can return -code break to prevent writing to socket
    if {[catch {Callback $context debug write $line}] != 3} {
        puts $irc(socket) $line
    }
}

# -------------------------------------------------------------------------

package provide picoirc 0.5.2

# -------------------------------------------------------------------------
