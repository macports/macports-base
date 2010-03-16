# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# $Id$
#
# Copyright (c) 2002 - 2003 Apple Inc.
# Copyright (c) 2004-2010 The MacPorts Project
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

package provide fetch_common 1.0
package require portutil 1.0
package require Pextlib 1.0

namespace eval portfetch {
    variable urlmap
    array set urlmap {}
}

# Name space for internal site lists storage
namespace eval portfetch::mirror_sites {
    variable sites

    array set sites {}
}

# Given a site url and the name of the distfile, assemble url and
# return it.
proc portfetch::assemble_url {site distfile} {
    if {[string index $site end] != "/"} {
        return "${site}/${distfile}"
    } else {
        return "${site}${distfile}"
    }
}

# For a given mirror site type, e.g. "gnu" or "x11", check to see if there's a
# pre-registered set of sites, and if so, return them.
proc portfetch::mirror_sites {mirrors tag subdir mirrorfile} {
    global UI_PREFIX name dist_subdir
    global global_mirror_site fallback_mirror_site

    if {[file exists $mirrorfile]} {
        source $mirrorfile
    }

    if {![info exists portfetch::mirror_sites::sites($mirrors)]} {
        if {$mirrors != $global_mirror_site && $mirrors != $fallback_mirror_site} {
            ui_warn "[format [msgcat::mc "No mirror sites on file for class %s"] $mirrors]"
        }
        return {}
    }

    set ret [list]
    foreach element $portfetch::mirror_sites::sites($mirrors) {

        # here we have the chance to take a look at tags, that possibly
        # have been assigned in mirror_sites.tcl
        set splitlist [split $element :]
        # every element is a URL, so we'll always have multiple elements. no need to check
        set element "[lindex $splitlist 0]:[lindex $splitlist 1]"
        set mirror_tag "[lindex $splitlist 2]"

        set name_re {\$(?:name\y|\{name\})}
        # if the URL has $name embedded, kill any mirror_tag that may have been added
        # since a mirror_tag and $name are incompatible
        if {[regexp $name_re $element]} {
            set mirror_tag ""
        }

        if {$mirror_tag == "mirror"} {
            set thesubdir ${dist_subdir}
        } elseif {$subdir == "" && $mirror_tag != "nosubdir"} {
            set thesubdir ${name}
        } else {
            set thesubdir ${subdir}
        }

        # parse an embedded $name. if present, remove the subdir
        if {[regsub $name_re $element $thesubdir element] > 0} {
            set thesubdir ""
        }

        if {"$tag" != ""} {
            eval append element "${thesubdir}:${tag}"
        } else {
            eval append element "${thesubdir}"
        }

        eval lappend ret $element
    }

    return $ret
}

# Checks sites.
# sites tags create variables in the portfetch:: namespace containing all sites
# within that tag distfiles are added in $site $distfile format, where $site is
# the name of a variable in the portfetch:: namespace containing a list of fetch
# sites
proc portfetch::checksites {sitelists mirrorfile} {
    global env
    variable urlmap

    foreach {listname extras} $sitelists {
        upvar #0 $listname $listname
        if {![info exists $listname]} {
            continue
        }
        global ${listname}.mirror_subdir
        # add the specified global, fallback and user-defined mirrors
        set sglobal [lindex $extras 0]; set sfallback [lindex $extras 1]; set senv [lindex $extras 2]
        set full_list [set $listname]
        append full_list " $sglobal $sfallback"
        if {[info exists env($senv)]} {
            set full_list [concat $env($senv) $full_list]
        }

        set site_list [list]
        foreach site $full_list {
            if {[regexp {([a-zA-Z]+://.+)} $site match site]} {
                set site_list [concat $site_list $site]
            } else {
                set splitlist [split $site :]
                if {[llength $splitlist] > 3 || [llength $splitlist] <1} {
                    ui_error [format [msgcat::mc "Unable to process mirror sites for: %s, ignoring."] $site]
                }
                set mirrors "[lindex $splitlist 0]"
                set subdir "[lindex $splitlist 1]"
                set tag "[lindex $splitlist 2]"
                if {[info exists ${listname}.mirror_subdir]} {
                    append subdir "[set ${listname}.mirror_subdir]"
                }
                set site_list [concat $site_list [mirror_sites $mirrors $tag $subdir $mirrorfile]]
            }
        }

        # add in the global, fallback and user-defined mirrors for each tag
        foreach site $site_list {
            if {[regexp {([a-zA-Z]+://.+/?):([0-9A-Za-z_-]+)$} $site match site tag] && ![info exists extras_added($tag)]} {
                if {$sglobal != ""} {
                    set site_list [concat $site_list [mirror_sites $sglobal $tag "" $mirrorfile]]
                }
                if {$sfallback != ""} {
                    set site_list [concat $site_list [mirror_sites $sfallback $tag "" $mirrorfile]]
                }
                if {[info exists env($senv)]} {
                    set site_list [concat [list $env($senv)] $site_list]
                }
                set extras_added($tag) yes
            }
        }

        foreach site $site_list {
        if {[regexp {([a-zA-Z]+://.+/?):([0-9A-Za-z_-]+)$} $site match site tag]} {
                lappend urlmap($tag) $site
            } else {
                lappend urlmap($listname) $site
            }
        }
    }
}

# sorts fetch_urls in order of ping time
proc portfetch::sortsites {urls fallback_mirror_list default_listvar} {
    global $default_listvar
    upvar $urls fetch_urls
    variable urlmap

    foreach {url_var distfile} $fetch_urls {
        if {![info exists urlmap($url_var)]} {
            ui_error [format [msgcat::mc "No defined site for tag: %s, using $default_listvar"] $url_var]
            set urlmap($url_var) [set $default_listvar]
        }
        set urllist $urlmap($url_var)
        set hosts {}
        set hostregex {[a-zA-Z]+://([a-zA-Z0-9\.\-_]+)}

        if {[llength $urllist] - [llength $fallback_mirror_list] <= 1} {
            # there is only one mirror, no need to ping or sort
            continue
        }

        foreach site $urllist {
            regexp $hostregex $site -> host

            if { [info exists seen($host)] } {
                continue
            }
            foreach fallback $fallback_mirror_list {
                if {[string match [append fallback *] $site]} {
                    # don't bother pinging fallback mirrors
                    set seen($host) yes
                    # and make them sort to the very end of the list
                    set pingtimes($host) 20000
                    break
                }
            }
            if { ![info exists seen($host)] } {
                if {[catch {set fds($host) [open "|ping -noq -c3 -t3 $host | grep round-trip | cut -d / -f 5"]}]} {
                    ui_debug "Spawning ping for $host failed"
                    # will end up after all hosts that were pinged OK but before those that didn't respond
                    set pingtimes($host) 5000
                } else {
                    ui_debug "Pinging $host..."
                    set seen($host) yes
                    lappend hosts $host
                }
            }
        }

        foreach host $hosts {
            set len [gets $fds($host) pingtimes($host)]
            if { [catch { close $fds($host) }] || ![string is double -strict $pingtimes($host)] } {
                # ping failed, so put it last in the list (but before the fallback mirrors)
                set pingtimes($host) 10000
            }
            ui_debug "$host ping time is $pingtimes($host)"
        }

        set pinglist {}
        foreach site $urllist {
            regexp $hostregex $site -> host
            lappend pinglist [ list $site $pingtimes($host) ]
        }

        set pinglist [ lsort -real -index 1 $pinglist ]

        set urlmap($url_var) {}
        foreach pair $pinglist {
            lappend urlmap($url_var) [lindex $pair 0]
        }
    }
}
