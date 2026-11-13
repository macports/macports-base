# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# Copyright (c) 2026 The MacPorts Project. See LICENSE for terms.

# Local HTTP regression tests for both libcurl polling backends.
# Run: tclsh curl-local.tcl /path/to/Pextlib.dylib [--head-cancel]

if {$argv eq {--server}} {
    set payload [string repeat 0123456789abcdef 4096]
    proc reply {fd method path} {
        global payload
        set status {200 OK}
        set body $payload
        if {$path eq "/missing"} {set status {404 Not Found}; set body missing}
        set failed [catch {
            fconfigure $fd -translation binary
            puts -nonewline $fd "HTTP/1.1 $status\r\nContent-Length: [string length $body]\r\nLast-Modified: Wed, 21 Oct 2015 07:28:00 GMT\r\nConnection: close\r\n\r\n"
            if {$method ne "HEAD"} {puts -nonewline $fd $body}
        } message]
        if {$failed && $path ne "/slow"} {puts stderr "HTTP test server: $message"}
        catch {close $fd}
    }
    proc readable {fd} {
        global requests
        while {[gets $fd line] >= 0} {
            if {![info exists requests($fd)]} {
                set requests($fd) [lrange [split $line] 0 1]
            } elseif {$line eq ""} {
                lassign $requests($fd) method path
                unset requests($fd)
                fileevent $fd readable {}
                if {$path eq "/slow"} {
                    after 1000 [list reply $fd $method $path]
                } else {
                    reply $fd $method $path
                }
                return
            }
        }
        if {[eof $fd]} {catch {close $fd}; unset -nocomplain requests($fd)}
    }
    proc accept {fd args} {
        fconfigure $fd -blocking 0 -buffering none -translation crlf
        fileevent $fd readable [list readable $fd]
    }
    set listener [socket -server accept -myaddr 127.0.0.1 0]
    puts [lindex [fconfigure $listener -sockname] 2]
    flush stdout
    fconfigure stdin -blocking 0
    fileevent stdin readable {if {[eof stdin]} {exit}; read stdin}
    vwait forever
}

load [lindex $argv 0]
proc assert {expression description} {
    if {![uplevel 1 [list expr $expression]]} {error "FAIL: $description"}
}
proc read_binary {path} {
    set fd [open $path rb]
    set data [read $fd]
    close $fd
    return $data
}
set server [open [list | [info nameofexecutable] [info script] --server] r+]
fconfigure $server -buffering line
gets $server port
assert {[string is integer -strict $port]} {HTTP server startup}
set url http://127.0.0.1:$port
set fd [file tempfile path]
close $fd
set payload [string repeat 0123456789abcdef 4096]
try {
    if {[llength [info commands time_connect]]} {
        assert {[time_connect 127.0.0.1 $port] >= 0} {TCP connection timing}
        assert {[catch {time_connect 127.0.0.1 macports-no-such-service}]} {invalid TCP service}
        assert {[time_connect 127.0.0.1 $port] >= 0} {connection timing after lookup failure}
    }
    for {set i 0} {$i < 3} {incr i} {
        curl fetch $url/payload $path
        assert {[read_binary $path] eq $payload} {complete payload on reused handle}
        assert {[curl getsize $url/payload] == [string length $payload]} {HEAD content length}
    }
    curl fetch --remote-time $url/payload $path
    assert {[read_binary $path] eq $payload} {remote-time preserves payload}
    assert {[file mtime $path] == 1445412480} {remote modification time}
    assert {[catch {curl fetch $url/missing $path}]} {HTTP error propagation}
    curl fetch $url/payload $path
    assert {[read_binary $path] eq $payload} {handle reuse after HTTP error}
    set commands [list [list curl fetch $url/slow $path]]
    if {"--head-cancel" in $argv} {lappend commands [list curl getsize $url/slow]}
    foreach command $commands {
        set token [after 0 {set ::pextlib::curl::cancelled 1}]
        set failed [catch {{*}$command} message]
        after cancel $token
        assert {$failed && [string match *cancelled* $message]} "Tcl cancellation during [lrange $command 0 1]: status=$failed, result=$message"
        assert {[curl getsize $url/payload] == [string length $payload]} {handle reuse after cancellation}
    }
    puts {PASS local curl: fetch, HEAD, remote time, HTTP errors, cancellation, handle reuse}
} finally {
    file delete -force $path
    close $server
}
