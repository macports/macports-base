# macports_index.tcl
# $Id$
#
# Copyright (c) 2004 Apple Inc.
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
# 3. Neither the name of Apple Inc. nor the names of its contributors
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
# Kevin Van Vechten <kevin@opedarwin.org>
#

package provide macports_index 1.0

namespace eval macports::index {
	variable has_sqlite {}
}

proc macports::index::init {} {
	global macports::index::has_sqlite macports::prefix
	if {$macports::index::has_sqlite == 1 ||
		[file exists ${macports::prefix}/lib/tclsqlite.dylib]} {
		load ${macports::prefix}/lib/tclsqlite.dylib Sqlite
		set macports::index::has_sqlite 1
	} else {
		return -code error "Sqlite must be installed to use a remote index.  Use the tclsqlite port."
	}
}

proc macports::index::get_path {source} {
    global macports::portdbpath
    regsub {://} $source {.} source_dir
    regsub -all {/} $source_dir {_} source_dir
    return [file join $portdbpath sources $source_dir]
}


# macports::index::sync
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

proc macports::index::sync {portdbpath url} {
	macports::index::init

	set indexpath [macports::index::get_path $url]
	if {[catch {file mkdir $indexpath} result]} {
		return -code error "$indexpath could not be created: $result"
	}

	set oldpath [pwd]
	cd $indexpath
	
	# We actually use http:// as the transport mechanism
	set url [regsub -- {^mports} $url {http}]

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

# macports::index::search
#
# Searches the cached copy of the specified port index for
# the Portfile satisfying the given query.
#
# Todo -- in the future we may want to do an implicit "port sync"
# when this function is called.
#
# portdbpath - the path to which the local database should
#              be stored.  "portindex/" and a unique hash based
#              on the url will be appended to this path.
# url        - the url of the remote index to search
#
# attrs      - an array of the attributes to search for
#			   currently only "name" is supported.

proc macports::index::search {portdbpath url attrslist} {
	macports::index::init
	set indexpath [macports::index::get_path $url]

	if {![file exists $indexpath/database.sqlite]} {
		return -code error "Can't open index file for source $url. Have you synced your source indexes (port sync)?"
	}

	sqlite DB $indexpath/database.sqlite
	# Map some functions into the SQL namespace
	DB function regexp regexp
	
	# The guts of the search logic.
	# Precedence is as follows:
	# - If a name, version, and revision is specified return that single port.
	# - If a name and version is specified, return the highest revision
	# - If only a name is specified, return the highest revision of 
	#   all distinct name, version combinations.
	# - NOTE: it is an error to specify a revision without a version.

	set pids [list]
	array set attrs $attrslist
	if {[info exists attrs(name)]} {
		set name $attrs(name)

		# If version was not specified, find all distinct versions;
		# otherwise use the specified version.
		if {![info exists attrs(version)]} {
			set sql "SELECT version FROM ports WHERE regexp('--','$name',name) GROUP BY version ORDER BY version DESC"
			set versions [DB eval $sql]
		} else {
			set versions [list $attrs(version)]
		}
	
		# If revision was not specified, find the highest revision;
		# otherwise use the specified revision.
		if {![info exists attrs(revision)]} {
			foreach version $versions {
				set sql "SELECT max(revision) FROM ports WHERE regexp('--','$name',name) AND version LIKE '$version'"
				set revisions($version) [DB eval $sql]
			}
		} else {
			set revisions($version) $attrs(revision)
		}
		
		foreach version $versions {
			set sql "SELECT pid FROM ports WHERE regexp('--','$name',name) AND version LIKE '$version' AND revision LIKE '$revisions($version)'"
			lappend pids [DB eval $sql]
		}
	}
	
	# Historically mportsearch has returned a serialized list of arrays.
	# This is kinda gross and really needs to change to a more opaque
	# data type in the future, but to ease the transition we're it the old
	# way here.  For each port that matched the query, build up an array 
	# from the keywords table and append it to the list.

	set result [list]

	foreach pid $pids {
		set portinfo [list]
		set primary_key [DB eval "SELECT name,version,revision FROM ports WHERE pid=$pid"]
		set name [lindex $primary_key 0]
		set version [lindex $primary_key 1]
		set revision [lindex $primary_key 2]
		lappend portinfo name $name
		lappend portinfo version $version
		lappend portinfo revision $revision
		
		set auxiliary_keys [DB eval "SELECT keyword, value FROM keywords WHERE pid=$pid"]
		foreach {key value} $auxiliary_keys {
			# XXX - special case list types: categories, maintainers, master_sites
			lappend portinfo $key $value
		}
		
		# Craft a URL where the port can be found.
		lappend portinfo porturl $url/files/$name/$version/$revision/Portfile.tar.gz
		
		# Make a note of where this port came from.
		lappend portsource $url
		
		lappend result $name
		lappend result $portinfo
	}

	DB close

	return $result
}



# macports::index::fetch_port
#
# Checks for a locally cached copy of the port, or downloads the port
# from the specified URL.  The port is extracted into the current working
# directory along with a .mports_source file containing the url of the
# source the port came from.  (This can be later used as a default for
# "port submit")
#
# The cached portfiles are in the same directory as the cached remote index.
#
# TODO - the existing infrastructure only gives us a URL at this point,
# but we really ought to have an opaque handle to a port.  We want to
# get the source URL and the Portfile.tar.gz md5 from this opaque handle.

proc macports::index::fetch_port {url destdir} {
	global macports::sources
	
	set portsource ""
	set portname ""
	set portversion ""
	set portrevision ""
	
	# Iterate through the sources, to see which one this port is coming from.
	# If the port is not coming from a known source, return an error (for now).
	
	set indexpath ""
	set fetchpath ""
	foreach source $sources {
		if {[regexp -- "^$source" $url] == 1} {
			set portsource $source
			set indexpath [macports::index::get_path $source]
			
			# Extract the relative portion of the url, 
			# and append it to the indexpath, this is where
			# we will store the cached Portfile.
			set dir [file dirname [regsub -- "$source/?" $url {}]]

			# XXX: crude hack to get port name and version, should realy come from opaque port handle.
			set portname [lindex [file split $dir] 1]
			set portversion [lindex [file split $dir] 2]
			set portrevision [lindex [file split $dir] 3]

			set fetchpath [file join $indexpath $dir]
			break
		}
	}
	
	if {$indexpath == "" || $fetchpath == ""} {
		return -code error "Port URL has unknown source: $url"
	}
	
	if {[catch {file mkdir $fetchpath} result]} {
		return -code error $result
	}

	# If the portdir already exists, we don't bother extracting again.
	
	# Look to see if the file exists in our cache, if it does, attempt
	# to extract it into the temporary directory that we will build in.
	# If it does not exist, or if the tar extraction fails, then attempt
	# to fetch it again.


	set portdir [file join "$destdir" "$portname-$portversion"]

	if {[file exists $portdir]} {
		return $portdir
	}
	
	if {[catch {file mkdir $portdir} result]} {
		return -code error $result
	}

	set fetchfile [file join $fetchpath [file tail $url]]
	set retries 2
	while {$retries > 0} {
		if {[file exists $fetchfile]} {
			set oldcwd [pwd]
			cd $portdir
			
			if {[catch {exec tar -zxf $fetchfile} result]} {
				return -code error "Could not unpack port file: $result"
			}
			
			set fd [open ".mports_source" w]
			puts $fd "source: $portsource"
			puts $fd "port: $portname"
			puts $fd "version: $portversion"
			puts $fd "revision: $portrevision"
			close $fd
			
			cd $oldcwd
		} else {		
			# We actually use http:// as the transport mechanism
			set http_url [regsub -- {^mports} $url {http}]
			if {[catch {exec curl -L -s -S -o $fetchfile $http_url} result ]} {
				return -code error "Could not download port from remote index: $result"
			}
		}
		incr retries -1
	}
	
	return $portdir
}
