# et:ts=4
# portfetch.tcl
#
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

package provide portfetch 1.0
package require portutil 1.0

set com.apple.fetch [target_new com.apple.fetch fetch_main]
target_init ${com.apple.fetch} fetch_init
target_provides ${com.apple.fetch} fetch
target_requires ${com.apple.fetch} main
target_prerun ${com.apple.fetch} fetch_start

# define options: distname master_sites
options master_sites patch_sites extract.sufx distfiles patchfiles use_zip use_bzip2 dist_subdir fetch.type cvs.module cvs.root cvs.password cvs.tag master_sites.subdir master_sites.listfile master_sites.listpath
# XXX we use the command framework to buy us some useful features,
# but this is not a user-modifiable command
commands cvs
commands fetch

# Defaults
default extract.sufx .tar.gz
default fetch.type standard
default cvs.cmd cvs
default cvs.password ""
default cvs.dir {${workpath}}
default cvs.module {$distname}
default cvs.tag HEAD
default cvs.env {CVS_PASSFILE=${workpath}/.cvspass}
default cvs.pre_args {"-d ${cvs.root}"}

default fetch.cmd curl
default fetch.dir {${distpath}}
default fetch.args {"-o ${distfile}.TMP"}
default fetch.pre_args ""
default fetch.post_args {"${site}${distfile}"}

default master_sites.listfile {"master_sites.tcl"}
default master_sites.listpath {"${portresourcepath}/sitelists/"}

# Set distfiles
default distfiles {[suffix $distname]}

# Option-executed procedures
namespace eval options { }
proc options::use_bzip2 {args} {
    global use_bzip2 extract.sufx
    if [tbool use_bzip2] {
        set extract.sufx .tar.bz2
    }
}

proc options::use_zip {args} {
    global use_zip extract.sufx
    if [tbool use_zip] {
        set extract.sufx .zip
    }
}

# Name space for internal implementation variables
# Site lists are stored here
namespace eval portfetch { }

set UI_PREFIX "---> "

# Given a distname, return a suffix based on the use_zip / use_bzip2 / extract.sufx options
proc suffix {distname} {
    global extract.sufx use_bzip2 use_zip fetch.type
    if {"${fetch.type}" == "cvs"} {
        return ""
    }
    if {[tbool use_bzip2]} {
	return ${distname}.tar.bz2
    } elseif {[tbool use_zip]} {
	return ${distname}.zip
    } else {
	return ${distname}${extract.sufx}
    }
}

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

# XXX
# Helper function for portextract.tcl that strips all tag names from a list
# Used to clean ${distfiles} for setting the ${extract.only} default
proc disttagclean {list} {
    if {"$list" == ""} {
        return $list
    }
    foreach name $list {
        lappend val [getdistname $name]
    }
    return $val
}

# Expand all variable references in each site variable, passing back a new 
# expanded list
proc expand-site-vars {sites} {
    set x [list]
    foreach element $sites {
        eval lappend x $element
    }
    return $x
}

# For a given master site type, e.g. "gnu" or "x11", check to see if there's a
# pre-registered set of sites, and if so, return them.
proc master-sites-for {arg} {
    global UI_PREFIX portresourcepath master_sites.listfile master_sites.listpath
    include ${master_sites.listpath}${master_sites.listfile}
    if ![info exists _master_sites($arg)] {
        ui_msg "$UI_PREFIX [format [msgcat::mc "No master sites on file for class %s"] $arg]"
        return {}
    }
    return [expand-site-vars $_master_sites($arg)]
}

# Checks all files and their tags to assemble url lists for later fetching
# sites tags create variables in the portfetch:: namespace containing all sites
# within that tag distfiles are added in $site $distfile format, where $site is
# the name of a variable in the portfetch:: namespace containing a list of fetch
# sites
proc checkfiles {args} {
    global distdir distfiles patchfiles all_dist_files patch_sites fetch_urls \
	    master_sites master_sites.subdir filespath

    foreach list {master_sites patch_sites} {
        upvar #0 $list uplist
        if ![info exists uplist] {
            continue
        }
        
        # There should be a better way to get rid of the extra list created by 
        # master-sites-for (the extra {}'s, one element in $uplist)
        set site_list [list]
        foreach site $uplist {
            set site_list [concat $site_list $site]
        }
        
        foreach site $site_list {
            if [info exists master_sites.subdir] {
                eval append site ${master_sites.subdir}
            }
            if {[regexp {([a-zA-Z]+://.+/):([a-zA-z]+)} $site match site tag] == 1} {
                lappend portfetch::$tag $site
            } else {
                lappend portfetch::$list $site
            }
        }
    }
   
    if {[info exists patchfiles]} {
	foreach file $patchfiles {
	    if {![file exists $filespath/$file]} {
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
	if {![file exists $filespath/$file]} {
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

# Perform a CVS login and fetch, storing the CVS login
# information in a custom .cvspass file
proc cvsfetch {args} {
    global workpath cvs.password cvs.args cvs.post_args cvs.tag cvs.module cvs.cmd cvs.env
    cd $workpath
    set cvs.args login
    set cvs.cmd "echo ${cvs.password} | /usr/bin/env ${cvs.env} cvs"
    if {[catch {system "[command cvs] 2>&1"} result]} {
        return -code error [msgcat::mc "CVS login failed"]
    }
    set cvs.args "co -r ${cvs.tag}"
    set cvs.cmd cvs
    set cvs.post_args "${cvs.module}"
    if {[catch {system "[command cvs] 2>&1"} result]} {
        return -code error [msgcat::mc "CVS check out failed"]
    }
    return 0
}

# Perform a standard fetch, assembling fetch urls from
# the listed url varable and associated distfile
proc fetchfiles {args} {
    global distpath all_dist_files UI_PREFIX fetch_urls fetch.cmd os.platform fetch.pre_args
    global distfile site

    # Override curl in the case of FreeBSD
    if {${os.platform} == "freebsd"} {
	set fetch.cmd "fetch"
    }

    if {![file isdirectory $distpath]} {
        if {[catch {file mkdir $distpath} result]} {
	    return -code error [format [msgcat::mc "Unable to create distribution files path: %s"] $result]
	}
    }
    if {![file writable $distpath]} {
        return -code error [format [msgcat::mc "%s must be writable"] $distpath]
    }
    foreach {url_var distfile} $fetch_urls {
	if {![file isfile $distpath/$distfile]} {
	    ui_info "$UI_PREFIX [format [msgcat::mc "%s doesn't seem to exist in %s"] $distfile $distpath]"
            global portfetch::$url_var
            if ![info exists $url_var] {
                ui_error [format [msgcat::mc "No defined site for tag: %s, using master_sites"] $url_var]
                set url_var master_sites
		global portfetch::$url_var
            }
	    foreach site [set $url_var] {
		ui_msg "$UI_PREFIX [format [msgcat::mc "Attempting to fetch %s from %s"] $distfile $site]"
		if {![catch {system "[command fetch]"} result] &&
		    ![catch {system "mv ${distpath}/${distfile}.TMP ${distpath}/${distfile}"}]} {
		    set fetched 1
		    break
		} else {
		    exec rm -f ${distpath}/${distfile}.TMP
		    ui_error "[msgcat::mc "Unable to fetch:"]: $result"
		}
	    }
	    if {![info exists fetched]} {
		return -code error [msgcat::mc "fetch failed"]
	    } else {
		unset fetched
	    }
	}
    }
    return 0
}

# Initialize fetch target, calling checkfiles if neccesary
proc fetch_init {args} {
    global distfiles distname distpath all_dist_files dist_subdir fetch.type

    if {[info exist distpath] && [info exists dist_subdir]} {
	set distpath ${distpath}/${dist_subdir}
    }
    if {"${fetch.type}" == "standard"} {
        checkfiles
    }
}

proc fetch_start {args} {
    global UI_PREFIX portname

    ui_msg "$UI_PREFIX [format [msgcat::mc "Fetching %s"] $portname]"
}

# Main fetch routine
# If all_dist_files is not populated and $fetch.type == standard, then
# there are no files to download. Otherwise, either do a cvs checkout
# or call the standard fetchfiles procedure
proc fetch_main {args} {
    global distname distpath all_dist_files fetch.type

    # Check for files, download if neccesary
    if {![info exists all_dist_files] && "${fetch.type}" == "standard"} {
        return 0
    }
    if {"${fetch.type}" == "cvs"} {
        return [cvsfetch]
    } else {
	return [fetchfiles]
    }
}
