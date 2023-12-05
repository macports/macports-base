# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# portlivecheck.tcl
#
# $Id$
#
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

package provide portlivecheck 1.0
package require portutil 1.0
package require portfetch 1.0

set org.macports.livecheck [target_new org.macports.livecheck portlivecheck::livecheck_main]
target_runtype ${org.macports.livecheck} always
target_state ${org.macports.livecheck} no
target_provides ${org.macports.livecheck} livecheck
target_requires ${org.macports.livecheck} main

namespace eval portlivecheck {
}

# define options
options livecheck.url livecheck.type livecheck.check livecheck.md5 livecheck.regex livecheck.name livecheck.distname livecheck.version

# defaults
default livecheck.url {$homepage}
default livecheck.check default
default livecheck.type default
default livecheck.md5 ""
default livecheck.regex ""
default livecheck.name default
default livecheck.distname default
default livecheck.version {$version}

# Deprecation
option_deprecate livecheck.check livecheck.type

proc portlivecheck::livecheck_main {args} {
    global livecheck.url livecheck.type livecheck.md5 livecheck.regex livecheck.name livecheck.distname livecheck.version
    global fetch.user fetch.password fetch.use_epsv fetch.ignore_sslcert
    global homepage portpath workpath
    global master_sites name distfiles

    set updated 0
    set updated_version "unknown"
    set has_master_sites [info exists master_sites]
    set has_homepage [info exists homepage]

    set tempfile [mktemp "/tmp/mports.livecheck.XXXXXXXX"]
    set port_moddate [file mtime ${portpath}/Portfile]

    ui_debug "Portfile modification date is [clock format $port_moddate]"
    ui_debug "Port (livecheck) version is ${livecheck.version}"

    # Copied over from portfetch in parts
    set fetch_options {}
    if {[string length ${fetch.user}] || [string length ${fetch.password}]} {
        lappend fetch_options -u
        lappend fetch_options "${fetch.user}:${fetch.password}"
    }
    if {${fetch.use_epsv} != "yes"} {
        lappend fetch_options "--disable-epsv"
    }
    if {${fetch.ignore_sslcert} != "no"} {
        lappend fetch_options "--ignore-ssl-cert"
    }

    # Check _resources/port1.0/livecheck for available types.
    set types_dir [getdefaultportresourcepath "port1.0/livecheck"]
    if {[catch {set available_types [glob -directory $types_dir -tails -types f *.tcl]} result]} {
        return -code 1 "No available types were found. Check '$types_dir'."
    }

    # Convert available_types from a list of files (e.g., { freshmeat.tcl
    # gnu.tcl ... }) into a string in the format "type|type|..." (e.g.,
    # "freshmeat|gnu|...").
    set available_types [regsub -all {\.tcl} [join $available_types |] {}]

    if {${livecheck.type} eq "default"} {
        # Determine the default type from the mirror.
        if {$has_master_sites} {
            foreach {master_site} ${master_sites} {
                if {[regexp "^($available_types)(?::(\[^:\]+))?" ${master_site} _ site subdir]} {
                    if {${subdir} ne "" && ${livecheck.name} eq "default"} {
                        set livecheck.name ${subdir}
                    }
                    set livecheck.type ${site}

                    break
                }
            }
        }
        # If the default type cannot be determined from the mirror, use the
        # fallback.
        if {${livecheck.type} eq "default"} {
            set livecheck.type "fallback"
        }
        if {$has_homepage} {
            if {[regexp {^http://code.google.com/p/([^/]+)} $homepage _ tag]} {
                set livecheck.type "googlecode"
            } elseif {[regexp {^http://www.gnu.org/software/([^/]+)} $homepage _ tag]} {
                set livecheck.type "gnu"
            }
        }
    }
    if {[lsearch -exact [split $available_types "|"] ${livecheck.type}] != -1} {
        # Load the defaults from _resources/port1.0/livecheck/${livecheck.type}.tcl.
        set defaults_file "$types_dir/${livecheck.type}.tcl"
        ui_debug "Loading the defaults from '$defaults_file'"
        if {[catch {source $defaults_file} result]} {
            return -code 1 "The defaults could not be loaded from '$defaults_file'."
        }
    }

    # de-escape livecheck.url
    set livecheck.url [join ${livecheck.url}]

    switch ${livecheck.type} {
        "regex" -
        "regexm" {
            # single and multiline regex
            ui_debug "Fetching ${livecheck.url}"
            if {[catch {eval curl fetch $fetch_options {${livecheck.url}} $tempfile} error]} {
                ui_error "cannot check if $name was updated ($error)"
                set updated -1
            } else {
                # let's extract the version from the file.
                set chan [open $tempfile "r"]
                set updated -1
                set the_re [join ${livecheck.regex}]
                ui_debug "The regex is \"$the_re\""
                if {${livecheck.type} == "regexm"} {
                    set data [read $chan]
                    if {[regexp $the_re $data matched updated_version]} {
                        if {$updated_version != ${livecheck.version}} {
                            set updated 1
                        } else {
                            set updated 0
                        }
                        ui_debug "The regex matched \"$matched\", extracted \"$updated_version\""
                    }
                } else {
                    set updated_version 0
                    set foundmatch 0
                    while {[gets $chan line] >= 0} {
                        if {[regexp $the_re $line matched upver]} {
                            set foundmatch 1
                            if {$updated_version == 0 || [rpm-vercomp $upver $updated_version] > 0} {
                                set updated_version $upver
                            }
                            ui_debug "The regex matched \"$matched\", extracted \"$upver\""
                        }
                    }
                    if {$foundmatch == 1} {
                        if {$updated_version == 0} {
                            set updated -1
                        } elseif {$updated_version != ${livecheck.version}} {
                            set updated 1
                        } else {
                            set updated 0
                        }
                    }
                }
                close $chan
                if {$updated < 0} {
                    ui_error "cannot check if $name was updated (regex didn't match)"
                }
            }
        }
        "md5" {
            ui_debug "Fetching ${livecheck.url}"
            if {[catch {eval curl fetch $fetch_options {${livecheck.url}} $tempfile} error]} {
                ui_error "cannot check if $name was updated ($error)"
                set updated -1
            } else {
                # let's compute the md5 sum.
                set dist_md5 [md5 file $tempfile]
                if {$dist_md5 != ${livecheck.md5}} {
                    ui_debug "md5sum for ${livecheck.url}: $dist_md5"
                    set updated 1
                }
            }
        }
        "moddate" {
            set port_moddate [file mtime ${portpath}/Portfile]
            if {[catch {set updated [curl isnewer ${livecheck.url} $port_moddate]} error]} {
                ui_error "cannot check if $name was updated ($error)"
                set updated -1
            } else {
                if {!$updated} {
                    ui_debug "${livecheck.url} is older than Portfile"
                }
            }
        }
        "none" {
        }
        default {
            ui_error "unknown livecheck.type ${livecheck.type}"
        }
    }

    file delete -force $tempfile

    if {${livecheck.type} != "none"} {
        if {$updated > 0} {
            ui_msg "$name seems to have been updated (port version: ${livecheck.version}, new version: $updated_version)"
        } elseif {$updated == 0} {
            ui_info "$name seems to be up to date"
        }
    }
}
