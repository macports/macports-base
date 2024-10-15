# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# selfupdate.tcl
#
# Copyright (c) 2016 The MacPorts Project
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

package provide selfupdate 1.0

package require macports
package require Pextlib 1.0

namespace eval selfupdate {
    namespace export main
}

proc selfupdate::can_use_https {provider} {
    global macports::os_platform macports::os_major
    switch -- $provider {
        letsencrypt {
            return [expr {${os_platform} ne "darwin" || ${os_major} == 16 || ${os_major} > 18}]
        }
        github {
            return [expr {${os_platform} ne "darwin" || ${os_major} >= 13}]
        }
    }
    return 1
}

##
# Determine the current MacPorts version from one of the configured \c
# macports::release_version_url.
#
# On success, return the current version number. On error, prints error
# messages and raises an error.
#
# @param mp_source_path Directory to use for the download
# @return current macports version on success, an error if the current version
#         could not be determined
proc selfupdate::get_current_version {mp_source_path} {
    global \
        macports::release_version_urls \
        macports::ui_prefix

    # Check for newer MacPorts versions
    ui_msg "$ui_prefix Checking for newer releases of MacPorts"

    if {![info exists release_version_urls]} {
        set release_version_urls [list]
        if {[can_use_https github]} {
            lappend release_version_urls \
                "https://raw.githubusercontent.com/macports/macports-base/master/config/RELEASE_URL"
        }
        if {[can_use_https letsencrypt]} {
            lappend release_version_urls \
                "https://distfiles.macports.org/MacPorts/RELEASE_URL" \
                "https://trac.macports.org/export/HEAD/macports-base/config/RELEASE_URL"
        } else {
            lappend release_version_urls \
                "http://distfiles.macports.org/MacPorts/RELEASE_URL"
        }
    }

    set progressflag {}
    if {$macports::portverbose} {
        set progressflag "--progress builtin"
    }
    array set selfupdate_errors {}

    foreach release_version_url $release_version_urls {
        # Try every URL until one of them succeeds or all failed
        set filename [file tail $release_version_url]
        set filepath [file join $mp_source_path $filename]
        ui_debug "Attempting to fetch version file $release_version_url"
        macports_try -pass_signal {
            curl fetch {*}$progressflag $release_version_url $filepath
        } on error {eMessage} {
            set selfupdate_errors($release_version_url) "Error downloading $release_version_url: $eMessage"
            ui_debug [set selfupdate_errors($release_version_url)]
            continue
        }

        # Read the downloaded file and attempt to extract the version
        macports_try -pass_signal {
            set fd [open $filepath r]
            if {[gets $fd line] < 0} {
                error "Could not read $filepath (or file is empty)"
            }
            # Expected format is https://github.com/macports/macports-base/releases/tag/v2.6.2
            # We extract 2.6.2
            set tag [file tail [string trim $line]]
            if {[string index $tag 0] ne "v" || [string length $tag] <= 1} {
                error "Version in $tag extracted from $line does not match expected format ^v(.+)\$"
            }
            set macports_version_new [string range $tag 1 end]
            # Successfully determined current version, break out of the loop
            break
        } on error {eMessage} {
            set selfupdate_errors($release_version_url) "Error extracting release version from $release_version_url: $eMessage"
            ui_debug [set selfupdate_errors($release_version_url)]
            continue
        }
    }
    # If macports_version_new isn't set, all available download URLs must have failed
    if {![info exists macports_version_new]} {
        ui_error "Failed to determine the current MacPorts release from any of the configured URLs:"
        foreach release_version_url [array names selfupdate_errors] {
            ui_error "  [set selfupdate_errors($release_version_url)]"
        }
        ui_error "Please check your internet connection and proxy configuration."
        error "Error determining current MacPorts release version"
    }

    return $macports_version_new
}

# Get version from extracted MacPorts source directory
proc selfupdate::get_current_version_from_sources {mp_source_path} {
    set version_file [file join $mp_source_path config macports_version]
    if {[file exists $version_file]} {
        set fd [open $version_file r]
        gets $fd macports_version_new
        close $fd
    } else {
        ui_warn "No version file found in downloaded MacPorts source code!"
        set macports_version_new 0
    }
    return $macports_version_new
}

##
# Download the MacPorts version \a macports_version_new from one of the
# mirrors, verify a detached signature against one of the public keys in
# $prefix/share/macports/keys/base and extract it into \a mp_source_path.
#
# On success, return the path to the extracted source code. On error, throws
# after printing an error message.
#
# @param mp_source_path Temporary path to use for downloading and extracting
# @param macports_version_new MacPorts version to download and extract
proc selfupdate::download_source {mp_source_path macports_version_new} {
    global \
        macports::release_urls \
        macports::ui_options \
        macports::ui_prefix

    if {![info exists release_urls]} {
        set release_urls [list]
        if {[can_use_https github]} {
            lappend release_urls \
                "https://github.com/macports/macports-base/releases/download/v{version}/MacPorts-{version}.tar.bz2"
        }
        if {[can_use_https letsencrypt]} {
            lappend release_urls \
                "https://distfiles.macports.org/MacPorts/MacPorts-{version}.tar.bz2"
        } else {
            lappend release_urls \
                "http://distfiles.macports.org/MacPorts/MacPorts-{version}.tar.bz2"
        }
    }

    #global macports::os_major macports::os_platform
    #set base_mirror_site_list [macports::getdefaultportresourcepath "port1.0/fetch/base_mirror_sites.list"]
    #set maybe_https [expr {${os_platform} eq "darwin" && ${os_major} < 10 ? "http" : "https"}]
    #macports_try -pass_signal {
    #    set fd [open $base_mirror_site_list r]
    #    while {[gets $fd base_mirror_site] >= 0} {
    #        set base_mirror_site [string trimright [string trim $base_mirror_site] /]
    #        set base_mirror_site [string map "{{maybe_https}} $maybe_https" $base_mirror_site]
    #        lappend release_urls "${base_mirror_site}/MacPorts/MacPorts-{version}.tar.bz2"
    #    }
    #    close $fd
    #} on error {eMessage} {
    #    ui_warn "Error reading mirror list: $eMessage"
    #    ui_warn "Continuing with reduced list of mirrors"
    #}

    set full_release_urls [list]
    foreach release_url $release_urls {
        lappend full_release_urls [string map [list {{version}} $macports_version_new] $release_url]
    }

    set progressflag {}
    set quietprogressflag {}
    if {$macports::portverbose} {
        set progressflag "--progress builtin"
        set quietprogressflag $progressflag
    } elseif {[info exists macports::ui_options(progress_download)]} {
        set progressflag "--progress ${macports::ui_options(progress_download)}"
    }
    array set selfupdate_errors {}

    foreach release_url $full_release_urls {
        # Try every URL until one of them succeeds or all failed
        set filename [file tail $release_url]
        set filepath [file join $mp_source_path $filename]
        set signature_url "${release_url}.sig"
        set signature_filename [file tail $signature_url]
        set signature_filepath [file join $mp_source_path $signature_filename]

        if {[file isfile $filepath] && [file isfile $signature_filepath]
            && ![catch {verify_signature $filepath $signature_filepath}]} {
            ui_msg "Verified existing file for $release_url"
            set tarball $filepath
            break
        }

        # Download source code tarball
        ui_msg "$ui_prefix Attempting to fetch MacPorts $macports_version_new source code from $release_url"
        macports_try -pass_signal {
            curl fetch {*}$progressflag $release_url $filepath
        } on error {eMessage} {
            set selfupdate_errors($release_url) "Error downloading $release_url: $eMessage"
            ui_info [set selfupdate_errors($release_url)]
            continue
        }
        # Download signature file
        macports_try -pass_signal {
            ui_info "Attempting to fetch signature from $signature_url"
            curl fetch {*}$progressflag $signature_url $signature_filepath
        } on error {eMessage} {
            set selfupdate_errors($release_url) "Error downloading signature from $signature_url: $eMessage"
            ui_info [set selfupdate_errors($release_url)]
            continue
        }

        macports_try -pass_signal {
            verify_signature $filepath $signature_filepath
        } on error {eMessage} {
            set selfupdate_errors($release_url) "Error verifying signature for $release_url: $eMessage"
            ui_info [set selfupdate_errors($release_url)]
            continue
        }

        set tarball $filepath
        break
    }
    if {![info exists tarball]} {
        ui_error "Failed to download MacPorts $macports_version_new from any of the configured mirrors:"
        foreach release_url [array names selfupdate_errors] {
            ui_error "  [set selfupdate_errors($release_url)]"
        }
        ui_error "Please check your internet connection and proxy configuration."
        error "Error downloading MacPorts $macports_version_new"
    }

    # extract tarball and move into place
    ui_msg "$ui_prefix Extracting MacPorts $macports_version_new"

    set tar [macports::findBinary tar $macports::autoconf::tar_path]
    file mkdir ${mp_source_path}/tmp
    set tarflags [macports::get_tar_flags [file extension $tarball]]
    set tar_cmd "$tar -C [macports::shellescape ${mp_source_path}/tmp] ${tarflags}xf [macports::shellescape $tarball]"
    macports_try -pass_signal {
        system $tar_cmd
    } on error {eMessage} {
        error "Failed to extract MacPorts sources from tarball: $eMessage"
    }
    file delete -force ${mp_source_path}/base
    foreach path [glob -nocomplain -tails -directory ${mp_source_path}/tmp *] {
        file rename ${mp_source_path}/tmp/${path} ${mp_source_path}/base/
    }
    file delete -force ${mp_source_path}/tmp
    # set the final extracted source path
    return ${mp_source_path}/base
}

# Download source using legacy rsync method
proc selfupdate::download_source_rsync {} {
    global macports::portdbpath \
        macports::hfscompression \
        macports::rsync_server \
        macports::rsync_dir \
        macports::rsync_options \
        macports::ui_prefix \
        macports::autoconf::rsync_path

    set rsync_url rsync://${rsync_server}/
    # are we syncing a tarball? (implies detached signature)
    if {[string range $rsync_dir end-3 end] ne ".tar"} {
        error "Selfupdate from unsigned rsync sources is no longer supported. Please update rsync_dir."
    }
    set tarballs_dir [file dirname $rsync_dir]
    append rsync_url ${tarballs_dir}/
    set mp_source_path [file join $portdbpath sources $rsync_server $tarballs_dir]
    set tarfile [file tail $rsync_dir]
    set include_options " --include=[macports::shellescape /${tarfile}] --include=[macports::shellescape /${tarfile}.rmd160] --exclude=*"
    # create the path to the to be downloaded sources if it doesn't exist
    if {![file exists $mp_source_path]} {
        file mkdir $mp_source_path
    }
    ui_debug "MacPorts sources location: $mp_source_path"

    # sync the MacPorts sources
    ui_msg "$ui_prefix Updating MacPorts base sources using rsync"
    macports_try -pass_signal {
        system "$rsync_path ${rsync_options}${include_options} [macports::shellescape $rsync_url] [macports::shellescape $mp_source_path]"
    } on error {eMessage} {
        error "Error synchronizing MacPorts sources: $eMessage"
    }

    # verify signature for tarball
    set tarball ${mp_source_path}/${tarfile}
    set signature ${tarball}.rmd160
    verify_signature_legacy $tarball $signature

    if {${hfscompression} && [getuid] == 0 &&
            ![catch {macports::binaryInPath bsdtar}] &&
            ![catch {exec bsdtar -x --hfsCompression < /dev/null >& /dev/null}]} {
        ui_debug "Using bsdtar with HFS+ compression (if valid)"
        set tar "bsdtar --hfsCompression"
    } else {
        global macports::autoconf::tar_path
        set tar [macports::findBinary tar $tar_path]
    }
    # extract tarball and move into place
    file mkdir ${mp_source_path}/tmp
    set tar_cmd "$tar -C [macports::shellescape ${mp_source_path}/tmp] -xf [macports::shellescape $tarball]"
    macports_try -pass_signal {
        system $tar_cmd
    } on error {} {
        error "Failed to extract MacPorts sources from tarball!"
    }
    file delete -force ${mp_source_path}/base
    file rename ${mp_source_path}/tmp/base ${mp_source_path}/base
    file delete -force ${mp_source_path}/tmp
    # set the final extracted source path
    return ${mp_source_path}/base
}

##
# Verify the given file \a path against the signify(1) signature in \a
# signature_path.
#
# If the signature is valid and matches one of the macports public keys, return
# success. Otherwise, raise an error.
#
# @param path The path of the file to verify
# @param signature_path The path of the detached signature file
# @return nothing on success, an error if the signature could not be verified
proc selfupdate::verify_signature {path signature_path} {
    set verified 0
    foreach pubkey [glob -nocomplain -tails -directory $macports::autoconf::macports_keys_base *.pub] {
        macports_try -pass_signal {
            set command [list \
                $macports::autoconf::signify_path -V \
                -p [file join $macports::autoconf::macports_keys_base $pubkey] \
                -x $signature_path \
                -m $path]
            ui_debug "Invoking ${command} to verify signature"
            exec {*}$command
            set verified 1
            ui_debug "$path successfully verified with public key $pubkey"
            break
        } on error {eMessage} {
            ui_debug "$path failed to verify with public key $pubkey"
            ui_debug "signify output: $eMessage"
        }
    }
    if {!$verified} {
        error "Failed to verify signature"
    }
}

# verify legacy .rmd160 signature
proc selfupdate::verify_signature_legacy {path signature_path} {
    global macports::archivefetch_pubkeys \
        macports::autoconf::openssl_path

    set openssl [macports::findBinary openssl $openssl_path]
    set verified 0
    foreach pubkey $archivefetch_pubkeys {
        macports_try -pass_signal {
            exec $openssl dgst -ripemd160 -verify $pubkey -signature $signature_path $path
            set verified 1
            ui_debug "successful verification with key $pubkey"
            break
        } on error {eMessage} {
            ui_debug "failed verification with key $pubkey"
            ui_debug "openssl output: $eMessage"
        }
    }
    if {!$verified} {
        error "Failed to verify signature for MacPorts source!"
    }
}

##
# Install a new MacPorts version from the given \a source code path.
#
# @param source Path to the source code to be installed.
proc selfupdate::install {source} {
    global \
        macports::build_arch \
        macports::developer_dir \
        macports::macos_version_major \
        macports::os_major \
        macports::prefix \
        macports::ui_prefix \
        macports::os_platform \
        tcl_platform

    # get installation user/group and permissions
    set owner [file attributes $prefix -owner]
    set group [file attributes $prefix -group]
    set perms [string range [file attributes $prefix -permissions] end-3 end]
    if {$tcl_platform(user) ne "root" && $tcl_platform(user) ne $owner} {
        error "User $tcl_platform(user) does not own $prefix - try using sudo"
    }
    ui_debug "Permissions OK"

    set configure_args [list \
                        --prefix=$prefix \
                        --with-install-user=$owner \
                        --with-install-group=$group \
                        --with-directory-mode=$perms]

    # too many users have an incompatible readline in /usr/local, see ticket #10651
    if {$os_platform ne "darwin" || $prefix eq "/usr/local"
        || ([glob -nocomplain /usr/local/lib/lib{readline,history}*] eq "" && [glob -nocomplain /usr/local/include/readline/*.h] eq "")} {
        lappend configure_args --enable-readline
    } else {
        ui_warn "Disabling readline support due to readline in /usr/local"
    }

    if {$prefix eq "/usr/local" || $prefix eq "/usr"} {
        lappend configure_args --with-unsupported-prefix
    }

    set configure_args_string [join [lmap arg $configure_args {macports::shellescape $arg}]]

    # Choose a sane compiler and SDK
    set cc_arg {}
    set sdk_arg {}
    set arch_arg {}
    set jobs [macports::get_parallel_jobs yes]
    if {$os_platform eq "darwin"} {
        catch {exec /usr/bin/cc 2>@1} output
        set output [join [lrange [split $output "\n"] 0 end-1] "\n"]
        if {[string match -nocase *license* $output]} {
            ui_error "It seems you have not accepted the Xcode license; unable to build."
            ui_error "Agree to the license by opening Xcode or running `sudo xcodebuild -license'."
            return -code error "Xcode license acceptance required"
        }

        set cc_arg "CC=/usr/bin/cc "
        if {$os_major >= 18 || ![file exists /usr/include/sys/cdefs.h]} {
            set cltpath /Library/Developer/CommandLineTools
            set sdk_version $macos_version_major
            set check_dirs [list ${cltpath}/SDKs \
                ${developer_dir}/Platforms/MacOSX.platform/Developer/SDKs \
                ${developer_dir}/SDKs]
            foreach check_dir $check_dirs {
                set sdk ${check_dir}/MacOSX${sdk_version}.sdk
                if {[file exists $sdk]} {
                    set sdk_arg "SDKROOT=[macports::shellescape ${sdk}] "
                    break
                } elseif {$os_major >= 20} {
                    set matches [glob -nocomplain -directory ${check_dir} MacOSX${sdk_version}*.sdk]
                    if {[llength $matches] > 1} {
                        set matches [lsort -decreasing -command vercmp $matches]
                    }
                    if {[llength $matches] > 0} {
                        set sdk_arg "SDKROOT=[macports::shellescape [lindex $matches 0]] "
                        break
                    }
                }
            }
        }
        if {$os_major >= 20 && $build_arch ne "x86_64" && ![catch {sysctl sysctl.proc_translated} translated] && $translated} {
            # Force a native build
            set arch_arg "/usr/bin/arch -arm64 /usr/bin/env "
        }
    }

    # do the actual configure, build and installation of new base
    ui_msg "$ui_prefix Installing new MacPorts release in $prefix as ${owner}:${group}; permissions ${perms}"
    macports_try -pass_signal {
        system -W $source "${arch_arg}${cc_arg}${sdk_arg}./configure $configure_args_string && ${arch_arg}${sdk_arg}make -j${jobs} SELFUPDATING=1 && ${arch_arg}make install SELFUPDATING=1"
    } on error {eMessage} {
        error "Error installing new MacPorts base: $eMessage"
    }
}

proc selfupdate::cleanup_sources {mp_source_path} {
    global macports::portdbpath macports::rsync_server
    set rsync_base_files [glob -nocomplain -directory [file join $portdbpath sources $rsync_server] base*]
    file delete -force $mp_source_path {*}$rsync_base_files
}

proc selfupdate::do_sync {options presync} {
    set needed_portindex 0
    set synced 0
    if {![dict exists $options ports_selfupdate_no-sync] || ![dict get $options ports_selfupdate_no-sync]} {
        set syncoptions $options
        if {$presync} {
            # updated portfiles potentially need new base to parse - tell sync to try to
            # use prefabricated PortIndex files and signal if it couldn't
            dict set syncoptions no_reindex 1
            dict set syncoptions needed_portindex_var needed_portindex
        }
        try {
            mportsync $syncoptions
        } on error {eMessage} {
            error "Couldn't sync the ports tree: $eMessage"
        }
        set synced 1
    }
    return [list $synced $needed_portindex]
}

proc selfupdate::main {{options {}} {updatestatusvar {}}} {
    global   \
            macports::autoconf::macports_version \
            macports::portdbpath \
            macports::ui_prefix

    # variable for communicating various status information to the caller:
    # whether we actually updated base, and if portindex is still required
    if {$updatestatusvar ne ""} {
        upvar $updatestatusvar updatestatus
        set updatestatus [dict create base_updated no \
                                      needed_portindex no \
                                      synced no]
    }

    set mp_source_path [file join $portdbpath sources selfupdate]
    # create the path to the to be downloaded sources if it doesn't exist
    if {![file exists $mp_source_path]} {
        file mkdir $mp_source_path
    }
    ui_debug "MacPorts sources location: $mp_source_path"

    set prefer_rsync [expr {[dict exists $options ports_selfupdate_rsync] && [dict get $options ports_selfupdate_rsync]}]
    set rsync_fetched 0
    macports_try -pass_signal {
        set macports_version_new [get_current_version $mp_source_path]
    } on error {eMessage} {
        ui_debug "get_current_version failed: $eMessage"
        set source_code [download_source_rsync]
        set macports_version_new [get_current_version_from_sources $source_code]
        set rsync_fetched 1
    }

    # Print current MacPorts version
    ui_msg "MacPorts base version $macports_version installed,"
    ui_msg "MacPorts base version $macports_version_new available."

    # check if we we need to rebuild base
    set comp [vercmp $macports_version_new $macports_version]
    if {[dict exists $options ports_force] && [dict get $options ports_force]} {
        set use_the_force_luke yes
        ui_debug "Forcing a rebuild and reinstallation of MacPorts"
    } else {
        set use_the_force_luke no
        ui_debug "Rebuilding and reinstalling MacPorts if needed"
    }

    # pre-syncing ports tree if needed (batch, shell modes)
    if {$comp > 0 && [dict exists $options ports_selfupdate_presync] && [dict get $options ports_selfupdate_presync]} {
        lassign [do_sync $options 1] synced need_reindex
        if {[info exists updatestatus]} {
            dict set updatestatus needed_portindex $need_reindex
            dict set updatestatus synced $synced
        }
    }

    # Check whether we need to re-install base because of a migration
    set migrating [expr {[dict exists $options ports_selfupdate_migrate] && [dict get $options ports_selfupdate_migrate]}]

    if {$use_the_force_luke || $comp > 0 || ($comp == 0 && $migrating)} {
        if {[dict exists $options ports_dryrun] && [dict get $options ports_dryrun]} {
            ui_msg "$ui_prefix MacPorts base is outdated, selfupdate would install $macports_version_new (dry run)"
        } else {
            ui_msg "$ui_prefix MacPorts base is outdated, installing new version $macports_version_new"

            if {!$rsync_fetched} {
                if {!$prefer_rsync} {
                    macports_try -pass_signal {
                        set source_code [download_source $mp_source_path $macports_version_new]
                    } on error {eMessage} {
                        ui_debug "download_source failed: $eMessage"
                        set prefer_rsync 1
                    }
                }
                if {$prefer_rsync} {
                    set source_code [download_source_rsync]
                    set macports_version_downloaded [get_current_version_from_sources $source_code]
                    set comp [vercmp $macports_version_downloaded $macports_version]
                }
            }
            if {$use_the_force_luke || $comp > 0 || ($comp == 0 && $migrating)} {
                install $source_code

                if {[info exists updatestatus]} {
                    dict set updatestatus base_updated yes
                }

                # Keep sources for future syncing if preferring rsync
                if {!$prefer_rsync} {
                    cleanup_sources $mp_source_path
                }
                # Return here, port.tcl will re-execute selfupdate with the updated
                # base to trigger sync and portindex with the new version
                return 0
            } else {
                ui_msg "$ui_prefix HTTP download failed and rsync does not yet have version $macports_version_new"
            }
        }
    } elseif {$comp < 0} {
        ui_msg "$ui_prefix MacPorts base is probably master or a release candidate"
    } else {
        ui_msg "$ui_prefix MacPorts base is already the latest version"
    }

    lassign [do_sync $options 0] synced
    if {[info exists updatestatus]} {
        dict set updatestatus synced $synced
    }

    return 0
}
