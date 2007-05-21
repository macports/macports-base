#!/usr/bin/env tclsh
# PortIndex2MySQL.tcl
# Kevin Van Vechten | kevin@opendarwin.org
# 3-Oct-2002
# $Id$
#
# Copyright (c) 2003 Apple Computer, Inc.
# Copyright (c) 2002 Kevin Van Vechten. 
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


catch {source \
	   [file join "@TCL_PACKAGE_DIR@" darwinports1.0 darwinports_fastload.tcl]}
package require darwinports

proc ui_prefix {priority} {
	return ""
}

proc ui_channels {priority} {
	return {}
}

# This should be a command line argument.
# if true, use_db insructs the script to insert directly into a database
# otherwise, sql statements will be printed to stdout.
set use_db ""

array set ui_options {}
array set global_options {}
array set global_variations {}
dportinit ui_options global_options global_variations

if {$use_db != ""} {
    load @PREFIX@/lib/libmysqltcl.dylib
    set db [mysqlconnect -user darwinports -password woot -db darwinports]
} else {
    set db ""
}

proc sql_exec {db sql} {
    if {$db != ""} {
        mysqlexec $db $sql
    } else {
        puts "${sql};"
    }
}

proc sql_escape {str} {
    global use_db
    if {$use_db != ""} {
        return [msyqlescape $str]
    } else {
        regsub -all -- {'} $str {\\'} str
        regsub -all -- {"} $str {\\"} str
        regsub -all -- {\n} $str {\\n} str
        return $str
    }
}

# CREATE TABLE portfiles (name VARCHAR(255) PRIMARY KEY NOT NULL, 
#  path VARCHAR(255),
#  version VARCHAR(255),
#  description TEXT);

# CREATE TABLE categories (portfile VARCHAR(255), 
#  category VARCHAR(255), 
#  primary INTEGER);

# CREATE TABLE maintainers (portfile VARCHAR(255),
#  maintainer VARCHAR(255),
#  primary INTEGER);

sql_exec $db "DROP TABLE log"
sql_exec $db "CREATE TABLE IF NOT EXISTS log (activity VARCHAR(255), activity_time TIMESTAMP(14))"
sql_exec $db "INSERT INTO log VALUES ('update', NOW())"

sql_exec $db "DROP TABLE portfiles"
sql_exec $db "CREATE TABLE portfiles (name VARCHAR(255) PRIMARY KEY NOT NULL, path VARCHAR(255), version VARCHAR(255),  description TEXT)"

sql_exec $db "DROP TABLE IF EXISTS categories"
sql_exec $db "CREATE TABLE categories (portfile VARCHAR(255), category VARCHAR(255), is_primary INTEGER)"

sql_exec $db "DROP TABLE IF EXISTS maintainers"
sql_exec $db "CREATE TABLE maintainers (portfile VARCHAR(255), maintainer VARCHAR(255), is_primary INTEGER)"

sql_exec $db "DROP TABLE IF EXISTS dependencies"
sql_exec $db "CREATE TABLE dependencies (portfile VARCHAR(255), library VARCHAR(255))"

sql_exec $db "DROP TABLE IF EXISTS variants"
sql_exec $db "CREATE TABLE variants (portfile VARCHAR(255), variant VARCHAR(255))"

sql_exec $db "DROP TABLE IF EXISTS platforms"
sql_exec $db "CREATE TABLE platforms (portfile VARCHAR(255), platform VARCHAR(255))"

if {[catch {set ports [dportsearch ".+"]} errstr]} {
	puts "port search failed: $errstr"
	exit 1
}

foreach {name array} $ports {
	array unset portinfo
	array set portinfo $array
	set portname [sql_escape $portinfo(name)]
	if {[info exists portinfo(version)]} {
		set portversion [sql_escape $portinfo(version)]
	} else {
		set portversion ""
	}
	set portdir [sql_escape $portinfo(portdir)]
	if {[info exists portinfo(description)]} {
		set description [sql_escape $portinfo(description)]
	} else {
		set description ""
	}
	if {[info exists portinfo(categories)]} {
		set categories $portinfo(categories)
	} else {
		set categories ""
	}
	if {[info exists portinfo(maintainers)]} {
		set maintainers $portinfo(maintainers)
	} else {
		set maintainers ""
	}
	if {[info exists portinfo(variants)]} {
		set variants $portinfo(variants)
	} else {
		set variants ""
	}
	if {[info exists portinfo(depends_lib)]} {
		set depends_lib $portinfo(depends_lib)
	} else {
		set depends_lib ""
	}
	if {[info exists portinfo(platforms)]} {
		set platforms $portinfo(platforms)
	} else {
		set platforms ""
	}
		
	set sql "INSERT INTO portfiles VALUES ('$portname', '$portdir', '$portversion', '$description')"
	#puts "$sql"
	sql_exec $db $sql

	set primary 1
	foreach category $categories {
		set category [sql_escape $category]
		set sql "INSERT INTO categories VALUES ('$portname', '$category', $primary)"
		#puts "$sql"
		sql_exec $db $sql
		set primary 0
	}
	
	set primary 1
	foreach maintainer $maintainers {
		set maintainer [sql_escape $maintainer]
		set sql "INSERT INTO maintainers VALUES ('$portname', '$maintainer', $primary)"
		#puts "$sql"
		sql_exec $db $sql
		set primary 0
	}

	foreach lib $depends_lib {
		set lib [sql_escape $lib]
		set sql "INSERT INTO dependencies VALUES ('$portname', '$lib')"
		#puts "$sql"
		sql_exec $db $sql
	}

	foreach variant $variants {
		set variant [sql_escape $variant]
		set sql "INSERT INTO variants VALUES ('$portname', '$variant')"
		#puts "$sql"
		sql_exec $db $sql
	}

	foreach platform $platforms {
		set platform [sql_escape $platform]
		set sql "INSERT INTO platforms VALUES ('$portname', '$platform')"
		#puts "$sql"
		sql_exec $db $sql
	}

}

if {$db != ""} {
    mysqlclose $db
    mysqlclose
}
