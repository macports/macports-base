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

register com.apple.fetch target fetch_main
register com.apple.fetch init fetch_init
register com.apple.fetch provides fetch
register com.apple.fetch requires main depends_fetch

# define options: distname master_sites
options master_sites patch_sites extract_sufx distfiles extract_only patchfiles use_zip use_bzip2 dist_subdir

# Defaults
default extract_sufx .tar.gz

# Set distfiles
default distfiles {[suffix $distname]}

namespace eval options { }
proc options::use_bzip2 {args} {
    global use_bzip2 extract_sufx
    if [tbool use_bzip2] {
        set extract_sufx .tar.bz2
    }
}

proc options::use_zip {args} {
    global use_zip extract_sufx
    if [tbool use_zip] {
        set extract_sufx .zip
    }
}

# Name space for internal implementation variables

namespace eval portfetch { }

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

proc getdisttag {name} {
    if {[regexp {.+:([A-Za-z]+)} $name match tag]} {
        return $tag
    } else {
        return ""
    }
}

proc getdistname {name} {
    regexp {(.+):[A-Za-z]+} $name match name
    return $name
}

proc checkfiles {args} {
    global distdir distfiles patchfiles all_dist_files patch_sites fetch_urls \
	portpath master_sites

    foreach list {master_sites patch_sites} {
        upvar #0 $list uplist
        if ![info exists uplist] {
            break
        }
        foreach site $uplist {
            if {[regexp {([a-zA-Z]+://.+/):([a-zA-z]+)} $site match site tag] == 1} {
                lappend portfetch::$tag $site
            } else {
                lappend portfetch::$list $site
            }
        }
    }

    if {[info exists patchfiles]} {
	foreach file $patchfiles {
	    if {![file exists $portpath/files/$file]} {
        set distsite [getdisttag $file]
		set file [getdistname $file]
		lappend all_dist_files $file
		if {$distsite != ""} {
		    lappend fetch_urls $distsite $file
		} elseif {[info exists patch_sites]} {
		    lappend fetch_urls patch_sites $file
		} else {
		    lappend fetch_urls master_sites $file
		}
	    }
	}
    }

    foreach file $distfiles {
	if {![file exists $portpath/files/$file]} {
        set distsite [getdisttag $file]
		set file [getdistname $file]
		lappend all_dist_files $file
		if {$distsite != ""} {
		        lappend fetch_urls $distsite $file
		} else {
	            lappend fetch_urls master_sites $file
		}
	}
    }
}

proc fetchfiles {args} {
    global distpath all_dist_files UI_PREFIX ports_verbose fetch_urls

    if {![file isdirectory $distpath]} {
        if {[catch {file mkdir $distpath} result]} {
	    ui_error "Unable to create distribution files path: $result"
	    return 1
	}
    }
    foreach {url_var distfile} $fetch_urls {
	if {![file isfile $distpath/$distfile]} {
	    ui_info "$UI_PREFIX $distfile doesn't seem to exist in $distpath"
            global portfetch::$url_var
            if ![info exists $url_var] {
                ui_error "No defined site for tag: $url_var, using master_sites"
                set url_var master_sites
		global portfetch::$url_var
            }
	    foreach site [set $url_var] {
		ui_msg "$UI_PREFIX Attempting to fetch $distfile from $site"
		if [tbool ports_verbose] {
			set verboseflag -v
		} else {
			set verboseflag "-s -S"
		}
		if ![catch {system "curl ${verboseflag} -o \"${distpath}/${distfile}\" \"${site}${distfile}\""} result] {
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
