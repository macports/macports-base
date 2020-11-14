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
    variable archivefetch_urls {}
}

options archive_sites archivefetch.user archivefetch.password \
    archivefetch.use_epsv archivefetch.ignore_sslcert \
    archive_sites.mirror_subdir archivefetch.pubkeys \
    archive.subdir

# user name & password
default archivefetch.user ""
default archivefetch.password ""
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
        portfetch::mirror_sites::archive_delete_la_files

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
    foreach site [array names portfetch::mirror_sites::archive_prefix] {
        set missing 0
        foreach var {archive_frameworks_dir archive_applications_dir archive_type archive_cxx_stdlib archive_delete_la_files} {
            if {![info exists portfetch::mirror_sites::${var}($site)]} {
                ui_warn "no $var configured for site '$site'"
                set missing 1
            }
        }
        if {$missing} {
            continue
        }
        if {$portfetch::mirror_sites::sites($site) ne {} &&
            $portfetch::mirror_sites::archive_prefix($site) eq $prefix_frozen &&
            $portfetch::mirror_sites::archive_frameworks_dir($site) eq $frameworks_dir_frozen &&
            $portfetch::mirror_sites::archive_applications_dir($site) eq $applications_dir_frozen &&
            $portfetch::mirror_sites::archive_cxx_stdlib($site) eq $cxx_stdlib &&
            $portfetch::mirror_sites::archive_delete_la_files($site) eq $delete_la_files &&
            ![catch {archiveTypeIsSupported $portfetch::mirror_sites::archive_type($site)}]} {
            # using the archive type as a tag
            lappend ret ${site}::$portfetch::mirror_sites::archive_type($site)
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
    global all_archive_files archivefetch.fulldestpath archive_sites
    upvar $urls fetch_urls

    # Define archive directory path
    set archivefetch.fulldestpath [file join [option portdbpath] incoming/verified]
    set archive.rootname [file rootname [get_portimage_name]]

    foreach entry [option archive_sites] {
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


# Perform a standard fetch, assembling fetch urls from
# the listed url variable and associated archive file
proc portarchivefetch::fetchfiles {args} {
    global archivefetch.fulldestpath UI_PREFIX \
           archivefetch.user archivefetch.password archivefetch.use_epsv \
           archivefetch.ignore_sslcert \
           portverbose ports_binary_only
    variable archivefetch_urls
    variable ::portfetch::urlmap

    if {![file isdirectory ${archivefetch.fulldestpath}]} {
        if {[catch {file mkdir ${archivefetch.fulldestpath}} result]} {
            elevateToRoot "archivefetch"
            set elevated yes
            if {[catch {file mkdir ${archivefetch.fulldestpath}} result]} {
                return -code error [format [msgcat::mc "Unable to create archive path: %s"] $result]
            }
        }
    }
    set incoming_path [file join [option portdbpath] incoming]
    chownAsRoot $incoming_path
    if {[info exists elevated] && $elevated eq "yes"} {
        dropPrivileges
    }

    set fetch_options [list]
    if {[string length ${archivefetch.user}] || [string length ${archivefetch.password}]} {
        lappend fetch_options -u
        lappend fetch_options "${archivefetch.user}:${archivefetch.password}"
    }
    if {${archivefetch.use_epsv} ne "yes"} {
        lappend fetch_options "--disable-epsv"
    }
    if {${archivefetch.ignore_sslcert} ne "no"} {
        lappend fetch_options "--ignore-ssl-cert"
    }
    if {$portverbose eq "yes"} {
        lappend fetch_options "--progress"
        lappend fetch_options "builtin"
    } else {
        lappend fetch_options "--progress"
        lappend fetch_options "ui_progress_download"
    }
    set sorted no

    set existing_archive [find_portarchive_path]

    foreach {url_var archive} $archivefetch_urls {
        if {![file isfile ${archivefetch.fulldestpath}/${archive}] && $existing_archive eq ""} {
            ui_info "$UI_PREFIX [format [msgcat::mc "%s doesn't seem to exist in %s"] $archive ${archivefetch.fulldestpath}]"
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
            set failed_sites 0
            unset -nocomplain fetched
            set lastError ""
            foreach site $urlmap($url_var) {
                if {[string index $site end] ne "/"} {
                    append site "/[option archive.subdir]"
                } else {
                    append site [option archive.subdir]
                }
                ui_msg "$UI_PREFIX [format [msgcat::mc "Attempting to fetch %s from %s"] $archive ${site}]"
                set file_url [portfetch::assemble_url $site $archive]
                set effectiveURL ""
                try {
                    curl fetch --effective-url effectiveURL {*}$fetch_options $file_url "${incoming_path}/${archive}.TMP"
                    set fetched 1
                    break
                } catch {{POSIX SIG SIGINT} eCode eMessage} {
                    ui_debug [msgcat::mc "Aborted fetching archive due to SIGINT"]
                    file delete -force "${incoming_path}/${archive}.TMP"
                    throw
                } catch {{POSIX SIG SIGTERM} eCode eMessage} {
                    ui_debug [msgcat::mc "Aborted fetching archive due to SIGTERM"]
                    file delete -force "${incoming_path}/${archive}.TMP"
                    throw
                } catch {{*} eCode eMessage} {
                    ui_debug [msgcat::mc "Fetching archive failed: %s" $eMessage]
                    set lastError $eMessage
                    file delete -force "${incoming_path}/${archive}.TMP"
                    incr failed_sites
                    if {$failed_sites > 2 && ![tbool ports_binary_only] && ![_archive_available]} {
                        break
                    }
                }
            }
            if {[info exists fetched]} {
                # there should be an rmd160 digest of the archive signed with one of the trusted keys
                set signature "${incoming_path}/${archive}.rmd160"
                ui_msg "$UI_PREFIX [format [msgcat::mc "Attempting to fetch %s from %s"] ${archive}.rmd160 $site]"
                # reusing $file_url from the last iteration of the loop above
                if {[catch {curl fetch --effective-url effectiveURL {*}$fetch_options ${file_url}.rmd160 $signature} result]} {
                    ui_debug "$::errorInfo"
                    return -code error "Failed to fetch signature for archive: $result"
                }
                set openssl [findBinary openssl $portutil::autoconf::openssl_path]
                set verified 0
                foreach pubkey [option archivefetch.pubkeys] {
                    if {![catch {exec $openssl dgst -ripemd160 -verify $pubkey -signature $signature "${incoming_path}/${archive}.TMP"} result]} {
                        set verified 1
                        break
                    } else {
                        ui_debug "failed verification with key $pubkey"
                        ui_debug "openssl output: $result"
                    }
                }
                file delete -force $signature
                if {!$verified} {
                    # fall back to building from source (or error out later if binary only mode)
                    ui_warn "Failed to verify signature for archive!"
                    file delete -force "${incoming_path}/${archive}.TMP"
                    break
                } elseif {[catch {file rename -force "${incoming_path}/${archive}.TMP" "${archivefetch.fulldestpath}/${archive}"} result]} {
                    ui_debug "$::errorInfo"
                    return -code error "Failed to move downloaded archive into place: $result"
                }
                set archive_exists 1
                break
            }
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
        return 0
    }
    if {([info exists ports_binary_only] && $ports_binary_only eq "yes") || [_archive_available]} {
        if {[info exists lastError] && $lastError ne ""} {
            error [msgcat::mc "version @[option version]_[option revision][option portvariants]: %s" $lastError]
        } else {
            error "version @[option version]_[option revision][option portvariants]"
        }
    } else {
        return 0
    }
}

# Initialize archivefetch target and call checkfiles.
#proc portarchivefetch::archivefetch_init {args} {
#    return 0
#}

proc portarchivefetch::archivefetch_start {args} {
    variable archivefetch_urls
    global UI_PREFIX subport all_archive_files destroot target_state_fd \
           ports_source_only ports_binary_only
    if {![tbool ports_source_only] && ([tbool ports_binary_only] ||
            !([check_statefile target org.macports.destroot $target_state_fd] && [file isdirectory $destroot]))} {
        portarchivefetch::checkfiles archivefetch_urls
    }
    if {[info exists all_archive_files] && [llength $all_archive_files] > 0} {
        ui_msg "$UI_PREFIX [format [msgcat::mc "Fetching archive for %s"] $subport]"
    } elseif {[tbool ports_binary_only]} {
        error "Binary-only mode requested with no usable archive sites configured"
    }
    portfetch::check_dns
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
