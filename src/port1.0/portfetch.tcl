# ex:ts=4
# portfetch.tcl
#
# Copyright (c) 2002 Apple Computer, Inc.
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

package provide portfetch 1.0
package require portutil 1.0

register com.apple.fetch target fetch_main fetch_init
register com.apple.fetch provides fetch
register com.apple.fetch requires main depends_fetch

# define options: distname master_sites
options master_sites patch_sites extract_sufx distfiles extract_only patchfiles use_zip use_bzip2 dist_subdir

# Defaults
default extract_sufx .tar.gz

set UI_PREFIX "---> "

proc suffix {distname} {
    global extract_sufx use_bzip2 use_zip
    if {[tbool use_bzip2]} {
	return ${distname}.tar.bz2
    } elseif {[tbool use_zip]} {
	return ${distname}.zip
    } else {
	return ${distname}${extract_sufx}
    }
}

proc checkfiles {args} {
    global distdir distfiles patchfiles all_dist_files patch_sites fetch_urls \
	portpath
    if {[info exists patchfiles]} {
	foreach file $patchfiles {
	    if {![file exists $portpath/files/$file]} {
		lappend all_dist_files $file
		if {[info exists patch_sites]} {
		    lappend fetch_urls patch_sites $file
		} else {
		    lappend fetch_urls master_sites $file
		}
	    }
	}
    }

    foreach file $distfiles {
	if {![file exists $portpath/files/$file]} {
	    lappend all_dist_files $file
	    lappend fetch_urls master_sites $file
	}
    }
}

proc fetchfiles {args} {
    global distpath all_dist_files UI_PREFIX ports_verbose \
	fetch_urls

    if {![file isdirectory $distpath]} {
	file mkdir $distpath
    }
    foreach {url_var distfile} $fetch_urls {
	if {![file isfile $distpath/$distfile]} {
	    ui_info "$UI_PREFIX $distfile doesn't seem to exist in $distpath"
	    upvar #0 $url_var sites 
	    foreach site $sites {
		ui_msg "$UI_PREFIX Attempting to fetch $distfile from $site"
		if [tbool ports_verbose] {
			set verboseflag -v
		} else {
			set verboseflag "-s"
		}
		if ![catch {system "curl ${verboseflag} -o \"${distpath}/${distfile}\" \"${site}${distfile}\" 2>&1"} result] {
		    set fetched 1
		    break
		}
	    }
	    if {![info exists fetched]} {
		return -1
	    } else {
		unset fetched
	    }
	}
    }
    return 0
}

proc fetch_init {args} {
    global distfiles distname distpath all_dist_files dist_subdir
    # Set distfiles
    if [info exists distname] {
	default distfiles [suffix $distname]
    }
    if {[info exist distpath] && [info exists dist_subdir]} {
	set distpath ${distpath}/${dist_subdir}
    }
    checkfiles
}

proc fetch_main {args} {
    global distname distpath all_dist_files

    # Check for files, download if neccesary
    if ![info exists all_dist_files] {
	return 0
    } else {
	return [fetchfiles]
    }
}
