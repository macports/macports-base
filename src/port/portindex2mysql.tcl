#!/usr/bin/tclsh
# PortIndex2MySQL.tcl
# Kevin Van Vechten | kevin@opendarwin.org
# 3-Oct-2002
#
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
# 3. Neither the name of the copyright holder nor the names of contributors
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

package require darwinports
load /opt/local/lib/libmysqltcl.dylib

dportinit

set db [mysqlconnect -user darwinports -password woot -db darwinports]

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

mysqlexec $db "DROP TABLE log"
mysqlexec $db "CREATE TABLE IF NOT EXISTS log (activity VARCHAR(255), activity_time TIMESTAMP(14))"
mysqlexec $db "INSERT INTO log VALUES ('update', NOW())"

mysqlexec $db "DROP TABLE portfiles"
mysqlexec $db "CREATE TABLE portfiles (name VARCHAR(255) PRIMARY KEY NOT NULL, path VARCHAR(255), version VARCHAR(255),  description TEXT)"

mysqlexec $db "DROP TABLE IF EXISTS categories"
mysqlexec $db "CREATE TABLE categories (portfile VARCHAR(255), category VARCHAR(255), is_primary INTEGER)"

mysqlexec $db "DROP TABLE IF EXISTS maintainers"
mysqlexec $db "CREATE TABLE maintainers (portfile VARCHAR(255), maintainer VARCHAR(255), is_primary INTEGER)"

mysqlexec $db "DROP TABLE IF EXISTS dependencies"
mysqlexec $db "CREATE TABLE dependencies (portfile VARCHAR(255), library VARCHAR(255))"

mysqlexec $db "DROP TABLE IF EXISTS variants"
mysqlexec $db "CREATE TABLE variants (portfile VARCHAR(255), variant VARCHAR(255))"

mysqlexec $db "DROP TABLE IF EXISTS platforms"
mysqlexec $db "CREATE TABLE platforms (portfile VARCHAR(255), platform VARCHAR(255))"

if {[catch {set ports [dportsearch ".+"]} errstr]} {
	puts "port search failed: $errstr"
	exit 1
}

foreach {name array} $ports {
	array unset portinfo
	array set portinfo $array
	set portname [mysqlescape $portinfo(name)]
	if {[info exists portinfo(version)]} {
		set portversion [mysqlescape $portinfo(version)]
	} else {
		set portversion ""
	}
	set portdir [mysqlescape $portinfo(portdir)]
	if {[info exists portinfo(description)]} {
		set description [mysqlescape $portinfo(description)]
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
	mysqlexec $db $sql

	set primary 1
	foreach category $categories {
		set category [mysqlescape $category]
		set sql "INSERT INTO categories VALUES ('$portname', '$category', $primary)"
		#puts "$sql"
		mysqlexec $db $sql
		set primary 0
	}
	
	set primary 1
	foreach maintainer $maintainers {
		set maintainer [mysqlescape $maintainer]
		set sql "INSERT INTO maintainers VALUES ('$portname', '$maintainer', $primary)"
		#puts "$sql"
		mysqlexec $db $sql
		set primary 0
	}

	foreach lib $depends_lib {
		set lib [mysqlescape $lib]
		set sql "INSERT INTO dependencies VALUES ('$portname', '$lib')"
		#puts "$sql"
		mysqlexec $db $sql
	}

	foreach variant $variants {
		set variant [mysqlescape $variant]
		set sql "INSERT INTO variants VALUES ('$portname', '$variant')"
		#puts "$sql"
		mysqlexec $db $sql
	}

	foreach platform $platforms {
		set platform [mysqlescape $platform]
		set sql "INSERT INTO platforms VALUES ('$portname', '$platform')"
		#puts "$sql"
		mysqlexec $db $sql
	}

}


mysqlclose $db
mysqlclose
