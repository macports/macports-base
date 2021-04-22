#!/usr/bin/env tclsh
## -*- tcl -*-
# saslclient.tcl - Copyright (C) 2005 Pat Thoyts <patthoyts@users.sf.net>
#
# This is a SMTP SASL test client. It connects to a SMTP server and uses 
# the STARTTLS feature if available to switch to a secure link before 
# negotiating authentication using SASL.
#
# $Id: saslclient.tcl,v 1.5 2009/01/30 04:18:14 andreas_kupries Exp $

package require SASL
package require base64
catch {package require SASL::NTLM}

variable user
array set user {username "" password ""}
if {[info exists env(http_proxy_user)]} {
    set user(username) $env(http_proxy_user)
} else {
    if {[info exists env(USERNAME)]} {
        set user(username) $env(USERNAME)
    }
}
if {[info exists env(http_proxy_pass)]} {
    set user(password) $env(http_proxy_pass)
}


# SASLCallback --
#
#	This procedure is called from the SASL library when it needs to get
#	information from the client application. The callback can be specified
#	with additional data elements and when called the SASL library will
#	append the SASL context, the command and possibly additional arguments.
#	The command specified the type of information needed.
#	So far we have:
#	  login     users authorization identity (can be same as username).
#	  username  users authentication identity
#	  password  users authentication token
#	  realm     the authentication realm (domain for NTLM)
#	  hostname  the client's idea of its hostname (for NTLM)
#
proc SASLCallback {clientblob chan context command args} {
    global env
    variable user
    upvar #0 $context ctx
    switch -exact -- $command {
        login { 
            return "";# means use the authentication id
        }
        username {
            return $user(username)
        }
        password { 
            return $user(password)
        }
        realm {
            if {$ctx(mech) eq "NTLM"} {
                return "$env(USERDOMAIN)"
            } else {
                return [lindex [fconfigure $chan -peername] 1]
            }
        }
        hostname {
            return [info host]
        }
        default {
            return -code error "oops: client needs to write $command"
        }
    }
}

# SMTPClient --
#
#	This implements a minimal SMTP client state engine. It will
#	do enough of the SMTP protocol to initiate a SSL/TLS link and
#	negotiate SASL parameters. Then it terminates.
#
proc Callback {chan eof line} {
    variable mechs
    variable tls
    variable ctx
    if {![info exists mechs]} {set mechs {}}
    if {$eof} { set ::forever 1; return }
    puts "> $line"
    switch -glob -- $line {
        "220 *" { 
            if {$tls} {
                set tls 0
                puts "| switching to SSL"
                fileevent $chan readable {}
                tls::import $chan
                catch {tls::handshake $chan} msg
                set mechs {}
                fileevent $chan readable [list Read $chan ::Callback]
            }
            Write $chan "EHLO [info host]" 
        }
        "250 *" {
            if {$tls} {
                Write $chan STARTTLS
            } else {
                set supported [SASL::mechanisms]
                puts "SASL mechanisms: $mechs\ncan do $supported"
                foreach mech $mechs {
                    if {[lsearch -exact $supported $mech] != -1} {
                        
                        set ctx [SASL::new \
                                     -mechanism $mech \
                                     -callback [list [namespace origin SASLCallback] "client blob" $chan]]
                        Write $chan "AUTH $mech"
                        return
                    }
                }
                puts "! No matching SASL mechanism found"
            }
        }
        "250-AUTH*" {
            set line [string trim [string range $line 9 end]]
            set mechs [concat $mechs [split $line]]
        }
        "250-STARTTLS*" {
            if {![catch {package require tls}]} {
                set tls 1
            }
        }
        "235 *" {
            SASL::cleanup $ctx
            Write $chan "QUIT" 
        }
        "334 *" {
            set challenge [string range $line 4 end]
            set e [string range $challenge end-5 end]
            puts "? '$e' [binary scan $e H* r; set r]"
            if {![catch {set dec [base64::decode $challenge]}]} {
                set challenge $dec
            }

            set mech [set [subst $ctx](mech)]
            #puts "> $challenge"
            if {$mech eq "NTLM"} {puts ">CHA [SASL::NTLM::Debug $challenge]"}
            set code [catch {SASL::step $ctx $challenge} err]
            if {! $code} {
                set rsp [SASL::response $ctx]
                # puts "< $rsp"
                if {$mech eq "NTLM"} {puts "<RSP [SASL::NTLM::Debug $rsp]"}
                Write $chan [join [base64::encode $rsp] {}]
            } else {
                puts stderr "sasl error: $err"
                Write $chan "QUIT"
            }
        }
        "535*" {
            Write $chan QUIT
        }
        default {
        }
    }
}

# Write --
#
#	Write data to the socket channel with logging.
#
proc Write {chan what} {
    puts "< $what"
    puts $chan $what
    return
}

# Read --
#
#	fileevent handler reads data when available from the network socket
#	and calls the specified callback when it has recieved a complete line.
#
proc Read {chan callback} {
    if {[eof $chan]} {
        fileevent $chan readable {}
        puts stderr "eof"
        eval $callback [list $chan 1 {}]
        return
    }
    if {[gets $chan line] != -1} {
        eval $callback [list $chan 0 $line]
    }
    return
}

# connect -- 
#
#	Open an SMTP session to test out the SASL implementation.
#
proc connect { server port {username {}} {passwd {}}} {
    variable mechs ; set mechs {}
    variable tls  ; set tls 0

    variable user
    if {$username ne {}} {set user(username) $username}
    if {$passwd ne {}} {set user(password) $passwd}

    puts "Connect to $server:$port"
    set sock [socket $server $port]
    fconfigure $sock -buffering line -blocking 1 -translation {auto crlf}
    fileevent $sock readable [list Read $sock ::Callback]
    after 6000 {puts timeout ; set ::forever 1}
    vwait ::forever
    catch {close $sock}
    return
}

if {!$tcl_interactive} {
    catch {eval ::connect $argv} res
    puts $res
}
