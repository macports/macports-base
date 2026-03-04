# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# portlivecheck.tcl
#
# Copyright (c) 2007-2011, 2014, 2016 The MacPorts Project
# Copyright (c) 2005-2007 Paul Guyot <pguyot@kallisys.net>,
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
options livecheck.url livecheck.type livecheck.md5 livecheck.regex livecheck.branch livecheck.name livecheck.distname livecheck.version livecheck.ignore_sslcert livecheck.compression livecheck.curloptions

# defaults
default livecheck.url {$homepage}
default livecheck.type default
default livecheck.md5 {}
default livecheck.regex {}
default livecheck.branch {}
default livecheck.name default
default livecheck.distname default
default livecheck.version {$version}
default livecheck.ignore_sslcert no
default livecheck.compression yes
default livecheck.curloptions [list --append-http-header "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"]

proc portlivecheck::livecheck_async_start {} {
    _livecheck_main yes
}

proc portlivecheck::_async_cleanup {} {
    variable async_job
    if {[info exists async_job]} {
        curlwrap_async_cancel $async_job
        unset async_job
    }
    variable tempfilename
    if {[info exists tempfilename]} {
        file delete -force $tempfilename
        unset tempfilename
    }
}

proc portlivecheck::_livecheck_main {{async no}} {
    global livecheck.url livecheck.type livecheck.md5 livecheck.regex livecheck.branch livecheck.name livecheck.distname livecheck.version \
           livecheck.ignore_sslcert \
           livecheck.compression \
           livecheck.curloptions \
           git.cmd \
           homepage portpath \
           master_sites name subport

    variable async_job
    variable tempfilename

    if {[info exists async_job]} {
        if {$async} {
            # Async fetch already started
            return 0
        }
        # Fetch was started asynchronously, wait for job to finish
        # Loop with a reasonable timeout so we don't wait too long
        # to handle events like signals.
        while {![curlwrap_async_is_complete $async_job 500]} {}
        lassign [curlwrap_async_result $async_job] status result
        unset async_job
        if {$status != 0} {
            ui_error "cannot check if $subport was updated ($result)"
            file delete -force $tempfilename ${tempfilename}.TMP
            unset tempfilename
            return 0
        }
        # Async fetch code appends .TMP for in-progress files. No real
        # need to rename it here when it's done.
        append tempfilename .TMP
        set async_done 1
    } else {
        set async_done 0
    }

    set updated 0
    set updated_version "unknown"
    set has_master_sites [info exists master_sites]
    set has_homepage [info exists homepage]
    if {!$has_homepage} {
        set livecheck.url {}
    }

    if {![info exists tempfilename]} {
        set tempfd [file tempfile tempfilename mports.livecheck]
        if {$async} {
            close $tempfd
            unset tempfd
        }
    }

    if {!$async} {
        ui_debug "Port (livecheck) version is ${livecheck.version}"
    }

    set curl_options ${livecheck.curloptions}
    if {[tbool livecheck.ignore_sslcert]} {
        lappend curl_options "--ignore-ssl-cert"
    }
    if {[tbool livecheck.compression]} {
        lappend curl_options "--enable-compression"
    }

    # Check _resources/port1.0/livecheck for available types.
    set types_dir [getdefaultportresourcepath "port1.0/livecheck"]
    if {[catch {set available_types [glob -directory $types_dir -tails -types f *.tcl]} result]} {
        return -code 1 "No available types were found. Check '$types_dir'."
    }

    # Convert available_types from a list of files (e.g., { freecode.tcl
    # gnu.tcl ... }) into a string in the format "type|type|..." (e.g.,
    # "freecode|gnu|...").
    set available_types [regsub -all {\.tcl} [join $available_types |] {}]

    if {${livecheck.type} eq "default"} {
        # Determine the default type from the mirror.
        if {$has_master_sites} {
            foreach {master_site} ${master_sites} {
                if {[regexp "^($available_types)(?::(\[^:\]+))?" ${master_site} _ site subdir]} {
                    set subdirs [split $subdir /]
                    if {[llength $subdirs] > 1} {
                        if {[lindex $subdirs 0] eq "project"} {
                            set subdir [lindex $subdirs 1]
                        } else {
                            set subdir ""
                        }
                    }
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
    if {${livecheck.type} in [split $available_types "|"]} {
        # Load the defaults from _resources/port1.0/livecheck/${livecheck.type}.tcl.
        set defaults_file "$types_dir/${livecheck.type}.tcl"
        ui_debug "Loading the defaults from '$defaults_file'"
        if {[catch {source $defaults_file} result]} {
            ui_debug "$::errorInfo: result"
            return -code 1 "The defaults could not be loaded from '$defaults_file'."
        }
    }

    if {$async && ${livecheck.type} ni {regex regexm md5}} {
        return 0
    }

    # de-escape livecheck.url
    set livecheck.url_str [join ${livecheck.url}]

    switch ${livecheck.type} {
        "regex" -
        "regexm" {
            # single and multiline regex
            if {!$async_done} {
                ui_debug "Fetching ${livecheck.url_str}"
                ui_debug "Using CURL options ${curl_options}"
            }
            if {$async} {
                set async_job [curlwrap_async fetch_file {} $curl_options {} \
                        [list ${livecheck.url_str}] $tempfilename]
                return 0
            }
            set updated -1
            if {!$async_done && [catch {curl fetch {*}$curl_options ${livecheck.url_str} $tempfilename} error]} {
                ui_error "cannot check if $subport was updated ($error)"
            } else {
                # let's extract the version from the file.
                set foundmatch 0
                set the_re [join ${livecheck.regex}]
                ui_debug "The regex is \"$the_re\""
                if {![info exists tempfd]} {
                    set tempfd [open $tempfilename r]
                }
                if {${livecheck.type} eq "regexm"} {
                    set data [read $tempfd]
                    if {[regexp -nocase $the_re $data matched updated_version]} {
                        set foundmatch 1
                        ui_debug "The regex matched \"$matched\", extracted \"$updated_version\""
                        if {$updated_version ne ${livecheck.version}} {
                            if {[vercmp $updated_version ${livecheck.version}] > 0} {
                                set updated 1
                            } else {
                                ui_error "livecheck failed for ${subport}: extracted version '$updated_version' is older than livecheck.version '${livecheck.version}'"
                            }
                        } else {
                            set updated 0
                        }
                    }
                } else {
                    set updated_version 0
                    while {[gets $tempfd line] >= 0} {
                        set lastoff 0
                        while {$lastoff >= 0 && [regexp -nocase -start $lastoff -indices $the_re $line offsets]} {
                            regexp -nocase -start $lastoff $the_re $line matched upver
                            set foundmatch 1
                            if {$updated_version == 0 || [vercmp $upver $updated_version] > 0} {
                                set updated_version $upver
                            }
                            ui_debug "The regex matched \"$matched\", extracted \"$upver\""
                            set lastoff [lindex $offsets end]
                        }
                    }
                    if {$foundmatch == 1} {
                        if {$updated_version ne ${livecheck.version}} {
                            if {[vercmp $updated_version ${livecheck.version}] > 0} {
                                set updated 1
                            } else {
                                ui_error "livecheck failed for ${subport}: extracted version '$updated_version' is older than livecheck.version '${livecheck.version}'"
                            }
                        } else {
                            set updated 0
                        }
                    }
                }
                if {!$foundmatch} {
                    ui_error "cannot check if $subport was updated (regex didn't match)"
                }
            }
        }
        "md5" {
            if {!$async_done} {
                ui_debug "Fetching ${livecheck.url_str}"
            }
            if {$async} {
                set async_job [curlwrap_async fetch_file {} $curl_options {} \
                        [list ${livecheck.url_str}] $tempfilename]
                return 0
            }
            if {!$async_done && [catch {curl fetch {*}$curl_options ${livecheck.url_str} $tempfilename} error]} {
                ui_error "cannot check if $subport was updated ($error)"
                set updated -1
            } else {
                # let's compute the md5 sum.
                set dist_md5 [md5 file $tempfilename]
                if {$dist_md5 ne ${livecheck.md5}} {
                    ui_debug "md5sum for ${livecheck.url_str}: $dist_md5"
                    set updated 1
                }
            }
        }
        "moddate" {
            set port_moddate [file mtime ${portpath}/Portfile]
            ui_debug "Portfile modification date is [clock format $port_moddate]"
            if {[catch {set updated [curl isnewer ${livecheck.url_str} $port_moddate]} error]} {
                ui_error "cannot check if $subport was updated ($error)"
                set updated -1
            } else {
                if {!$updated} {
                    ui_debug "${livecheck.url_str} is older than Portfile"
                }
            }
        }
        "git" {
            if {${livecheck.branch} eq {}} {
                set livecheck.branch "HEAD"
            }
            ui_debug "Getting latest commit from ${livecheck.url_str} ${livecheck.branch}"
            if {[catch {exec ${git.cmd} ls-remote ${livecheck.url_str} ${livecheck.branch}} result]} {
                ui_error "cannot check if $subport was updated ($result)"
                set updated -1
            } else {
                set updated_version [lindex [split $result] 0]
                if {$updated_version ne ${livecheck.version}} {
                    set updated 1
                }
            }
        }
        "none" {
            ui_debug "Livecheck.type is 'none'.  That's all."
        }
        default {
            ui_error "unknown livecheck.type ${livecheck.type}"
        }
    }

    if {[info exists tempfd]} {
        close $tempfd
    }
    file delete -force $tempfilename

    if {${livecheck.type} ne "none"} {
        if {$updated > 0} {
            ui_msg "$subport seems to have been updated (port version: ${livecheck.version}, new version: $updated_version)"
        } elseif {$updated == 0} {
            ui_info "$subport seems to be up to date"
        }
    }
}

proc portlivecheck::livecheck_main {args} {
    _livecheck_main no
}
