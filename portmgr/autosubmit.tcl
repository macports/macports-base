#!/bin/sh
#\
exec /usr/bin/tclsh "$0" "$@"

# Updates the distfiles to current distfiles by deleting old stuff.
# Uses the database.
# $Id: portmirror.tcl 24631 2007-04-29 05:35:59Z jmpp@macports.org $

# TODO:
#	- autoconfigurize the tcl path
#	- don't use a hard-coded db location
#	- search path is hardcoded at the moment


catch {source \
	[file join "@TCL_PACKAGE_DIR@" darwinports1.0 darwinports_fastload.tcl]}
package require darwinports
package require sqlite3


proc open_db {} {
	# Open/create our database
	sqlite3 db "/Users/jberry/autosubmit.sqlite3"
	db timeout 10000
	if { [llength [db eval {pragma table_info('SubmitInfo')}]] == 0 } {
		db eval {
			create table SubmitInfo (
				porturl text unique,
				lastsubmit datetime
			)
		}
	}
}


proc close_db {} {
	db close
}


proc sql_date { datetime } {
	return [clock format $datetime -format "%Y-%m-%d %H:%M:%S"]
}


proc check_ports {} {
	if {[catch {set res [dportsearch "^commons-.*\$"]} result]} {
		puts "port search failed: $result"
		exit 1
	}
	
	foreach {name array} $res {
		global prefix
		array unset portinfo
		array set portinfo $array
	
		if {![info exists portinfo(porturl)]} {
			puts stderr "Internal error: no porturl for $name"
			continue
		}
		
		set porturl $portinfo(porturl)
		if { 0 != [regexp {file://(.*)} $porturl match path] } {
			set portdir [file normalize $path]
		} else {
			set portdir [file normalize [darwinports::getportdir $porturl]]
		}
		set portfile "${portdir}/Portfile"
		puts "checking ${name}"
	
		if {[file readable $portfile]} {
			set moddate [sql_date [file mtime $portfile]]
			set values [db eval { select * from submitinfo where porturl=$porturl and $moddate <= lastsubmit }]
			if { [llength $values] == 0 } {
				puts "submitting ${name}"
				
				if {[catch {set workername [dportopen $porturl]} result]} {
					global errorInfo
					ui_debug "$errorInfo"
					puts "Unable to open port: $result"
					continue
				}
				
				if {[catch {set result [dportexec $workername submit]} result]} {
					global errorInfo
					dportclose $workername
					ui_debug "$errorInfo"
					puts "Unable to execute port: $result"
					continue
				}
		
				dportclose $workername
		
				# Update the date in the database for this item
				db eval { insert or replace into submitinfo (porturl,lastsubmit) values ($porturl, $moddate) }
			}
		}
		
	}
}


# Initialize dports api
dportinit
open_db
check_ports
close_db