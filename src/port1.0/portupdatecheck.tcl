# et:ts=4
# portupdatecheck.tcl
#
# $Id: portupdatecheck.tcl,v 1.1 2005/08/11 01:46:31 pguyot Exp $
#
# Copyright (c) 2005 Paul Guyot <pguyot@kallisys.net>,
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Computer, Inc. nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

package provide portupdatecheck 1.0
package require portutil 1.0

set com.apple.updatecheck [target_new com.apple.updatecheck updatecheck_main]
target_runtype ${com.apple.updatecheck} always
target_state ${com.apple.updatecheck} no
target_provides ${com.apple.updatecheck} updatecheck
target_requires ${com.apple.updatecheck} main
target_prerun ${com.apple.updatecheck} updatecheck_start

set_ui_prefix

# define options
options updatecheck.url updatecheck.type updatecheck.md5 updatecheck.name

# defaults
default updatecheck.url {$homepage}
default updatecheck.type url_mod_date
default updatecheck.md5 ""
default updatecheck.name {$name}

proc updatecheck_start {args} {
	global UI_PREFIX portname portversion portrevision variations portvariants
    
	if { ![info exists portvariants] } {
		set portvariants ""

		set vlist [lsort -ascii [array names variations]]

	 	# Put together variants in the form +foo+bar for the registry
		foreach v $vlist {
			if { ![string equal $v [option os.platform]] && ![string equal $v [option os.arch]] } {
				set portvariants "${portvariants}+${v}"
			}
		}
	}
}

proc updatecheck_main {args} {
	global updatecheck.url updatecheck.type updatecheck.md5 updatecheck.name
	global portname portpath workpath
	
	set updated 0

	set tempfile ${workpath}/updatecheck.TMP
	set port_moddate [file mtime ${portpath}/Portfile]
	
	# set the url depending on the type.
	if {${updatecheck.type} == "freshmeat"} {
		set updatecheck.url "http://freshmeat.net/projects-xml/${updatecheck.name}/${updatecheck.name}.xml"
		
		if {[catch {curl fetch ${updatecheck.url} $tempfile} error]} {
			ui_error "cannot check if $portname was updated ($error)"
		} else {
			# let's extract the modification date from the file.
			set chan [open $tempfile "r"]
			set updated -1
			while {1} {
				set line [gets $chan]
				if {[regexp "<date_updated>(.*)</date_updated>" $line line date_string]} {
					if {[catch {set date_updated [clock scan $date_string -gmt 1]} error]} {
						set updated 0
						ui_error "cannot check if $portname was updated (couldn't parse date_updated tag: $error)"
					} else {
						set updated [expr $date_updated > $port_moddate]
					}
					break
				}
			}
			if {$updated < 0} {
				ui_error "cannot check if $portname was updated (couldn't find date_updated tag)"
			}
		}		
	} elseif {${updatecheck.type} == "md5"} {
		if {[catch {curl fetch ${updatecheck.url} $tempfile} error]} {
			ui_error "cannot check if $portname was updated ($error)"
		} else {
			# let's compute the md5 sum.
			set dist_md5 [md5 file $tempfile]
			if {$dist_md5 != ${updatecheck.md5}} {
				ui_debug "md5sum for ${updatecheck.url}: $dist_md5"
				set updated 1
			}
		}
	} else {
		set port_moddate [file mtime ${portpath}/Portfile]
		if {[catch {set updated [curl isnewer ${updatecheck.url} $port_moddate]} error]} {
			ui_error "cannot check if $portname was updated ($error)"
		}
	}
	
	file delete -force $tempfile

	if {$updated} {
		ui_info "$portname seems to have been updated"
	} else {
		ui_debug "$portname seems to be up to date"
	}
}
