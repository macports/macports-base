# et:ts=4
# portextract.tcl
#
# Copyright (c) 2005, 2007-2011, 2013-2014, 2016, 2018 The MacPorts Project
# Copyright (c) 2002 - 2003 Apple Inc.
# Copyright (c) 2007 Markus W. Weissmann <mww@macports.org>
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

package provide portextract 1.0
package require portutil 1.0

set org.macports.extract [target_new org.macports.extract portextract::extract_main]
target_provides ${org.macports.extract} extract
target_requires ${org.macports.extract} main fetch checksum
target_prerun ${org.macports.extract} portextract::extract_start

namespace eval portextract {
}

# define options
options extract.only extract.mkdir extract.asroot
commands extract

# Set up defaults
default extract.asroot no
# XXX call out to code in portutil.tcl XXX
# This cleans the distfiles list of all site tags
default extract.only {[portextract::disttagclean $distfiles]}

default extract.dir {${workpath}}
default extract.cmd {[findBinary gzip ${portutil::autoconf::gzip_path}]}
default extract.pre_args -dc
default extract.post_args {| ${portutil::autoconf::tar_command} -xf -}
default extract.mkdir no

set_ui_prefix

# XXX
# Helper function for portextract.tcl that strips all tag names from a list
# Used to clean ${distfiles} for setting the ${extract.only} default
proc portextract::disttagclean {list} {
    if {$list eq ""} {
        return $list
    }
    foreach name $list {
        lappend val [getdistname $name]
    }
    return $val
}

proc portextract::extract_start {args} {
    global UI_PREFIX extract.dir extract.mkdir use_tar use_bzip2 use_lzma use_xz use_zip use_7z use_lzip use_dmg

    ui_notice "$UI_PREFIX [format [msgcat::mc "Extracting %s"] [option subport]]"

    # create any users and groups needed by the port
    handle_add_users

    # should the distfiles be extracted to worksrcpath instead?
    if {[tbool extract.mkdir]} {
        global worksrcpath
        ui_debug "Extracting to subdirectory worksrcdir"
        file mkdir ${worksrcpath}
        set extract.dir ${worksrcpath}
    }
    if {[tbool use_tar]} {
        option extract.cmd [findBinary tar ${portutil::autoconf::tar_command}]
        option extract.pre_args -xf
        option extract.post_args ""
    } elseif {[tbool use_bzip2]} {
        if {![catch {findBinary lbzip2} result]} {
            option extract.cmd $result
        } else {
            option extract.cmd [findBinary bzip2 ${portutil::autoconf::bzip2_path}]
        }
    } elseif {[tbool use_lzma]} {
        option extract.cmd [findBinary lzma ${portutil::autoconf::lzma_path}]
    } elseif {[tbool use_xz]} {
        option extract.cmd [findBinary xz ${portutil::autoconf::xz_path}]
    } elseif {[tbool use_zip]} {
        option extract.cmd [findBinary unzip ${portutil::autoconf::unzip_path}]
        option extract.pre_args -q
        option extract.post_args "-d ${extract.dir}"
    } elseif {[tbool use_7z]} {
        option extract.cmd [binaryInPath "7za"]
        option extract.pre_args x
        option extract.post_args ""
    } elseif {[tbool use_lzip]} {
        option extract.cmd [binaryInPath "lzip"]
        option extract.pre_args "-dc"
        #option extract.post_args ""
    } elseif {[tbool use_dmg]} {
        global distname extract.cmd
        set dmg_mount [mkdtemp "/tmp/mports.XXXXXXXX"]
        option extract.cmd [findBinary hdiutil ${portutil::autoconf::hdiutil_path}]
        option extract.pre_args attach
        option extract.post_args "-private -readonly -nobrowse -mountpoint \\\"${dmg_mount}\\\" && cd \\\"${dmg_mount}\\\" && [findBinary find ${portutil::autoconf::find_path}] . -depth -perm -+r -print0 | [findBinary cpio ${portutil::autoconf::cpio_path}] -0 -p -d -m -u \\\"${extract.dir}/${distname}\\\"; status=\$?; cd / && ${extract.cmd} detach \\\"${dmg_mount}\\\" && [findBinary rmdir ${portutil::autoconf::rmdir_path}] \\\"${dmg_mount}\\\"; exit \$status"
    }
}

proc portextract::extract_main {args} {
    global UI_PREFIX filespath workpath worksrcdir worksrcpath extract.dir use_dmg

    if {![exists distfiles] && ![exists extract.only]} {
        # nothing to do
        return 0
    }

    foreach distfile [option extract.only] {
        ui_info "$UI_PREFIX [format [msgcat::mc "Extracting %s"] $distfile]"
        if {[file exists $filespath/$distfile]} {
            option extract.args "'$filespath/$distfile'"
        } else {
            option extract.args "'[option distpath]/$distfile'"
        }

        # If the MacPorts user does not have the privileges to mount a
        # DMG then hdiutil will fail with this error:
        #   hdiutil: attach failed - Device not configured
        # So elevate back to root.
        if {[tbool use_dmg]} {
            elevateToRoot {extract dmg}
        }
        set code [catch {command_exec extract} result]
        if {[tbool use_dmg]} {
            dropPrivileges
        }
        if {$code} {
            return -code error "$result"
        }

        chownAsRoot ${extract.dir}
    }

    # If expected path of extract doesn't exist && worksrcdir is
    # not explicitly set to subdirectory, symlink to actual path.
    if {![file isdirectory $worksrcpath] && [regexp {^[^/]+$} $worksrcdir]} {
        set workdirs [glob -nocomplain -types d [file join $workpath *]]
        if {[llength $workdirs] == 1} {
            set dir [file tail [lindex $workdirs 0]]
            ui_debug [format [msgcat::mc "Symlink: %s -> %s"] $worksrcpath $dir]
            symlink $dir $worksrcpath
        }
    }
    return 0
}
