# et:ts=4
# portdistcheck.tcl
#
# Copyright (c) 2007-2011, 2014, 2016 The MacPorts Project
# Copyright (c) 2005-2006 Paul Guyot <pguyot@kallisys.net>,
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
# 3. Neither the name of The MacPorts Project nor the names of its
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

package provide portdistcheck 1.0
package require portutil 1.0
package require portfetch 1.0

set org.macports.distcheck [target_new org.macports.distcheck portdistcheck::distcheck_main]
target_runtype ${org.macports.distcheck} always
target_state ${org.macports.distcheck} no
target_provides ${org.macports.distcheck} distcheck
target_requires ${org.macports.distcheck} main

namespace eval portdistcheck {
}

# define options
options distcheck.type

# defaults
default distcheck.type moddate

proc portdistcheck::distcheck_main {args} {
    global distcheck.type fetch.type fetch.ignore_sslcert \
           subport portpath

    set port_moddate [file mtime ${portpath}/Portfile]

    ui_debug "Portfile modification date is [clock format $port_moddate]"

    set curl_options {}
    if {[tbool fetch.ignore_sslcert]} {
        lappend curl_options "--ignore-ssl-cert"
    }

    # Check the distfiles if it's a regular fetch phase.
    if {"${distcheck.type}" ne "none"
        && "${fetch.type}" eq "standard"} {
        # portfetch 1.0::checkfiles sets fetch_urls list.
        set fetch_urls {}
        portfetch::checkfiles fetch_urls
        set totalsize 0

        # Check all the files.
        foreach {url_var distfile} $fetch_urls {
            global portfetch::urlmap
            if {![info exists urlmap($url_var)]} {
                ui_error [format [msgcat::mc "No defined site for tag: %s, using master_sites"] $url_var]
                set urlmap($url_var) $master_sites
            }
            if {${distcheck.type} eq "moddate"} {
                set count 0
                foreach site $urlmap($url_var) {
                    ui_debug [format [msgcat::mc "Checking %s from %s"] $distfile $site]
                    set file_url [portfetch::assemble_url $site $distfile]
                    try -pass_signal {
                        set urlnewer [curl isnewer {*}$curl_options $file_url $port_moddate]
                        if {$urlnewer} {
                            ui_warn "port $subport: $file_url is newer than Portfile"
                        }
                        incr count
                    } catch {{*} eCode eMessage} {
                        ui_debug [msgcat::mc "couldn't fetch %s for %s (%s)" $file_url $subport $eMessage]
                    }
                }
                if {$count == 0} {
                    ui_error "no mirror had $distfile for $subport"
                }
            } elseif {${distcheck.type} eq "filesize"} {
                set count 0
                foreach site $urlmap($url_var) {
                    ui_debug [format [msgcat::mc "Checking %s from %s"] $distfile $site]
                    set file_url [portfetch::assemble_url $site $distfile]
                    try -pass_signal {
                        set urlsize [curl getsize {*}$curl_options $file_url]
                        incr count
                        if {$urlsize > 0} {
                            ui_info "port $subport: $distfile $urlsize bytes"
                            incr totalsize $urlsize
                            break
                        }
                    } catch {{*} eCode eMessage} {
                        ui_debug [msgcat::mc "couldn't fetch %s for %s (%s)" $file_url $subport $eMessage]
                    }
                }
                if {$count == 0} {
                    ui_error "no mirror had $distfile for $subport"
                }
            } else {
                ui_error "unknown distcheck.type ${distcheck.type}"
                break
            }
        }

        if {${distcheck.type} eq "filesize" && $totalsize > 0} {
            if {$totalsize < 1024} {
                set size $totalsize
                set humansize "${size}"
            } elseif {$totalsize < 1024*1024} {
                set size [expr {$totalsize / 1024.0}]
                set humansize [format "%.1fK" $size]
            } elseif {$totalsize < 1024*1024*1024} {
                set size [expr {$totalsize / (1024.0*1024.0)}]
                set humansize [format "%.1fM" $size]
            } else {
                set size [expr {$totalsize / (1024.0*1024.0*1024.0)}]
                set humansize [format "%.1fG" $size]
            }
            ui_msg "$subport: $humansize"
        }
    }
}
