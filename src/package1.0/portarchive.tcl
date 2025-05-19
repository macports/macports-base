# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# portarchive.tcl
#
# Copyright (c) 2004 Robert Shaw <rshaw@opendarwin.org>
# Copyright (c) 2002 - 2003 Apple Computer, Inc.
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
# 3. Neither the name of Apple Computer, Inc. nor the names of its contributors
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

package provide portarchive 1.0
package require portutil 1.0

set org.macports.archive [target_new org.macports.archive portarchive::archive_main]
target_provides ${org.macports.archive} archive
target_runtype ${org.macports.archive} always
target_state ${org.macports.archive} no
target_requires ${org.macports.archive} main archivefetch fetch checksum extract patch configure build destroot install

namespace eval portarchive {
}

set_ui_prefix

proc portarchive::archive_command_setup {location archive.type} {
    global archive.env archive.cmd archive.pre_args archive.args \
           archive.post_args portarchive_hfscompression
    set archive.env {}
    set archive.cmd {}
    set archive.pre_args {}
    set archive.args {}
    set archive.post_args {}

    switch -regex -- ${archive.type} {
        aar {
            set aa "aa"
            if {[catch {set aa [findBinary $aa ${portutil::autoconf::aa_path}]} errmsg] == 0} {
                ui_debug "Using $aa"
                set archive.cmd "$aa"
                set archive.pre_args "archive -v"
                set archive.args "-o [shellescape ${location}] -d ."
            } else {
                ui_debug $errmsg
                return -code error "No '$aa' was found on this system!"
            }
        }
        cp(io|gz) {
            set pax "pax"
            if {[catch {set pax [findBinary $pax ${portutil::autoconf::pax_path}]} errmsg] == 0} {
                ui_debug "Using $pax"
                set archive.cmd "$pax"
                set archive.pre_args {-w -v -x cpio}
                if {[regexp {z$} ${archive.type}]} {
                    set gzip "gzip"
                    if {[catch {set gzip [findBinary $gzip ${portutil::autoconf::gzip_path}]} errmsg] == 0} {
                        ui_debug "Using $gzip"
                        set archive.args {.}
                        set archive.post_args "| $gzip -c9 > [shellescape ${location}]"
                    } else {
                        ui_debug $errmsg
                        return -code error "No '$gzip' was found on this system!"
                    }
                } else {
                    set archive.args "-f [shellescape ${location}] ."
                }
            } else {
                ui_debug $errmsg
                return -code error "No '$pax' was found on this system!"
            }
        }
        t(ar|bz|lz|xz|gz|mptar) {
            set tar "tar"
            if {[catch {set tar [findBinary $tar ${portutil::autoconf::tar_path}]} errmsg] == 0} {
                ui_debug "Using $tar"
                set archive.cmd "$tar"
                set archive.pre_args {-cvf}
                if {[regexp {z2?$} ${archive.type}]} {
                    if {[regexp {bz2?$} ${archive.type}]} {
                        if {![catch {binaryInPath lbzip2}]} {
                            set gzip "lbzip2"
                        } elseif {![catch {binaryInPath pbzip2}]} {
                            set gzip "pbzip2"
                        } else {
                            set gzip "bzip2"
                        }
                        set level 9
                    } elseif {[regexp {lz$} ${archive.type}]} {
                        set gzip "lzma"
                        set level ""
                    } elseif {[regexp {xz$} ${archive.type}]} {
                        set gzip "xz"
                        set level 6
                    } else {
                        set gzip "gzip"
                        set level 9
                    }
                    if {[info exists portutil::autoconf::${gzip}_path]} {
                        set hint [set portutil::autoconf::${gzip}_path]
                    } else {
                        set hint ""
                    }
                    if {[catch {set gzip [findBinary $gzip $hint]} errmsg] == 0} {
                        ui_debug "Using $gzip"
                        set archive.args {- .}
                        set archive.post_args "| $gzip -c$level > [shellescape ${location}]"
                    } else {
                        ui_debug $errmsg
                        return -code error "No '$gzip' was found on this system!"
                    }
                } else {
                    if {${archive.type} eq "tmptar"} {
                        # Pass through tar for hardlink detection and HFS compression,
                        # but extract without saving the tar file.
                        if {${portarchive_hfscompression} && [getuid] == 0 &&
                            ![catch {binaryInPath bsdtar}] &&
                            ![catch {exec bsdtar -x --hfsCompression < /dev/null >& /dev/null}]
                        } then {
                            set extract_tar bsdtar
                            set extract_tar_args {-xvp --hfsCompression -f}
                        } else {
                            set extract_tar $tar
                            set extract_tar_args {-xvpf}
                        }
                        set archive.args {- .}
                        set archive.post_args "| $extract_tar -C $location $extract_tar_args -"
                        file mkdir $location
                    } else {
                        set archive.args "[shellescape ${location}] ."
                    }
                }
            } else {
                ui_debug $errmsg
                return -code error "No '$tar' was found on this system!"
            }
        }
        xar {
            set xar "xar"
            if {[catch {set xar [findBinary $xar ${portutil::autoconf::xar_path}]} errmsg] == 0} {
                ui_debug "Using $xar"
                set archive.cmd "$xar"
                set archive.pre_args {-cvf}
                set archive.args "[shellescape ${location}] ."
            } else {
                ui_debug $errmsg
                return -code error "No '$xar' was found on this system!"
            }
        }
        zip {
            set zip "zip"
            if {[catch {set zip [findBinary $zip ${portutil::autoconf::zip_path}]} errmsg] == 0} {
                ui_debug "Using $zip"
                set archive.cmd "$zip"
                set archive.pre_args {-ry9}
                set archive.args "[shellescape ${location}] ."
            } else {
                ui_debug $errmsg
                return -code error "No '$zip' was found on this system!"
            }
        }
    }

    return 0
}

proc portarchive::archive_main {args} {

    set location [get_portimage_path]
    if {[file isfile $location]} {
        ui_debug "Archive already exists at $location"
        return 0
    }
    set imagedir [file rootname $location]
    if {![file isdirectory $imagedir]} {
        # Query the registry for the definitive location
        global subport version revision portvariants
        set regref [registry_open $subport $version $revision $portvariants ""]
        set imagedir [registry_prop_retr $regref location]
        if {[file isfile $imagedir]} {
            ui_debug "Archive already exists at $imagedir"
            return 0
        }
        if {![file isdirectory $imagedir]} {
            ui_error "No port image found at: $imagedir"
            return -code error "Port image missing"
        }
    }

    global UI_PREFIX portarchivetype archive.dir

    # Now create the archive
    archiveTypeIsSupported $portarchivetype
    archive_command_setup $location $portarchivetype
    set archive.dir $imagedir

    ui_info "$UI_PREFIX [format [msgcat::mc "Creating %s"] $location]"
    if {[getuid] == 0 && [geteuid] != 0} {
        elevateToRoot "archive"
    }
    command_exec archive
    ui_info "$UI_PREFIX [format [msgcat::mc "Archive %s packaged"] $location]"

    return 0
}
