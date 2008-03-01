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

set org.macports.livecheck [target_new org.macports.livecheck livecheck_main]
target_runtype ${org.macports.livecheck} always
target_state ${org.macports.livecheck} no
target_provides ${org.macports.livecheck} livecheck
target_requires ${org.macports.livecheck} main

# define options
options livecheck.url livecheck.check livecheck.md5 livecheck.regex livecheck.name livecheck.distname livecheck.version

# defaults
default livecheck.url {$homepage}
default livecheck.check default
default livecheck.md5 ""
default livecheck.regex ""
default livecheck.name default
default livecheck.distname default
default livecheck.version {$version}

proc livecheck_main {args} {
    global livecheck.url livecheck.check livecheck.md5 livecheck.regex livecheck.name livecheck.distname livecheck.version
    global homepage portname portpath workpath
    global master_sites name distfiles
    
    set updated 0
    set updated_version "unknown"
    set has_master_sites [info exists master_sites]
    set has_homepage [info exists homepage]

    set tempfile [mktemp "/tmp/mports.livecheck.XXXXXXXX"]
    set port_moddate [file mtime ${portpath}/Portfile]

    ui_debug "Portfile modification date is [clock format $port_moddate]"
    ui_debug "Port (livecheck) version is ${livecheck.version}"

    # Determine the default type depending on the mirror.
    if {${livecheck.check} eq "default"} {
        if {$has_master_sites} {
            foreach {master_site} ${master_sites} {
                if {[regexp {^(sourceforge|freshmeat|googlecode|gnu)(?::([^:]+))?} ${master_site} _ site subdir]} {
                    if {${subdir} ne "" && ${livecheck.name} eq "default"} {
                        set livecheck.name ${subdir}
                    }
                    set livecheck.check ${site}

                    break
                }
            }
        }
        if {${livecheck.check} eq "default"} {
            set livecheck.check "freshmeat"
        }
        if {$has_homepage} {
            if {[regexp {^http://code.google.com/p/([^/]+)} $homepage _ tag]} {
                if {${livecheck.name} eq "default"} {
                    set livecheck.name $tag
                }
                set livecheck.check "googlecode"
            } elseif {[regexp {^http://www.gnu.org/software/([^/]+)} $homepage _ tag]} {
                if {${livecheck.name} eq "default"} {
                    set livecheck.name $tag
                }
                set livecheck.check "gnu"
            }
        }
    }
    if {${livecheck.name} eq "default"} {
        set livecheck.name $name
    }

    # Perform the check depending on the type.
    switch ${livecheck.check} {
        "freshmeat" {
            if {!$has_homepage || ${livecheck.url} eq ${homepage}} {
                set livecheck.url "http://freshmeat.net/projects-xml/${livecheck.name}/${livecheck.name}.xml"
            }
            if {${livecheck.regex} eq ""} {
                set livecheck.regex "<latest_release_version>(.*)</latest_release_version>"
            }
            set livecheck.check "regex"
        }
        "sourceforge" {
            if {!$has_homepage || ${livecheck.url} eq ${homepage}} {
                set livecheck.url "http://sourceforge.net/export/rss2_projfiles.php?project=${livecheck.name}"
            }
            if {${livecheck.distname} eq "default"} {
                set livecheck.distname ${livecheck.name}
            }
            if {${livecheck.regex} eq ""} {
                set livecheck.regex "<title>[quotemeta ${livecheck.distname}] (.*) released.*</title>"
            }
            set livecheck.check "regex"
        }
        "googlecode" {
            if {!$has_homepage || ${livecheck.url} eq ${homepage}} {
                set livecheck.url "http://code.google.com/p/${livecheck.name}/downloads/list"
            }
            if {${livecheck.distname} eq "default"} {
                set livecheck.distname [regsub ***=${livecheck.version} [file tail [lindex ${distfiles} 0]] (.*)]
            }
            if {${livecheck.regex} eq ""} {
                set livecheck.regex "<a href=\"http://[quotemeta ${livecheck.name}].googlecode.com/files/[quotemeta ${livecheck.distname}]\""
            }
            set livecheck.check "regex"
        }
        "gnu" {
            if {!$has_homepage || ${livecheck.url} eq ${homepage}} {
                set livecheck.url "http://ftp.gnu.org/gnu/${livecheck.name}/?C=M&O=D"
            }
            if {${livecheck.distname} eq "default"} {
                set livecheck.distname ${livecheck.name}
            }
            if {${livecheck.regex} eq ""} {
                set livecheck.regex "[quotemeta ${livecheck.distname}]-(\\\\d+(?:\\\\.\\\\d+)*)"
            }
            set livecheck.check "regex"
        }
    }
    
    # de-escape livecheck.url
    set livecheck.url [join ${livecheck.url}]
    
    switch ${livecheck.check} {
        "regex" -
        "regexm" {
            # single and multiline regex
            ui_debug "Fetching ${livecheck.url}"
            if {[catch {curl fetch ${livecheck.url} $tempfile} error]} {
                ui_error "cannot check if $portname was updated ($error)"
                set updated -1
            } else {
                # let's extract the version from the file.
                set chan [open $tempfile "r"]
                set updated -1
                set the_re [join ${livecheck.regex}]
                ui_debug "The regex is \"$the_re\""
                if {${livecheck.check} == "regexm"} {
                    set data [read $chan]
                    if {[regexp $the_re $data matched updated_version]} {
                        if {$updated_version != ${livecheck.version}} {
                            set updated 1
                        } else {
                            set updated 0
                        }
                        ui_debug "The regex matched \"$matched\""
                    }
                } else {
                    set updated_version 0
                    while {1} {
                        if {[gets $chan line] < 0} {
                            break
                        }
                        if {[regexp $the_re $line matched upver]} {
                            if {[rpm-vercomp $upver $updated_version] > 0} {
                                set updated_version $upver
                            }
                            ui_debug "The regex matched \"$matched\""
                        }
                    }
                    if {$updated_version != ${livecheck.version}} {
                        set updated 1
                    } else {
                        set updated 0
                    }
                }
                close $chan
                if {$updated < 0} {
                    ui_error "cannot check if $portname was updated (regex didn't match)"
                }
            }
        }
        "md5" {
            ui_debug "Fetching ${livecheck.url}"
            if {[catch {curl fetch ${livecheck.url} $tempfile} error]} {
                ui_error "cannot check if $portname was updated ($error)"
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
                ui_error "cannot check if $portname was updated ($error)"
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
            ui_error "unknown livecheck.check ${livecheck.check}"
        }
    }

    file delete -force $tempfile

    if {${livecheck.check} != "none"} {
        if {$updated > 0} {
            ui_msg "$portname seems to have been updated (port version: ${livecheck.version}, new version: $updated_version)"
        } elseif {$updated == 0} {
            ui_info "$portname seems to be up to date"
        }
    }
}
