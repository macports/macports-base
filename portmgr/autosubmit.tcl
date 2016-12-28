#!/usr/bin/env tclsh

package require macports
package require sqlite3

proc open_db { db_file } {
	# Open/create our database
	sqlite3 db $db_file
	db timeout 10000
	if { [llength [db eval {pragma table_info('SubmitInfo')}]] == 0 } {
		db eval {
			create table SubmitInfo (
				porturl text unique,
				portname text,
				last_mod_date datetime,
				submitted_mod_date datetime,
				submit_date datetime
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


proc submit_ports {} {
	global prefix submit_options verbose

	if {[catch {set res [mportlistall]} result]} {
		puts "port search failed: $result"
		exit 1
	}
	
	foreach {name array} $res {
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
			set portdir [file normalize [macports::getportdir $porturl]]
		}
		set portfile "${portdir}/Portfile"
		if { $verbose } { puts "checking ${name}" }
	
		if {[file readable $portfile]} {
			set mod_date [sql_date [file mtime $portfile]]
			set cur_date [sql_date [clock seconds]]
			
			set post ""
			set none 1
			db eval { select * from submitinfo where porturl=$porturl } values {
				set none 0
				
				if { $values(last_mod_date) eq "" || $values(last_mod_date) != $mod_date } {
				
					# The last_mod_date has changed, so just update it to provide
					# hysteresis for file changes
					if { $verbose } { puts "    update ${name} mod date to $mod_date" }
					set post { update submitinfo set last_mod_date=$mod_date where porturl=$porturl }				
				
				} elseif { $values(submitted_mod_date) != $mod_date } {
				
					# last_mod_date is correct and stable, but has not yet been submitted
					# so let's submit it
	
					# Open the port
					set err 0
					if {[catch {set workername [mportopen $porturl [array get submit_options]]} result]} {
						ui_debug $::errorInfo
						puts "Unable to open port: $result"
						set err 1
					}
	
					# Submit the port
					if { !$err && [catch {set result [mportexec $workername submit]} result]} {
						ui_debug $::errorInfo
						puts "Unable to execute port: $result"
						set err 1
					}
			
					# Close the port
					mportclose $workername
					
					# Update the date in the database for this item
					if { !$err && !$result } {
						set post { update submitinfo set submitted_mod_date=$mod_date, submit_date=$cur_date where porturl=$porturl }
					}
				} else {
				
					# The port has already been submitted
					if { $verbose } { puts "   submission up to date as of $values(submit_date)" }
				}
				
			}
			
			if { $none } {
				# No record yet, so just create a record for this port
				# Do nothing else yet to provide hysteresis for file changes
				if { $verbose } { puts "    set ${name} mod date to $mod_date" }
				set post { insert into submitinfo (porturl,portname,last_mod_date) values ($porturl, $name, $mod_date) }				
			}
			
			# Do update or insert post processing
			if { $post ne "" } {
				db eval $post
			}
		}
		
	}
}


# Globals
set SUBMITTER_NAME "autosubmit"
set SUBMITTER_EMAIL "autosubmit@macports.org"
array set submit_options "submitter_name $SUBMITTER_NAME submitter_email $SUBMITTER_EMAIL"

# Do argument processing
set verbose 0
if { [lsearch $argv -v] >= 0 } {
	set verbose 1
}

# Initialize mports api
mportinit

# Submit ports
set db_file [file normalize "${macports::macports_user_dir}/autosubmit.db"]
if { $verbose } { puts "Using database at $db_file" }
open_db $db_file
submit_ports
close_db
