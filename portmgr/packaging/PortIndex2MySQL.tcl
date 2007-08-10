#!/usr/bin/env tclsh
#
# PortIndex2MySQL.tcl
# Kevin Van Vechten | kevin@opendarwin.org
# 3-Oct-2002
# Juan Manuel Palacios | jmpp@macports.org
# 30-Jul-2007
# $Id$
#
# Copyright (c) 2007 Juan Manuel Palacios, MacPorts Team.
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


# Load macports1.0 so that we can use some of its procs and the portinfo array.
catch {source \
	   [file join "@TCL_PACKAGE_DIR@" macports1.0 macports_fastload.tcl]}
package require macports

# Initialize MacPorts to find the sources.conf file, wherefrom we'll
# get the PortIndex that'll feed the database.
mportinit


# Procedure to catch the database password from a protected file.
proc getpasswd {passwdfile} {
    if {[catch {open $passwdfile r} passwdfile_fd]} {
        ui_error "${::errorCode}: $passwdfile_fd"
        exit 1
    }
    if {[gets $passwdfile_fd passwd] <= 0} {
        ui_error "No password found in $passwdfile!"
        exit 1
    }
    close $passwdfile_fd
    return $passwd
}

# Needed escaping for some strings output as sql statements.
proc sql_escape {str} {
        regsub -all -- {'} $str {\\'} str
        regsub -all -- {"} $str {\\"} str
        regsub -all -- {\n} $str {\\n} str
        return $str
}


# Abstraction variables:
set sqlfile [file join /tmp ports.sql]
set dbcmd [macports::findBinary mysql5]
set dbname macports
set passwdfile [file join . password_file]
set dbpasswd [getpasswd $passwdfile]
set dbcmdargs "$dbname --password=$dbpasswd"


# Flat text file to which sql statements are written.
if {[catch {open $sqlfile w+} sqlfile_fd]} {
    ui_error "${::errorCode}: $sqlfile_fd"
    exit 1
}


# Initial creation of database tables: log, portfiles, categories, maintainers, dependencies, variants and platforms.
# Do we need any other?
puts $sqlfile_fd "DROP TABLE log"
puts $sqlfile_fd "CREATE TABLE IF NOT EXISTS log (activity VARCHAR(255), activity_time TIMESTAMP(14))"
puts $sqlfile_fd "INSERT INTO log VALUES ('update', NOW())"

puts $sqlfile_fd "DROP TABLE portfiles"
puts $sqlfile_fd "CREATE TABLE portfiles (name VARCHAR(255) PRIMARY KEY NOT NULL, path VARCHAR(255), version VARCHAR(255),  description TEXT)"

puts $sqlfile_fd "DROP TABLE IF EXISTS categories"
puts $sqlfile_fd "CREATE TABLE categories (portfile VARCHAR(255), category VARCHAR(255), is_primary INTEGER)"

puts $sqlfile_fd "DROP TABLE IF EXISTS maintainers"
puts $sqlfile_fd "CREATE TABLE maintainers (portfile VARCHAR(255), maintainer VARCHAR(255), is_primary INTEGER)"

puts $sqlfile_fd "DROP TABLE IF EXISTS dependencies"
puts $sqlfile_fd "CREATE TABLE dependencies (portfile VARCHAR(255), library VARCHAR(255))"

puts $sqlfile_fd "DROP TABLE IF EXISTS variants"
puts $sqlfile_fd "CREATE TABLE variants (portfile VARCHAR(255), variant VARCHAR(255))"

puts $sqlfile_fd "DROP TABLE IF EXISTS platforms"
puts $sqlfile_fd "CREATE TABLE platforms (portfile VARCHAR(255), platform VARCHAR(255))"


# Load every port in the index through a search matching everything.
if {[catch {set ports [mportsearch ".+"]} errstr]} {
	ui_error "port search failed: $errstr"
	exit 1
}

# Iterate over each matching port, extracting its information from the
# portinfo array.
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
        if {[info exists portinfo(depends_build)]} {
                set depends_build $portinfo(depends_build)
        } else {
                set depends_build ""
        }
	if {[info exists portinfo(depends_lib)]} {
		set depends_lib $portinfo(depends_lib)
	} else {
		set depends_lib ""
	}
        if {[info exists portinfo(depends_run)]} {
                set depends_run $portinfo(depends_run)
        } else {
                set depends_run ""
        }
	if {[info exists portinfo(platforms)]} {
		set platforms $portinfo(platforms)
	} else {
		set platforms ""
	}

	puts $sqlfile_fd "INSERT INTO portfiles VALUES ('$portname', '$portdir', '$portversion', '$description')"

	set primary 1
	foreach category $categories {
		set category [sql_escape $category]
		puts $sqlfile_fd "INSERT INTO categories VALUES ('$portname', '$category', $primary)"
		incr primary
	}
	
	set primary 1
	foreach maintainer $maintainers {
		set maintainer [sql_escape $maintainer]
		puts $sqlfile_fd "INSERT INTO maintainers VALUES ('$portname', '$maintainer', $primary)"
		incr primary
	}

        foreach build_dep $depends_build {
            set build_dep [sql_escape $build_dep]
            puts $sqlfile_fd "INSERT INTO dependencies VALUES ('$portname', '$build_dep')"
        }

	foreach lib $depends_lib {
		set lib [sql_escape $lib]
		puts $sqlfile_fd "INSERT INTO dependencies VALUES ('$portname', '$lib')"
	}

        foreach run_dep $depends_run {
            set run_dep [sql_escape $run_dep]
            puts $sqlfile_fd "INSERT INTO dependencies VALUES ('$portname', '$run_dep')"
        }

	foreach variant $variants {
		set variant [sql_escape $variant]
		puts $sqlfile_fd "INSERT INTO variants VALUES ('$portname', '$variant')"
	}

	foreach platform $platforms {
		set platform [sql_escape $platform]
		puts $sqlfile_fd "INSERT INTO platforms VALUES ('$portname', '$platform')"
	}

}


# Pipe the contents of the generated sql file to the database command,
# reading from the file descriptor for the raw sql file to assure completeness.
if {[catch {seek $sqlfile_fd 0 start} errstr]} {
    ui_error "${::errorCode}: $errstr"
    exit 1
}
if {[catch {exec $dbcmd $dbcmdargs <@ $sqlfile_fd} errstr]} {
    ui_error "${::errorCode}: $errstr"
    exit 1
}


# And we're done regen'ing the MacPorts dabase! (cleanup)
close $sqlfile_fd
file delete -force $sqlfile
