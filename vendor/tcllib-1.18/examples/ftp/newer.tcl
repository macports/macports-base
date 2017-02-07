#!/usr/bin/env tclsh
## -*- tcl -*-

package require Tcl 8.3
package require ftp 2.0

if { [set conn [ftp::Open ftp.scriptics.com  anonymous xxxx]] != -1} {
    if {[ftp::Newer $conn /pub/tcl/httpd/tclhttpd.tar.gz /usr/local/src/tclhttpd.tgz]} {
	exec echo "New httpd arrived!" | mailx -s ANNOUNCE root
    }
    ftp::Close $conn
}

