#!/usr/bin/env tclsh

# TODO:
#	- don't use a hard-coded db location

package require darwinports
package require sqlite3


proc open_db {} {
	# Open/create our database
	sqlite3 db "/Users/jberry/autosubmit.db"
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
	if {[catch {set res [dportsearch "^.*\$"]} result]} {
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
				
				# Open the port
				if {[catch {set workername [dportopen $porturl]} result]} {
					global errorInfo
					ui_debug "$errorInfo"
					puts "Unable to open port: $result"
					continue
				}
				
				# Submit the port
				if {[catch {set result [dportexec $workername submit]} result]} {
					global errorInfo
					dportclose $workername
					ui_debug "$errorInfo"
					puts "Unable to execute port: $result"
					
					# Cleanup
					dportclose $workername
					continue
				}
		
				# Close the port
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