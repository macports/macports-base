# darwinports_index.tcl
#
# Copyright (c) 2004 Apple Computer, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Computer, Inc. nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# 31-Mar-2004
# Kevin Van Vechten <kevin@opendarwin.org>
#

package provide darwinports_index 1.0

namespace eval darwinports_index {
	variable has_sqlite {}
}

proc dports_index_init {} {
	global darwinports_index::has_sqlite darwinports::prefix
	if {$darwinports_index::has_sqlite == 1 ||
		[file exists ${darwinports::prefix}/lib/tclsqlite.dylib]} {
		load ${darwinports::prefix}/lib/tclsqlite.dylib Sqlite
		set darwinports_index::has_sqlite 1
	} else {
		return -code error "Sqlite must be installed to use a remote index.  Use the tclsqlite port."
	}
}



# portindex_sync
# Interact with the remote index at the specified URL.
# Replays the SQL transactions contained in the remote
# index file into a local database, creating it if it
# does not yet exist.  If it does already exist, only
# the transactions newer than the last sync will be
# downloaded and replayed.
#
# portdbpath - the path to which the local database should
#              be stored.  "portindex/" and a unique hash based
#              on the url will be appended to this path.
# url        - the url of the remote index to synchronize with

proc dports_index_sync {portdbpath url} {
	dports_index_init

	set indexpath [file join $portdbpath portindex]
	set indexpath [file join $indexpath [regsub -all -- {[^A-Za-z0-9._]} $url {-}]]
	if {[catch {file mkdir $indexpath} result]} {
		return -code error "$indexpath could not be created: $result"
	}

	set oldpath [pwd]
	cd $indexpath


	# If the database didn't exist, initialize it.
	# The schema is available on the server in the initialize.sql file.
	if {![file exists [file join $indexpath database.sqlite]]} {
		puts "Initializing portindex"
		exec curl --silent -O "$url/index/initialize.sql"
		# XXX detect curl failures
		
		set fd [open initialize.sql r]
		set sql {}
		while {[gets $fd line] >= 0} {
			append sql " $line\n"
		}
		close $fd
		# Database file has the name database.sqlite
		sqlite DB database.sqlite
		DB eval $sql
		DB eval "CREATE TABLE priv_data (keyword text, value int);"
		DB eval "INSERT INTO priv_data (keyword, value) VALUES ('last_index', 1);"
		DB eval "INSERT INTO priv_data (keyword, value) VALUES ('last_trans', 0);"
		DB close
	}

	# Database file has the name database.sqlite
	sqlite DB database.sqlite

	##
	# Download any new files
	##

	# Get the last downloaded file index out of the database.
	set start_index [DB eval "SELECT value FROM priv_data WHERE keyword='last_index';"]

	# Get the current high-water mark from the server.
	exec curl --silent -O "$url/index/.last_index"
	# XXX detect curl failures
	set fd [open ".last_index" r]
	gets $fd last_index
	# XXX should validate the contents of $last_index
	close $fd
	# Re-fetch the last file we fetched (transactions may have
	# been appended to it) and any new files.
	for {set i $start_index} {$i <= $last_index} {incr i} {
		puts "Fetching portindex-$i"
		exec curl --silent -O "$url/index/portindex-$i.sql"
		# XXX detect curl failures
		DB eval "UPDATE priv_data SET value=$i WHERE keyword='last_index';\n"
	}

	##
	# Replay the transactions
	##

	# Get the last transaction ID out of the database.
	set last_trans [DB eval "SELECT value FROM priv_data WHERE keyword='last_trans';"]

	# Iterate through the files we just downloaded
	for {set i $start_index} {$i <= $last_index} {incr i} {
		puts "Processing portindex-$i"
		set fd [open "portindex-$i.sql" r]
		set sql {}
		while {[gets $fd line] >= 0} {
			append sql " $line\n"	
			if {[regexp -- {^-- END TRANSACTION #([0-9]+)} $line unused trans_id] == 1} {
				# If this is a transaction we have not seen before, commit it.
				# Also update the last transaction number.
				if {$trans_id > $last_trans} {
					set last_trans $trans_id
					append sql " UPDATE priv_data SET value=$last_trans WHERE keyword='last_trans';\n"
					DB eval $sql
				}
				set sql {}
			}
		}
		close $fd
	}

	# Clean Up
	DB close
	cd $oldpath
}
