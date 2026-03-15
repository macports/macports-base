#!/bin/env tclsh
# Example websocket server from anonymous user at
# https://core.tcl-lang.org/tcllib/tktview?name=0dd2a66f08

package require websocket

::websocket::loglevel debug


oo::class create WebSocketServer {
    variable srvSock port

    constructor {port} {
        set srvSock [socket -server [list [namespace current]::my HandleConnect] $port]

        ::websocket::server $srvSock
        ::websocket::live $srvSock / [list [namespace current]::my WsLiveCB]
    }

    method port {} {
        return $port
    }

    method HandleConnect {client_socket IP_address port} {
        fileevent $client_socket readable [list [namespace current]::my HandleRead $client_socket]
    }

    method HandleRead {client_socket} {
        chan configure $client_socket -translation crlf
        set hdrs {}

        gets $client_socket line

        while {[gets $client_socket header_line]>=0 && $header_line ne ""} {

            if {[regexp -expanded {^( [^\s:]+ ) \s* : \s* (.+)} $header_line -> header_name header_value]} {
                lappend hdrs $header_name $header_value
            } else {
                break
            }
        }

        if {[::websocket::test $srvSock $client_socket / $hdrs]} {
            ::websocket::upgrade $client_socket
        }
    }

    method WsLiveCB {client_socket type_of_event data_received} {
        my on_$type_of_event $client_socket $data_received
    }

    method on_connect {client_socket data_received} {}
    method on_disconnect {client_socket data_received} {}
    method on_error {client_socket data_received} {}
    method on_close {client_socket data_received} {}
    method on_timeout {client_socket data_received} {}
    method on_binary {client_socket data_received} {}
    method on_text {client_socket data_received} {}
    method on_pong {client_socket data_received} {}

    forward send ::websocket::send

}

oo::class create ServerExample {
    superclass WebSocketServer

    method on_text {client_socket data_received} {
        my send $client_socket text "The server received '$data_received'"
    }
}

ServerExample new 8080
vwait forever
