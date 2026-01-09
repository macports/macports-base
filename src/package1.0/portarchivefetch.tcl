# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
#
# Copyright (c) 2002 - 2003 Apple Inc.
# Copyright (c) 2004 - 2016, 2018 The MacPorts Project
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
#

package provide portarchivefetch 1.0
package require fetch_common 1.0
package require portutil 1.0
package require Pextlib 1.0

set org.macports.archivefetch [target_new org.macports.archivefetch portarchivefetch::archivefetch_main]
#target_init ${org.macports.archivefetch} portarchivefetch::archivefetch_init
target_provides ${org.macports.archivefetch} archivefetch
target_requires ${org.macports.archivefetch} main
target_runtype ${org.macports.archivefetch} always
target_prerun ${org.macports.archivefetch} portarchivefetch::archivefetch_start

namespace eval portarchivefetch {
    # List of URLs to attempt, filled in by checkarchivefiles
    variable archivefetch_urls {}
    # Whether fetching an archive has been attempted. Used to print an
    # explanatory message when an archive was not available.
    variable attempted 0
}

options archive_sites archivefetch.user archivefetch.password \
    archivefetch.use_epsv archivefetch.ignore_sslcert \
    archive_sites.mirror_subdir archivefetch.pubkeys \
    archive.subdir

# user name & password
default archivefetch.user {}
default archivefetch.password {}
# Use EPSV for FTP transfers
default archivefetch.use_epsv no
# Ignore SSL certificate
default archivefetch.ignore_sslcert no
default archivefetch.pubkeys {$archivefetch_pubkeys}

default archive_sites {[portarchivefetch::filter_sites]}
default archive_sites.listfile archive_sites.tcl
default archive_sites.listpath port1.0/fetch
default archive.subdir {${subport}}

proc portarchivefetch::filter_sites {} {
    global prefix_frozen frameworks_dir_frozen applications_dir_frozen porturl \
        cxx_stdlib delete_la_files \
        portfetch::mirror_sites::sites portfetch::mirror_sites::archive_type \
        portfetch::mirror_sites::archive_prefix \
        portfetch::mirror_sites::archive_frameworks_dir \
        portfetch::mirror_sites::archive_applications_dir \
        portfetch::mirror_sites::archive_cxx_stdlib \
        portfetch::mirror_sites::archive_delete_la_files  \
        portfetch::mirror_sites::archive_sigtype \
        portfetch::mirror_sites::archive_pubkey

    # get defaults from ports tree resources
    set mirrorfile [get_full_archive_sites_path]
    if {[file exists $mirrorfile]} {
        source $mirrorfile
    }
    # get archive_sites.conf values
    foreach {key val} [get_archive_sites_conf_values] {
        set $key $val
    }

    set ret [list]
    foreach site [array names archive_prefix] {
        set missing 0
        foreach var {archive_frameworks_dir archive_applications_dir archive_type archive_cxx_stdlib archive_delete_la_files} {
            if {![info exists ${var}($site)]} {
                ui_warn "no $var configured for site '$site'"
                set missing 1
            }
        }
        if {$missing} {
            continue
        }
        # The paths in the portfile vars are fully resolved, so resolve
        # these too before comparing them.
        foreach var {archive_prefix archive_frameworks_dir archive_applications_dir} {
            if {[catch {set ${var}_norm [realpath [set ${var}($site)]]}]} {
                set ${var}_norm [file normalize [set ${var}($site)]]
            }
        }
        if {$sites($site) ne {} &&
            $archive_prefix_norm eq $prefix_frozen &&
            $archive_frameworks_dir_norm eq $frameworks_dir_frozen &&
            $archive_applications_dir_norm eq $applications_dir_frozen &&
            $archive_cxx_stdlib($site) eq $cxx_stdlib &&
            $archive_delete_la_files($site) eq $delete_la_files &&
            ![catch {archiveTypeIsSupported $archive_type($site)}]} {
            # using the archive type as a tag
            lappend ret ${site}::$archive_type($site)
        }
    }

    # check if porturl itself points to an archive
    if {![catch {get_portimage_name} portimage_name] && [file rootname [file tail $porturl]] eq [file rootname $portimage_name] && [file extension $porturl] ne ""} {
        lappend ret [string range $porturl 0 end-[string length [file tail $porturl]]]:[string range [file extension $porturl] 1 end]
        archive.subdir
    }
    return $ret
}

set_ui_prefix

# Checks possible archive files to assemble url lists for later fetching
proc portarchivefetch::checkarchivefiles {urls} {
    global all_archive_files archivefetch.fulldestpath archive_sites portdbpath
    upvar $urls fetch_urls

    # Define archive directory path
    set archivefetch.fulldestpath [file join ${portdbpath} incoming/verified]
    set archive.rootname [file rootname [get_portimage_name]]

    foreach entry ${archive_sites} {
        # the archive type is used as a tag
        set type [lindex [split $entry :] end]
        if {![info exists seen($type)]} {
            set archive.file "${archive.rootname}.${type}"
            lappend all_archive_files ${archive.file}
            lappend fetch_urls $type ${archive.file}
            set seen($type) 1
        }
    }
}

# returns full path to mirror list file
proc portarchivefetch::get_full_archive_sites_path {} {
    global archive_sites.listfile archive_sites.listpath porturl
    # look up archive sites only from this ports tree,
    # do not fallback to the default
    return [getportresourcepath $porturl [file join ${archive_sites.listpath} ${archive_sites.listfile}] no]
}

# Perform the full checksites/checkarchivefiles sequence.
proc portarchivefetch::checkfiles {urls} {
    upvar $urls fetch_urls

    portfetch::checksites [list archive_sites [list {} ARCHIVE_SITE_LOCAL]] \
                          [get_full_archive_sites_path]
    checkarchivefiles fetch_urls
}


# Return all signature types that may be used with the configured sites
proc portarchivefetch::get_all_sigtypes {} {
    global archive_sites portfetch::mirror_sites::archive_sigtype
    set sigtypes [dict create]
    foreach site $archive_sites {
        # If the entry is a URL rather than a mirror site name then
        # this will actually extract the URL scheme, but that's OK
        # since it won't exist in the array and will be skipped.
        set site [lindex [split $site :] 0]
        if {[info exists archive_sigtype($site)]} {
            dict set sigtypes $archive_sigtype($site) 1
        }
    }
    if {[dict size $sigtypes] > 0} {
        return [dict keys $sigtypes]
    } else {
        # Legacy default
        return rmd160
    }
}

# Verify signature for a fetched archive using any of the public keys
# set for each archive site or in pubkeys.conf.
proc portarchivefetch::verify_signature {archive_path sig_path} {
    global archive_sites archivefetch.pubkeys \
           portfetch::mirror_sites::archive_sigtype \
           portfetch::mirror_sites::archive_pubkey

    # Chop off the .TMP before getting extension
    set archivetype [file extension [file rootname $archive_path]]
    set sigtype [file extension $sig_path]
    set pubkeys [dict create]
    foreach site $archive_sites {
        set site_split [split $site :]
        set site [lindex $site_split 0]
        set tag [lindex $site_split end]
        if {".$tag" eq $archivetype && [info exists archive_sigtype($site)]
            && [info exists archive_pubkey($site)]
            && ".$archive_sigtype($site)" eq $sigtype
        } then {
            # Use dict to avoid duplicates if a key is added in both
            # the archive site definition and pubkeys.conf.
            dict set pubkeys $archive_pubkey($site) 1
        }
    }
    foreach pubkey ${archivefetch.pubkeys} {
        set keytype [file extension $pubkey]
        if {($keytype eq ".pub" && $sigtype eq ".sig") || ($keytype eq ".pem" && $sigtype eq ".rmd160")} {
            dict set pubkeys $pubkey 1
        }
    }

    # Succeed if the signature can be verified with any of the keys
    foreach pubkey [dict keys $pubkeys] {
        if {($sigtype eq ".sig" && [verify_signature_signify $archive_path $pubkey $sig_path])
            || ($sigtype eq ".rmd160" && [verify_signature_openssl $archive_path $pubkey $sig_path])
        } then {
            return 1
        }
    }
    return 0
}

# Perform a standard fetch, assembling fetch urls from
# the listed url variable and associated archive file
proc portarchivefetch::fetchfiles {{async no} args} {
    global UI_PREFIX archivefetch.fulldestpath archivefetch.user \
           archivefetch.password archivefetch.use_epsv \
           archivefetch.ignore_sslcert archive.subdir portverbose \
           ports_binary_only portdbpath force_archive_refresh
    variable archivefetch_urls
    variable ::portfetch::urlmap
    variable async_job

    if {[info exists async_job]} {
        if {$async} {
            # Async fetch already started
            return 0
        }
        # Fetch was started asynchronously, wait for job to finish
        if {![curlwrap_async_is_complete $async_job]} {
            # Display progress for this fetch while waiting for it to finish
            curlwrap_async_show_progress $async_job
            # Loop with a reasonable timeout so we don't wait too long
            # to handle events like signals.
            while {![curlwrap_async_is_complete $async_job 500]} {}
        }
        lassign [curlwrap_async_result $async_job] status result
        unset async_job
        if {$status != 0} {
            if {[tbool ports_binary_only] || [_archive_available]} {
                error "Failed to fetch archive for [option subport]: $result"
            } else {
                variable attempted 1
                return 0
            }
        }
        set async_done 1
    } else {
        set async_done 0
    }

    if {![file isdirectory ${archivefetch.fulldestpath}]} {
        if {[catch {file mkdir ${archivefetch.fulldestpath}} result]} {
            elevateToRoot "archivefetch"
            set elevated yes
            if {[catch {file mkdir ${archivefetch.fulldestpath}} result]} {
                return -code error [format [msgcat::mc "Unable to create archive path: %s"] $result]
            }
        }
    }
    set incoming_path [file join ${portdbpath} incoming]
    chownAsRoot $incoming_path
    if {[info exists elevated] && $elevated eq "yes"} {
        dropPrivileges
    }

    set fetch_options [list]
    set credentials {}
    if {[string length ${archivefetch.user}] || [string length ${archivefetch.password}]} {
        set credentials ${archivefetch.user}:${archivefetch.password}
    }
    if {${archivefetch.use_epsv} ne "yes"} {
        lappend fetch_options "--disable-epsv"
    }
    if {${archivefetch.ignore_sslcert} ne "no"} {
        lappend fetch_options "--ignore-ssl-cert"
    }
    if {!$async} {
        if {$portverbose eq "yes"} {
            lappend fetch_options "--progress"
            lappend fetch_options "builtin"
        } else {
            lappend fetch_options "--progress"
            lappend fetch_options "ui_progress_download"
        }
    }
    set sorted no

    set existing_archive [find_portarchive_path]
    if {$existing_archive eq "" && ![tbool force_archive_refresh]
        && [file isdirectory [file rootname [get_portimage_path]]]} {
        set existing_archive yes
    }

    foreach {url_var archive} $archivefetch_urls {
        if {![file isfile ${archivefetch.fulldestpath}/${archive}] && $existing_archive eq ""} {
            if {!$async && !$async_done} {
                ui_info "$UI_PREFIX [format [msgcat::mc "%s doesn't seem to exist in %s"] $archive ${archivefetch.fulldestpath}]"
            }
            if {![file writable ${archivefetch.fulldestpath}]} {
                return -code error [format [msgcat::mc "%s must be writable"] ${archivefetch.fulldestpath}]
            }
            if {![file writable $incoming_path]} {
                return -code error [format [msgcat::mc "%s must be writable"] $incoming_path]
            }
            if {!$sorted} {
                portfetch::sortsites archivefetch_urls archive_sites
                set sorted yes
            }
            if {![info exists urlmap($url_var)]} {
                ui_error [format [msgcat::mc "No defined site for tag: %s, using archive_sites"] $url_var]
                set urlmap($url_var) $urlmap(archive_sites)
            }
            if {![info exists sigtypes]} {
                set sigtypes [get_all_sigtypes]
            }
            set archive_tmp_path ${incoming_path}/${archive}.TMP
            set failed_sites 0
            set archive_fetched [expr {$async_done ? [file isfile $archive_tmp_path] : 0}]
            set lastError ""
            set sig_fetched 0
            if {$async_done} {
                foreach sigtype $sigtypes {
                    set signature ${incoming_path}/${archive}.${sigtype}
                    if {[file isfile $signature]} {
                        set sig_fetched 1
                        break
                    }
                }
            }
            if {$async} {
                file delete -force ${incoming_path}/${archive}.TMP
                touch ${incoming_path}/${archive}.TMP
                chownAsRoot ${incoming_path}/${archive}.TMP
                foreach sigtype $sigtypes {
                    file delete -force ${incoming_path}/${archive}.${sigtype}
                    touch ${incoming_path}/${archive}.${sigtype}
                    chownAsRoot ${incoming_path}/${archive}.${sigtype}
                }
                if {[tbool ports_binary_only] || [_archive_available]} {
                    set this_urlmap $urlmap($url_var)
                    set maxfails 0
                } else {
                    set this_urlmap [lrange $urlmap($url_var) 0 2]
                    set maxfails 3
                }
                set async_job [curlwrap_async fetch_archive $credentials $fetch_options $this_urlmap \
                        [lmap site $this_urlmap {portfetch::assemble_url \
                        [expr {[string index $site end] eq "/" ? $site : "${site}/"}]${archive.subdir} $archive}] \
                        ${incoming_path}/${archive} $sigtypes $maxfails]
                return 0
            } else {
                foreach site $urlmap($url_var) {
                    set orig_site $site
                    if {[string index $site end] ne "/"} {
                        append site /
                    }
                    append site ${archive.subdir}
                    set file_url [portfetch::assemble_url $site $archive]
                    # fetch archive
                    if {!$archive_fetched} {
                        ui_msg "$UI_PREFIX [format [msgcat::mc "Attempting to fetch %s from %s"] $archive ${site}]"
                        try {
                            curlwrap fetch $orig_site $credentials {*}$fetch_options $file_url $archive_tmp_path
                            set archive_fetched 1
                        } trap {POSIX SIG SIGINT} {_ eOptions} {
                            ui_debug [msgcat::mc "Aborted fetching archive due to SIGINT"]
                            file delete -force $archive_tmp_path
                            throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
                        } trap {POSIX SIG SIGTERM} {_ eOptions} {
                            ui_debug [msgcat::mc "Aborted fetching archive due to SIGTERM"]
                            file delete -force $archive_tmp_path
                            throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
                        } on error {eMessage} {
                            ui_debug [msgcat::mc "Fetching archive failed: %s" $eMessage]
                            set lastError $eMessage
                            file delete -force $archive_tmp_path
                            incr failed_sites
                            if {$failed_sites > 2 && ![tbool ports_binary_only] && ![_archive_available]} {
                                break
                            }
                        }
                    }
                    # fetch signature
                    if {$archive_fetched && !$sig_fetched} {
                        # TODO: record signature type for each URL somehow
                        foreach sigtype $sigtypes {
                            set signature ${incoming_path}/${archive}.${sigtype}
                            ui_msg "$UI_PREFIX [format [msgcat::mc "Attempting to fetch %s from %s"] ${archive}.${sigtype} $site]"
                            try {
                                curlwrap fetch $orig_site $credentials {*}$fetch_options ${file_url}.${sigtype} $signature
                                set sig_fetched 1
                                break
                            } trap {POSIX SIG SIGINT} {_ eOptions} {
                                ui_debug [msgcat::mc "Aborted fetching archive due to SIGINT"]
                                file delete -force $archive_tmp_path $signature
                                throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
                            } trap {POSIX SIG SIGTERM} {_ eOptions} {
                                ui_debug [msgcat::mc "Aborted fetching archive due to SIGTERM"]
                                file delete -force $archive_tmp_path $signature
                                throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
                            } on error {eMessage} {
                                ui_debug [msgcat::mc "Fetching archive signature failed: %s" $eMessage]
                                set lastError $eMessage
                                file delete -force $signature
                            }
                        }
                        if {$sig_fetched} {
                            break
                        }
                    }
                }
                if {$archive_fetched && $sig_fetched} {
                    set verified [verify_signature $archive_tmp_path $signature]
                    file delete -force $signature
                    if {!$verified} {
                        # fall back to building from source (or error out later if binary only mode)
                        ui_warn "Failed to verify signature for archive!"
                        file delete -force $archive_tmp_path
                        break
                    } elseif {[catch {file rename -force $archive_tmp_path ${archivefetch.fulldestpath}/${archive}} result]} {
                        ui_debug "$::errorInfo"
                        return -code error "Failed to move downloaded archive into place: $result"
                    }
                    set archive_exists 1
                    break
                }
            }
        } elseif {$async} {
            return 0
        } else {
            set archive_exists 1
            break
        }
    }
    if {[info exists archive_exists]} {
        # modify state file to skip remaining phases up to destroot
        global target_state_fd
        foreach target {archivefetch fetch checksum extract patch configure build destroot} {
            write_statefile target "org.macports.${target}" $target_state_fd
        }
        # Cancel any async distfile fetch that may be in progress
        portfetch::_async_cleanup
        return 0
    }
    if {[tbool ports_binary_only] || [_archive_available]} {
        global version revision portvariants
        if {[info exists lastError] && $lastError ne ""} {
            error [msgcat::mc "version @${version}_${revision}${portvariants}: %s" $lastError]
        } else {
            error "version @${version}_${revision}${portvariants}"
        }
    } else {
        variable attempted 1
        return 0
    }
}

# Start asynchronous fetch of archive
proc portarchivefetch::archivefetch_async_start {} {
    global all_archive_files
    _archivefetch_start yes
    if {![info exists all_archive_files]} {
        # No files to fetch
        return 0
    }
    fetchfiles yes
}

proc portarchivefetch::_async_cleanup {} {
    variable async_job
    if {[info exists async_job]} {
        curlwrap_async_cancel $async_job
        unset async_job
    }
}

# Initialize archivefetch target and call checkfiles.
#proc portarchivefetch::archivefetch_init {args} {
#    return 0
#}

proc portarchivefetch::_archivefetch_start {quiet} {
    variable archivefetch_urls
    global UI_PREFIX subport all_archive_files destroot target_state_fd \
           ports_source_only ports_binary_only
    if {![tbool ports_source_only] && ([tbool ports_binary_only] ||
            !([info exists target_state_fd] && [file isdirectory $destroot]
              && [check_statefile target org.macports.destroot $target_state_fd]))} {
        portarchivefetch::checkfiles archivefetch_urls
    }
    if {[info exists all_archive_files] && [llength $all_archive_files] > 0} {
        if {!$quiet} {
            ui_msg "$UI_PREFIX [format [msgcat::mc "Fetching archive for %s"] $subport]"
        }
    } elseif {[tbool ports_binary_only]} {
        error "Binary-only mode requested with no usable archive sites configured"
    }
    portfetch::check_dns
}

proc portarchivefetch::archivefetch_start {args} {
    _archivefetch_start no
}

# Main archive fetch routine
# just calls the standard fetchfiles procedure
proc portarchivefetch::archivefetch_main {args} {
    global all_archive_files
    if {[info exists all_archive_files] && [llength $all_archive_files] > 0} {
        # Fetch the files
        portarchivefetch::fetchfiles
    }
    return 0
}
