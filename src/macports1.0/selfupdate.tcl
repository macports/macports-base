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
        macports::release_version_url \
        macports::ui_prefix

    # Check for newer MacPorts versions
    ui_msg "$macports::ui_prefix Checking for newer releases of MacPorts"

    if {![info exists macports::release_version_url]} {
        set macports::release_version_url [list \
            "https://raw.githubusercontent.com/macports/macports-base/master/config/RELEASE_URL" \
            "https://trac.macports.org/export/HEAD/macports-base/config/RELEASE_URL" \
            "https://distfiles.macports.org/MacPorts/RELEASE_URL" \
        ]
    }

    set progressflag {}
    if {$macports::portverbose} {
        set progressflag "--progress builtin"
    }
    array set selfupdate_errors {}

    foreach release_version_url $macports::release_version_url {
        # Try every URL until one of them succeeds or all failed
        set filename [file tail $release_version_url]
        set filepath [file join $mp_source_path $filename]
        ui_debug "Attempting to fetch version file $release_version_url"
        try -pass_signal {
            curl fetch {*}$progressflag $release_version_url $filepath
        } catch {{*} eCode eMessage} {
            set selfupdate_errors($release_version_url) "Error downloading $release_version_url: $eMessage"
            ui_debug [set selfupdate_errors($release_version_url)]
            continue
        }

        # Read the downloaded file and attempt to extract the version
        try -pass_signal {
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
        } catch {{*} eCode eMessage} {
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
        macports::autoconf::tar_path \
        macports::os_major \
        macports::os_platform \
        macports::release_url \
        macports::ui_options \
        macports::ui_prefix

    if {![info exists macports::release_url]} {
        set macports::release_url [list \
            "https://github.com/macports/macports-base/releases/download/v{version}/MacPorts-{version}.tar.bz2" \
        ]
    }

    set base_mirror_site_list [macports::getdefaultportresourcepath "port1.0/fetch/base_mirror_sites.list"]
    set maybe_https [expr {${macports::os_platform} eq "darwin" && ${macports::os_major} < 10 ? "http" : "https"}]
    try -pass_signal {
        set fd [open $base_mirror_site_list r]
        while {[gets $fd base_mirror_site] >= 0} {
            set base_mirror_site [string trimright [string trim $base_mirror_site] /]
            set base_mirror_site [string map "{{maybe_https}} $maybe_https" $base_mirror_site]
            lappend macports::release_url "${base_mirror_site}/MacPorts/MacPorts-{version}.tar.bz2"
        }
        close $fd
    }  catch {{*} eCode eMessage} {
        ui_warn "Error reading mirror list: $eMessage"
        ui_warn "Continuing with reduced list of mirrors"
    }

    set release_urls {}
    foreach release_url $macports::release_url {
        lappend release_urls [string map "{{version}} $macports_version_new" $release_url]
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

    foreach release_url $release_urls {
        # Try every URL until one of them succeeds or all failed
        set filename [file tail $release_url]
        set filepath [file join $mp_source_path $filename]
        set signature_url "$release_url.sig"
        set signature_filename [file tail $signature_url]
        set signature_filepath [file join $mp_source_path $signature_filename]

        # Download source code tarball
        ui_msg "$macports::ui_prefix Attempting to fetch MacPorts $macports_version_new source code from $release_url"
        try -pass_signal {
            curl fetch {*}$progressflag $release_url $filepath
        } catch {{*} eCode eMessage} {
            set selfupdate_errors($release_url) "Error downloading $release_url: $eMessage"
            ui_info [set selfupdate_errors($release_url)]
            continue
        }
        # Download signature file
        try -pass_signal {
            ui_info "Attempting to fetch signature from $signature_url"
            curl fetch {*}$progressflag $signature_url $signature_filepath
        } catch {{*} eCode eMessage} {
            set selfupdate_errors($release_url) "Error downloading signature from $signature_url: $eMessage"
            ui_info [set selfupdate_errors($release_url)]
            continue
        }

        try -pass_signal {
            selfupdate::verify_signature $filepath $signature_filepath
        } catch {{*} eCode eMessage} {
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
    ui_msg "$macports::ui_prefix Extracting MacPorts $macports_version_new"

    set tar [macports::findBinary tar $macports::autoconf::tar_path]
    file mkdir ${mp_source_path}/tmp
    set tar_cmd "$tar -C ${mp_source_path}/tmp -xf $tarball"
    try -pass_signal {
        system $tar_cmd
    } catch {{*} eCode eMessage} {
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
    global \
        macports::autoconf::macports_keys_base \
        macports::autoconf::signify_path

    set verified 0
    foreach pubkey [glob -nocomplain -tails -directory $macports::autoconf::macports_keys_base *.pub] {
        try -pass_signal {
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
        } catch {{*} eCode eMessage} {
            ui_debug "$path failed to verify with public key $pubkey"
            ui_debug "signify output: $eMessage"
        }
    }
    if {!$verified} {
        error "Failed to verify signature"
    }
}

##
# Install a new MacPorts version from the given \a source code path.
#
# @param source Path to the source code to be installed.
proc selfupdate::install {source} {
    global \
        macports::prefix \
        macports::ui_prefix \
        tcl_platform

    # get installation user/group and permissions
    set owner [file attributes $macports::prefix -owner]
    set group [file attributes $macports::prefix -group]
    set perms [string range [file attributes $macports::prefix -permissions] end-3 end]
    if {$tcl_platform(user) ne "root" && $tcl_platform(user) ne $owner} {
        error "User $tcl_platform(user) does not own $prefix - try using sudo"
    }
    ui_debug "Permissions OK"

    set configure_args [list]
    lappend configure_args "--prefix=$macports::prefix"
    lappend configure_args "--with-install-user=$owner"
    lappend configure_args "--with-install-group=$group"
    lappend configure_args "--with-directory-mode=$perms"

    # too many users have an incompatible readline in /usr/local, see ticket #10651
    if {$tcl_platform(os) ne "Darwin" || $prefix eq "/usr/local"
        || ([glob -nocomplain /usr/local/lib/lib{readline,history}*] eq "" && [glob -nocomplain /usr/local/include/readline/*.h] eq "")} {
        lappend configure_args "--enable-readline"
    } else {
        ui_warn "Disabling readline support due to readline in /usr/local"
    }

    if {$macports::prefix eq "/usr/local" || $macports::prefix eq "/usr"} {
        lappend configure_args "--with-unsupported-prefix"
    }

    set configure_args_string ""
    foreach configure_arg $configure_args {
        append configure_args_string " " [macports::shellescape $configure_arg]
    }

    # Choose a sane compiler
    set cc_arg {}
    if {$::macports::os_platform eq "darwin"} {
        set cc_arg "CC=/usr/bin/cc "
    }

    # do the actual configure, build and installation of new base
    ui_msg "$macports::ui_prefix Installing new MacPorts release in $macports::prefix as ${owner}:${group}; permissions ${perms}"
    try -pass_signal {
        system -W $source "${cc_arg}./configure $configure_args_string && make SELFUPDATING=1 && make install SELFUPDATING=1"
    } catch {{*} eCode eMessage} {
        error "Error installing new MacPorts base: $eMessage"
    }
}

proc selfupdate::main {{optionslist {}} {updatestatusvar {}}} {
    global \
        macports::autoconf::macports_version \
        macports::autoconf::openssl_path \
        macports::autoconf::tar_path \
        macports::portdbpath \
        macports::prefix \
        tcl_platform
    array set options $optionslist

    # variable that indicates whether we actually updated base
    if {$updatestatusvar ne ""} {
        upvar $updatestatusvar updatestatus
        set updatestatus no
    }

    # create the path to the to be downloaded sources if it doesn't exist
    set mp_source_path [file join $portdbpath sources]
    if {![file exists $mp_source_path]} {
        file mkdir $mp_source_path
    }
    ui_debug "MacPorts sources location: $mp_source_path"

    set macports_version_new [selfupdate::get_current_version $mp_source_path]

    # Print current MacPorts versions
    ui_msg "MacPorts base version $macports::autoconf::macports_version installed,"
    ui_msg "MacPorts base version $macports_version_new available."

    # check if we we need to rebuild base
    set comp [vercmp $macports_version_new $macports::autoconf::macports_version]
    if {[info exists options(ports_force)] && $options(ports_force)} {
        set use_the_force_luke yes
        ui_debug "Forcing a rebuild and reinstallation of MacPorts"
    } else {
        set use_the_force_luke no
        ui_debug "Rebuilding and reinstalling MacPorts if needed"
    }

    if {$use_the_force_luke || $comp > 0} {
        if {[info exists options(ports_dryrun)] && $options(ports_dryrun)} {
            ui_msg "$macports::ui_prefix MacPorts base is outdated, selfupdate would install $macports_version_new (dry run)"
        } else {
            ui_msg "$macports::ui_prefix MacPorts base is outdated, installing new version $macports_version_new"

            set source_code [selfupdate::download_source $mp_source_path $macports_version_new]
            selfupdate::install $source_code
            if {[info exists updatestatus]} {
                set updatestatus yes
            }
            # Abort here, port.tcl will re-execute selfupdate with the updated
            # base to trigger sync and portindex with the new version
            return 0
        }
    } elseif {$comp < 0} {
        ui_msg "$macports::ui_prefix MacPorts base is probably master or a release candidate"
    } else {
        ui_msg "$macports::ui_prefix MacPorts base is already the latest version"
    }

    # syncing ports tree.
    if {![info exists options(ports_selfupdate_no-sync)] || !$options(ports_selfupdate_no-sync)} {
        try -pass_signal {
            mportsync $optionslist
        }  catch {{*} eCode eMessage} {
            error "Couldn't sync the ports tree: $eMessage"
        }
    }

    # set the MacPorts sources to the right owner
    set sources_owner [file attributes [file join $portdbpath sources/] -owner]
    ui_debug "Setting MacPorts sources ownership to $sources_owner"
    try -pass_signal {
        exec [macports::findBinary chown $macports::autoconf::chown_path] -R $sources_owner [file join $portdbpath sources/]
    }  catch {{*} eCode eMessage} {
        error "Couldn't change permissions of the MacPorts sources at $mp_source_path to ${sources_owner}: $eMessage"
    }

    if {![info exists options(ports_selfupdate_no-sync)] || !$options(ports_selfupdate_no-sync)} {
        ui_msg "\nThe ports tree has been updated. To upgrade your installed ports, you should run"
        ui_msg "  port upgrade outdated"
    }

    return 0
}
