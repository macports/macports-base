# et:ts=4
# portdistfiles.tcl
#
# Copyright (c) 2003 Kevin Van Vechten <kevin@opendarwin.org>
# Copyright (c) 2002 - 2003 Apple Computer, Inc.
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

PortTarget 1.0

name			org.opendarwin.distfiles
#version		1.0
maintainers		kevin@opendarwin.org
description		Download the distribution files.
provides		distfiles
requires		main

options master_sites distfiles patch_sites patchfiles extract.sufx extract.dir extract.post_args checksums dist_subdir

# XXX: extract suffix stuff needs to be reworked
default extract.sufx .tar.gz
default extract.dir {[option workpath]}
default extract.post_args {{| tar -xf -}}

default distfiles {[option distname][option extract.sufx]}


set UI_PREFIX "---> "

namespace eval site_tags {}

# Given a distribution file name, return the appended tag
# Example: getdisttag distfile.tar.gz:tag1 returns "tag1"
proc getdisttag {name} {
    if {[regexp {.+:([A-Za-z]+)} $name match tag]} {
        return $tag
    } else {
        return ""
    }
}

# Given a distribution file name, return the name without an attached tag
# Example : getdistname distfile.tar.gz:tag1 returns "distfile.tar.gz"
proc getdistname {name} {
    regexp {(.+):[A-Za-z_-]+} $name match name
    return $name
}


proc start {args} {
	global UI_PREFIX
	ui_msg "${UI_PREFIX} Downloading distribution files"
}

proc main {args} {
	global UI_PREFIX

	# The distfiles builtes the list of distribution files then
	# iterates through it.  It sets the 'distfile' option to the
	# name of the file to be downloaded then selects the download,
	# checksum, and extract targets from the Port API.  These
	# targets are run on the distfile.
	
	# If the distfile is tagged, then only the master sites with
	# the equivalent tag are made visible to the download targets.
	# Otherwise all master sites will be made visible.
	
	if {[exists distpath] && [exists dist_subdir]} {
		option distpath [file join [option distpath] [option dist_subdir]]
	}
	
    if {![file isdirectory [option distpath]]} {
        if {[catch {file mkdir [option distpath]} result]} {
			return -code error [format [msgcat::mc "Unable to create distribution files path: %s"] $result]
		}
	}
    if {![file writable [option distpath]]} {
        return -code error [format [msgcat::mc "%s must be writable"] [option distpath]]
    }
	
	# XXX: The distfiles target needs to handle tags.
	
	foreach distfile [option distfiles] {
		# Make the distfile globally visible.
		option distfile $distfile
		
		# Selects the download, checksum, and extract targets.
		# extracts the distfile into the work directory.
		# Don't keep state.
		eval_targets extract 0
	}
	
	# XXX: patch files dont' get extracted, only checksummed
	
	# Hoodwink the fetch targets into using patchsites instead of master_sites.
	if {[exists patch_sites]} {
		set orig_master_sites [option master_sites]
		option master_sites [option patch_sites]
		
		foreach distfile [option patchfiles] {
			# Make the distfile globally visible.
			option distfile $distfile
			
			# Selects the download and checksum targets.
			# checksums the patch file.
			# Don't keep state.
			eval_targets checksum 0
		}
		
		# Restore the master sites.
		option master_sites $orig_master_sites
	}
}
