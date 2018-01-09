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

namespace eval selfupdate {
    namespace export main
}

proc selfupdate::main {{optionslist {}} {updatestatusvar {}}} {
    global macports::prefix macports::portdbpath macports::rsync_server macports::rsync_dir \
           macports::rsync_options macports::autoconf::macports_version \
           macports::autoconf::rsync_path tcl_platform macports::autoconf::openssl_path \
           macports::autoconf::tar_path
    array set options $optionslist

    # variable that indicates whether we actually updated base
    if {$updatestatusvar ne ""} {
        upvar $updatestatusvar updatestatus
        set updatestatus no
    }

    # are we syncing a tarball? (implies detached signature)
    set is_tarball 0
    if {[string range $rsync_dir end-3 end] eq ".tar"} {
        set is_tarball 1
        set mp_source_path [file join $portdbpath sources $rsync_server [file dirname $rsync_dir]]
    } else {
        if {[string index $rsync_dir end] ne "/"} {
            append rsync_dir /
        }
        set mp_source_path [file join $portdbpath sources $rsync_server $rsync_dir]
    }
    # create the path to the to be downloaded sources if it doesn't exist
    if {![file exists $mp_source_path]} {
        file mkdir $mp_source_path
    }
    ui_debug "MacPorts sources location: $mp_source_path"

    # sync the MacPorts sources
    ui_msg "$macports::ui_prefix Updating MacPorts base sources using rsync"
    try -pass_signal {
        system "$rsync_path $rsync_options rsync://${rsync_server}/$rsync_dir $mp_source_path"
    } catch {{*} eCode eMessage} {
        return -code error "Error synchronizing MacPorts sources: $eMessage"
    }

    if {$is_tarball} {
        # verify signature for tarball
        global macports::archivefetch_pubkeys
        try -pass_signal {
            system "$rsync_path $rsync_options rsync://${rsync_server}/${rsync_dir}.rmd160 $mp_source_path"
        } catch {{*} eCode eMessage} {
            return -code error "Error synchronizing MacPorts source signature: $eMessage"
        }
        set openssl [macports::findBinary openssl $macports::autoconf::openssl_path]
        set tarball ${mp_source_path}/[file tail $rsync_dir]
        set signature ${tarball}.rmd160
        set verified 0
        foreach pubkey $macports::archivefetch_pubkeys {
            try -pass_signal {
                exec $openssl dgst -ripemd160 -verify $pubkey -signature $signature $tarball
                set verified 1
                ui_debug "successful verification with key $pubkey"
                break
            }  catch {{*} eCode eMessage} {
                ui_debug "failed verification with key $pubkey"
                ui_debug "openssl output: $eMessage"
            }
        }
        if {!$verified} {
            return -code error "Failed to verify signature for MacPorts source!"
        }

        # extract tarball and move into place
        set tar [macports::findBinary tar $macports::autoconf::tar_path]
        file mkdir ${mp_source_path}/tmp
        set tar_cmd "$tar -C ${mp_source_path}/tmp -xf $tarball"
        try -pass_signal {
            system $tar_cmd
        } catch {*} {
            return -code error "Failed to extract MacPorts sources from tarball!"
        }
        file delete -force ${mp_source_path}/base
        file rename ${mp_source_path}/tmp/base ${mp_source_path}/base
        file delete -force ${mp_source_path}/tmp
        # set the final extracted source path
        set mp_source_path ${mp_source_path}/base
    }

    # echo current MacPorts version
    ui_msg "MacPorts base version $macports::autoconf::macports_version installed,"

    if {[info exists options(ports_force)] && $options(ports_force)} {
        set use_the_force_luke yes
        ui_debug "Forcing a rebuild and reinstallation of MacPorts"
    } else {
        set use_the_force_luke no
        ui_debug "Rebuilding and reinstalling MacPorts if needed"
    }

    # Choose what version file to use: old, floating point format or new, real version number format
    set version_file [file join $mp_source_path config macports_version]
    if {[file exists $version_file]} {
        set fd [open $version_file r]
        gets $fd macports_version_new
        close $fd
        # echo downloaded MacPorts version
        ui_msg "MacPorts base version $macports_version_new downloaded."
    } else {
        ui_warn "No version file found, please rerun selfupdate."
        set macports_version_new 0
    }

    # check if we we need to rebuild base
    set comp [vercmp $macports_version_new $macports::autoconf::macports_version]

    # syncing ports tree.
    if {![info exists options(ports_selfupdate_nosync)] || !$options(ports_selfupdate_nosync)} {
        if {$comp > 0} {
            # updated portfiles potentially need new base to parse - tell sync to try to
            # use prefabricated PortIndex files and signal if it couldn't
            lappend optionslist no_reindex 1 needed_portindex_var needed_portindex
        }
        try {
            mportsync $optionslist
        }  catch {{*} eCode eMessage} {
            return -code error "Couldn't sync the ports tree: $eMessage"
        }
    }

    # Check whether we need to re-install base because of a migration
    set migrating [expr {[info exists options(ports_selfupdate_migrate)] && $options(ports_selfupdate_migrate)}]

    if {$use_the_force_luke || $comp > 0 || ($comp == 0 && $migrating)} {
        if {[info exists options(ports_dryrun)] && $options(ports_dryrun)} {
            ui_msg "$macports::ui_prefix MacPorts base is outdated, selfupdate would install $macports_version_new (dry run)"
        } else {
            ui_msg "$macports::ui_prefix MacPorts base is outdated, installing new version $macports_version_new"

            # get installation user/group and permissions
            set owner [file attributes $prefix -owner]
            set group [file attributes $prefix -group]
            set perms [string range [file attributes $prefix -permissions] end-3 end]
            if {$tcl_platform(user) ne "root" && $tcl_platform(user) ne $owner} {
                return -code error "User $tcl_platform(user) does not own $prefix - try using sudo"
            }
            ui_debug "Permissions OK"

            set configure_args "--prefix=[macports::shellescape $prefix] --with-install-user=[macports::shellescape $owner] --with-install-group=[macports::shellescape $group] --with-directory-mode=[macports::shellescape $perms]"
            # too many users have an incompatible readline in /usr/local, see ticket #10651
            if {$tcl_platform(os) ne "Darwin" || $prefix eq "/usr/local"
                || ([glob -nocomplain /usr/local/lib/lib{readline,history}*] eq "" && [glob -nocomplain /usr/local/include/readline/*.h] eq "")} {
                append configure_args " --enable-readline"
            } else {
                ui_warn "Disabling readline support due to readline in /usr/local"
            }

            if {$prefix eq "/usr/local" || $prefix eq "/usr"} {
                append configure_args " --with-unsupported-prefix"
            }

            # Choose a sane compiler
            set cc_arg {}
            if {$::macports::os_platform eq "darwin"} {
                set cc_arg "CC=/usr/bin/cc OBJC=/usr/bin/cc "
            }

            # do the actual configure, build and installation of new base
            ui_msg "Installing new MacPorts release in $prefix as ${owner}:${group}; permissions ${perms}\n"
            try {
                system -W $mp_source_path "${cc_arg}./configure $configure_args && make SELFUPDATING=1 && make install SELFUPDATING=1"
            } catch {{*} eCode eMessage} {
                return -code error "Error installing new MacPorts base: $eMessage"
            }
            if {[info exists updatestatus]} {
                set updatestatus yes
            }
        }
    } elseif {$comp < 0} {
        ui_msg "$macports::ui_prefix MacPorts base is probably master or a release candidate"
    } else {
        ui_msg "$macports::ui_prefix MacPorts base is already the latest version"
    }

    # set the MacPorts sources to the right owner
    set sources_owner [file attributes [file join $portdbpath sources/] -owner]
    ui_debug "Setting MacPorts sources ownership to $sources_owner"
    try {
        exec [macports::findBinary chown $macports::autoconf::chown_path] -R $sources_owner [file join $portdbpath sources/]
    }  catch {{*} eCode eMessage} {
        return -code error "Couldn't change permissions of the MacPorts sources at $mp_source_path to ${sources_owner}: $eMessage"
    }

    if {![info exists options(ports_selfupdate_nosync)] || !$options(ports_selfupdate_nosync)} {
        if {[info exists needed_portindex]} {
            ui_msg "Not all sources could be fully synced using the old version of MacPorts."
            ui_msg "Please run selfupdate again now that MacPorts base has been updated."
        } else {
            ui_msg "\nThe ports tree has been updated. To upgrade your installed ports, you should run"
            ui_msg "  port upgrade outdated"
        }
    }

    return 0
}
