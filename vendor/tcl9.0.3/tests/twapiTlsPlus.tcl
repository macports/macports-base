# Module twapiTlsPlus
#
# Temporary wrapper for package twapi, to expose the same API as package tls.
# - Command twapiTlsPlus::socket, cf. tls::socket, replacement for ::socket, for
#   use with http::register.
# - Variable twapiTlsPlus::socketCmd, cf. tls::socketCmd, holds the value of the
#   callback command used by twapi to open a socket.
#
# Intended to allow twapi TLS to use an https proxy server, and a background
# thread for evaluation of ::socket.
#
# For twapiTlsPlus to work correctly, twapi*/tls.tcl must be edited so that
#-        set so [$socketcmd {*}$socket_args {*}$args]
#+        set so [{*}$socketcmd {*}$socket_args {*}$args]

package require http
package require twapi

namespace eval twapiTlsPlus {
    variable socketCmd [::twapi::tls_socket_command]
    namespace export socket
}

# Proc twapiTlsPlus::socket
# Replacement for ::socket, use with http::register.

proc twapiTlsPlus::socket {args} {
    variable socketCmd

    set targ [lsearch -exact $args -type]
    if {$targ != -1} {
	set token [lindex $args $targ+1]
	set args [lreplace $args $targ $targ+1 -socketcmd [list {*}$socketCmd -type $token]]
    }
    ::twapi::tls_socket {*}$args
}

# Variable twapi::tls::_socket_cmd does it.

proc twapiTlsPlus::TraceSocketCmd {args} {
    variable socketCmd
    ::twapi::tls_socket_command $socketCmd
    return
}

trace add variable ::twapiTlsPlus::socketCmd write ::twapiTlsPlus::TraceSocketCmd

package provide twapiTlsPlus 0.1
