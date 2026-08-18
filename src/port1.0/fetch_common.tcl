# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
#
# Copyright (c) 2002-2003 Apple Inc.
# Copyright (c) 2004-2014, 2016-2018 The MacPorts Project
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
    variable tagged_url_re {([a-zA-Z]+://.+/?):([0-9A-Za-z_-]+)$}
}

# For a given mirror site type, e.g. "gnu" or "x11", check to see if there's a
# pre-registered set of sites, and if so, return them.
proc portfetch::mirror_sites {mirrors tag subdir mirrorscmd} {
    global name dist_subdir global_mirror_site

    set sites_entry [{*}$mirrorscmd $mirrors]
    if {$sites_entry eq {}} {
        if {$mirrors ne $global_mirror_site} {
            ui_warn "[format [msgcat::mc "No mirror sites on file for class %s"] $mirrors]"
        }
        return [list]
    }

    lmap element $sites_entry {
        resolve_mirror_tags $element $subdir $tag $name $dist_subdir
    }
}

# Resolve any tags present in a user-defined site
# a single tag is taken to be a mirror option tag (:nosubdir, :mirror)
# an optional second tag acts like a tag on a url in master_sites
proc portfetch::resolve_env_site {site} {
    variable tagged_url_re
    set resolved_is_tagged 0
    if {[regexp $tagged_url_re $site]} {
        global name dist_subdir
        # At least one tag, check for a second
        lassign [separate_tag $site] element tag
        if {[regexp $tagged_url_re $element]} {
            # two tags
            set resolved_element [resolve_mirror_tags $element {} $tag $name $dist_subdir]
            resolved_is_tagged 1
        } else {
            # single tag
            set resolved_element [resolve_mirror_tags $site {} {} $name $dist_subdir]
        }
    } else {
        set resolved_element $site
    }
    return [list $resolved_element $resolved_is_tagged]
}

# Checks sites.
# sites tags create variables in the portfetch:: namespace containing all sites
# within that tag distfiles are added in $site $distfile format, where $site is
# the name of a variable in the portfetch:: namespace containing a list of fetch
# sites
proc portfetch::checksites {sitelists mirrorscmd} {
    global env
    variable urlmap
    set url_re {([a-zA-Z]+://.+)}
    variable tagged_url_re

    foreach {listname extras} $sitelists {
        upvar #0 $listname $listname
        if {![info exists $listname]} {
            continue
        }
        global ${listname}.mirror_subdir
        set full_list [set $listname]
        # add the specified global and user-defined mirrors
        set global_sites [list]
        set untagged_env_sites [list]
        if {[llength $extras] >= 2} {
            lassign $extras sglobal senv
            if {[info exists env($senv)]} {
                set resolved_senv [list]
                foreach s $env($senv) {
                    lassign [resolve_env_site $s] resolved_element resolved_is_tagged
                    lappend resolved_senv $resolved_element
                    if {!$resolved_is_tagged} {
                        lappend untagged_env_sites $resolved_element
                    }
                }
                set full_list [list {*}$resolved_senv {*}$full_list]
            }
            if {$sglobal ne ""} {
                set full_list [list $sglobal {*}$full_list]
                set global_sites [mirror_sites $sglobal "" "" $mirrorscmd]
            }
        }

        set site_list [list]
        foreach site $full_list {
            if {[regexp $url_re $site match site]} {
                lappend site_list $site
            } else {
                set splitlist [split $site :]
                if {[llength $splitlist] > 3 || [llength $splitlist] <1} {
                    ui_error [format [msgcat::mc "Unable to process mirror sites for: %s, ignoring."] $site]
                }
                lassign $splitlist mirrors subdir tag
                if {[info exists ${listname}.mirror_subdir]} {
                    append subdir [set ${listname}.mirror_subdir]
                }
                lappend site_list {*}[mirror_sites $mirrors $tag $subdir $mirrorscmd]
            }
        }

        set tags [dict create]
        foreach site $site_list {
            if {[regexp $tagged_url_re $site match site tag]} {
                lappend urlmap($tag) $site
                dict set tags $tag 1
            } else {
                lappend urlmap($listname) $site
            }
        }

        # add in the global and user-defined mirrors for each tag
        foreach tag [dict keys $tags] {
            # Only add untagged sites from the environment here.
            # Tagged ones will already be in the list.
            set urlmap($tag) [list {*}$global_sites {*}$untagged_env_sites {*}$urlmap($tag)]
        }
    }
}

# sorts fetch_urls in order of ping time
proc portfetch::sortsites {urls default_listvar} {
    upvar $urls fetch_urls
    variable urlmap

    foreach {url_var distfile} $fetch_urls {
        if {![info exists urlmap($url_var)]} {
            if {$url_var ne $default_listvar} {
                ui_error [format [msgcat::mc "No defined site for tag: %s, using $default_listvar"] $url_var]
                set urlmap($url_var) $urlmap($default_listvar)
            } else {
                set urlmap($url_var) {}
            }
        }

        if {[llength $urlmap($url_var)] <= 1} {
            # there is only one mirror, no need to ping or sort
            continue
        }

        set urlmap($url_var) [lsort -command compare_pingtimes $urlmap($url_var)]
    }
}

proc portfetch::get_urls {} {
    variable fetch_urls
    variable urlmap
    set urls [list]

    portfetch::checkfiles fetch_urls

    foreach {url_var distfile} $fetch_urls {
        if {![info exists urlmap($url_var)]} {
            ui_error [format [msgcat::mc "No defined site for tag: %s, using master_sites"] $url_var]
            set urlmap($url_var) $urlmap(master_sites)
        }
        foreach site $urlmap($url_var) {
            lappend urls $site
        }
    }

    return $urls
}

# warn if DNS is broken
proc portfetch::check_dns {} {
    # check_broken_dns returns true at most once, so we don't have to worry about spamming this message
    if {[check_broken_dns]} {
        ui_warn "Your DNS servers incorrectly claim to know the address of nonexistent hosts. This may cause checksum mismatches for some ports. See this page for more information: <https://trac.macports.org/wiki/MisbehavingServers>"
    }
}
