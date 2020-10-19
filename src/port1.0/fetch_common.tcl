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
}

# Name space for internal site lists storage
namespace eval portfetch::mirror_sites {
    variable sites

    array set sites {}
}

# percent-encode all characters in str that are not unreserved in URIs
proc portfetch::percent_encode {str} {
    set outstr ""
    while {$str ne ""} {
        set char [string index $str 0]
        set str [string range $str 1 end]
        switch -- $char {
            {-} -
            {.} -
            {_} -
            {~} {
                append outstr $char
            }
            default {
                if {[string is ascii -strict $char] && [string is alnum -strict $char]} {
                    append outstr $char
                } else {
                    foreach {a b} [split [format %02X [scan $char %c]] {}] {
                        append outstr "%${a}${b}"
                    }
                }
            }
        }
    }
    return $outstr
}

# Given a site url and the name of the distfile, assemble url and
# return it.
proc portfetch::assemble_url {site distfile} {
    if {[string index $site end] ne "/"} {
        append site /
    }
    return "${site}[percent_encode ${distfile}]"
}

# For a given mirror site type, e.g. "gnu" or "x11", check to see if there's a
# pre-registered set of sites, and if so, return them.
proc portfetch::mirror_sites {mirrors tag subdir mirrorfile} {
    global name dist_subdir global_mirror_site

    if {[file exists $mirrorfile]} {
        source $mirrorfile
    }

    if {![info exists portfetch::mirror_sites::sites($mirrors)]} {
        if {$mirrors ne $global_mirror_site} {
            ui_warn "[format [msgcat::mc "No mirror sites on file for class %s"] $mirrors]"
        }
        return {}
    }

    set ret [list]
    set name_re {\$(?:name\y|\{name\})}
    foreach element $portfetch::mirror_sites::sites($mirrors) {

        # here we have the chance to take a look at tags, that possibly
        # have been assigned in mirror_sites.tcl
        # tag will be after the last colon after the
        # first slash after the ://
        set lastcolon [string last : $element]
        set aftersep [expr {[string first : $element] + 3}]
        set firstslash [string first / $element $aftersep]
        if {$firstslash != -1 && $firstslash < $lastcolon} {
            set mirror_tag [string range $element [expr {$lastcolon + 1}] end]
            set element [string range $element 0 [expr {$lastcolon - 1}]]
        } else {
            set mirror_tag ""
        }

        # if the URL has $name embedded, kill any mirror_tag that may have been added
        # since a mirror_tag and $name are incompatible
        if {[regexp $name_re $element]} {
            set mirror_tag ""
        }

        if {$mirror_tag eq "mirror"} {
            set thesubdir ${dist_subdir}
        } elseif {$subdir eq "" && $mirror_tag ne "nosubdir"} {
            set thesubdir ${name}
        } else {
            set thesubdir ${subdir}
        }

        # parse an embedded $name. if present, remove the subdir
        if {[regsub $name_re $element $thesubdir element] > 0} {
            set thesubdir ""
        }

        if {$tag ne ""} {
            append element "${thesubdir}:${tag}"
        } else {
            append element "${thesubdir}"
        }

        lappend ret $element
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
    set url_re {([a-zA-Z]+://.+)}
    set tagged_url_re {([a-zA-Z]+://.+/?):([0-9A-Za-z_-]+)$}

    foreach {listname extras} $sitelists {
        upvar #0 $listname $listname
        if {![info exists $listname]} {
            continue
        }
        global ${listname}.mirror_subdir
        set full_list [set $listname]
        # add the specified global and user-defined mirrors
        set sglobal ""
        set senv ""
        if {[llength $extras] >= 2} {
            set sglobal [lindex $extras 0]
            set senv [lindex $extras 1]
            append full_list " $sglobal"
            if {[info exists env($senv)]} {
                set full_list [concat $env($senv) $full_list]
            }
        }

        set site_list [list]
        foreach site $full_list {
            if {[regexp $url_re $site match site]} {
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

        # add in the global and user-defined mirrors for each tag
        foreach site $site_list {
            if {[regexp $tagged_url_re $site match site tag] && ![info exists extras_added($tag)]} {
                if {$sglobal ne ""} {
                    set site_list [concat $site_list [mirror_sites $sglobal $tag "" $mirrorfile]]
                }
                if {[info exists env($senv)]} {
                    set site_list [concat $env($senv) $site_list]
                }
                set extras_added($tag) yes
            }
        }

        foreach site $site_list {
        if {[regexp $tagged_url_re $site match site tag]} {
                lappend urlmap($tag) $site
            } else {
                lappend urlmap($listname) $site
            }
        }
    }
}

# sorts fetch_urls in order of ping time
proc portfetch::sortsites {urls default_listvar} {
    global $default_listvar
    upvar $urls fetch_urls
    variable urlmap
    set hostregex {[a-zA-Z]+://([a-zA-Z0-9\.\-_]+)}

    foreach {url_var distfile} $fetch_urls {
        if {![info exists urlmap($url_var)]} {
            if {$url_var ne $default_listvar} {
                ui_error [format [msgcat::mc "No defined site for tag: %s, using $default_listvar"] $url_var]
                set urlmap($url_var) $urlmap($default_listvar)
            } else {
                set urlmap($url_var) {}
            }
        }
        set urllist $urlmap($url_var)

        if {[llength $urllist] <= 1} {
            # there is only one mirror, no need to ping or sort
            continue
        }

        # can't do the ping with dropped privileges (though it works fine if we didn't start as root)
        if {[getuid] == 0 && [geteuid] != 0} {
            set oldeuid [geteuid]
            set oldegid [getegid]
            seteuid 0; setegid 0
        }

        set hosts {}
        foreach site $urllist {
            if {[string range $site 0 6] eq "file://"} {
                set pingtimes(localhost) 0
                continue
            }
            
            regexp $hostregex $site -> host
            
            if { [info exists seen($host)] } {
                continue
            }
            # first check the persistent cache
            set pingtimes($host) [get_pingtime $host]
            if {$pingtimes($host) eq {}} {
                set seen($host) yes
                lappend hosts $host
            }
        }

        set max_hosts_to_ping 50
        set len [llength $hosts]
        if {$len > $max_hosts_to_ping} {
            # randomize them
            # shuffle10a from https://wiki.tcl-lang.org/page/Shuffle+a+list
            while {$len} {
                set n [expr {int($len*rand())}]
                set tmp [lindex $hosts $n]
                lset hosts $n [lindex $hosts [incr len -1]]
                lset hosts $len $tmp
            }
        }

        set pinged_hosts [list]
        foreach host $hosts {
            if {[llength $pinged_hosts] < $max_hosts_to_ping} {
                if {[catch {set fds($host) [open "|ping -noq -c3 -t3 $host"]}]} {
                    ui_debug "Spawning ping for $host failed"
                } else {
                    lappend pinged_hosts $host
                    continue
                }
            }
            # will end up after all hosts that were pinged OK but before those that didn't respond
            set pingtimes($host) 5000
        }

        foreach host $pinged_hosts {
            set pingtimes($host) ""
            while {[gets $fds($host) pingline] >= 0} {
                if {[string match round-trip* $pingline]} {
                    set pingtimes($host) [lindex [split $pingline /] 4]
                    break
                }
            }
            if { [catch { close $fds($host) }] || ![string is double -strict $pingtimes($host)] } {
                # ping failed, so put it last in the list
                set pingtimes($host) 10000
            }
            # cache it
            set_pingtime $host $pingtimes($host)
        }

        if {[info exists oldeuid]} {
            setegid $oldegid
            seteuid $oldeuid
        }

        set pinglist [list]
        foreach site $urllist {
            if {[string range $site 0 6] eq "file://"} {
                set host localhost
            } else {
                regexp $hostregex $site -> host
            }
            # -1 means blacklisted
            if {$pingtimes($host) != "-1"} {
                lappend pinglist [ list $site $pingtimes($host) ]
            }
        }

        set pinglist [ lsort -real -index 1 $pinglist ]

        set urlmap($url_var) {}
        foreach pair $pinglist {
            lappend urlmap($url_var) [lindex $pair 0]
        }
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
