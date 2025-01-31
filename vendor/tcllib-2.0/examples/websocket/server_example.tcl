#!/bin/env tclsh
# Example websocket server from anonymous user at
# https://core.tcl-lang.org/tcllib/tktview?name=0dd2a66f08

package require websocket

::websocket::loglevel debug
set srvSock [socket -server handleConnect 8080]

# 1. declare the (tcp) server-socket as a websocket server
::websocket::server $srvSock
# 2. register callback
::websocket::live $srvSock / wsLiveCB

# the usual tcl-tcp stuff (I don't (want to) use an http server package)

proc handleConnect {client_socket IP_address port} {
    puts "handleConnect"
    puts "============="
    puts "IP_address: $IP_address"
    puts "port: $port\n"
    fileevent $client_socket readable [list handleRead $client_socket]
}



proc handleRead {client_socket} {
    global srvSock
    chan configure $client_socket -translation crlf
    set hdrs {}

    gets $client_socket line

    puts "HTTP HEADERS"
    puts "============"
    puts $line

    while {[gets $client_socket header_line]>=0 && $header_line ne ""} {

        puts $header_line
        if {[regexp -expanded {^( [^\s:]+ ) \s* : \s* (.+)} $header_line -> header_name header_value]} {
            lappend hdrs $header_name $header_value
        } else {
            break
        }
    }

    puts "\n"


    # Now have the HTTP GET headers
    # 3. let's check valid

    if {[::websocket::test $srvSock $client_socket / $hdrs]} {
        puts "Incoming websocket connection received"
        # 4. upgrade the socket
        ::websocket::upgrade $client_socket
        # from now the wsLiveCB will be called (not anymore handleRead).
    } else {
        close $client_socket
    }
}

proc wsLiveCB {client_socket type_of_event data_received} {
    puts "
    inside wsLiveCB handler
    =======================
    client_socket: $client_socket
    type_of_event: $type_of_event
    data_received: $data_received\n"

    switch $type_of_event {
        connect { }
        disconnect { }
        text {
            ::websocket::send $client_socket text "The server received '$data_received'"
        }
        binary {}
        error {}
        close { }
        timeout { }
        ping {}
        pong {}
    }

}


vwait forever
