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
package require port 1.0

set org.macports.extract [target_new org.macports.extract portextract::extract_main]
target_provides ${org.macports.extract} extract
target_requires ${org.macports.extract} main fetch checksum
target_prerun ${org.macports.extract} portextract::extract_start

namespace eval portextract {
    variable all_use_options [list use_7z use_bzip2 use_dmg use_lzip use_lzma use_tar use_xz use_zip]
    variable dmg_mount {/tmp/mports.XXXXXXXX}
}

# define options
options extract.only extract.mkdir extract.rename extract.suffix extract.asroot \
        {*}${portextract::all_use_options}
commands extract

# Set up defaults
default extract.asroot no
# XXX call out to code in portutil.tcl XXX
# This cleans the distfiles list of all site tags
default extract.only {[portextract::disttagclean $distfiles]}

default extract.dir {${workpath}}
default extract.cmd {[portextract::get_extract_cmd]}
default extract.pre_args {[portextract::get_extract_pre_args]}
default extract.post_args {[portextract::get_extract_post_args]}
default extract.suffix {[portextract::get_extract_suffix]}
default extract.mkdir no
default extract.rename no

foreach _extract_use_option ${portextract::all_use_options} {
    option_proc ${_extract_use_option} portextract::set_extract_type
}
unset _extract_use_option

set_ui_prefix

proc portextract::get_extract_cmd {} {
    variable all_use_options
    global {*}$all_use_options
    if {[tbool use_bzip2]} {
        if {![catch {findBinary lbzip2} result]} {
            return $result
        } else {
            return [findBinary bzip2 ${portutil::autoconf::bzip2_path}]
        }
    } elseif {[tbool use_lzma]} {
        return [findBinary lzma ${portutil::autoconf::lzma_path}]
    } elseif {[tbool use_tar]} {
        return [findBinary tar ${portutil::autoconf::tar_command}]
    } elseif {[tbool use_xz]} {
        return [findBinary xz ${portutil::autoconf::xz_path}]
    } elseif {[tbool use_zip]} {
        return [findBinary unzip ${portutil::autoconf::unzip_path}]
    } elseif {[tbool use_7z]} {
        return [binaryInPath {7za}]
    } elseif {[tbool use_lzip]} {
        return [binaryInPath {lzip}]
    } elseif {[tbool use_dmg]} {
        return [findBinary hdiutil ${portutil::autoconf::hdiutil_path}]
    }
    return [findBinary gzip ${portutil::autoconf::gzip_path}]
}

proc portextract::get_extract_pre_args {} {
    variable all_use_options
    global {*}$all_use_options
    if {[tbool use_tar]} {
        return {-xf}
    } elseif {[tbool use_zip]} {
        return {-q}
    } elseif {[tbool use_7z]} {
        return {x}
    } elseif {[tbool use_lzip]} {
        return {-dc}
    } elseif {[tbool use_dmg]} {
        return {attach}
    }
    return {-dc}
}

proc portextract::get_extract_post_args {} {
    global use_tar use_zip use_7z use_dmg
    if {[tbool use_tar]} {
        return {}
    } elseif {[tbool use_zip]} {
        global extract.dir
        return "-d [shellescape ${extract.dir}]"
    } elseif {[tbool use_7z]} {
        return {}
    } elseif {[tbool use_dmg]} {
        global distname extract.cmd extract.dir
        variable dmg_mount
        return "-private -readonly -nobrowse -mountpoint [shellescape ${dmg_mount}] && cd [shellescape ${dmg_mount}] && [findBinary find ${portutil::autoconf::find_path}] . -depth -perm -+r -print0 | [findBinary cpio ${portutil::autoconf::cpio_path}] -0 -p -d -m -u [shellescape ${extract.dir}/${distname}]; status=\$?; cd / && ${extract.cmd} detach [shellescape ${dmg_mount}] && [findBinary rmdir ${portutil::autoconf::rmdir_path}] [shellescape ${dmg_mount}]; exit \$status"
    }
    return "| ${portutil::autoconf::tar_command} -xf -"
}

proc portextract::get_extract_suffix {} {
    variable all_use_options
    global {*}$all_use_options
    if {[tbool use_bzip2]} {
        return {.tar.bz2}
    } elseif {[tbool use_lzma]} {
        return {.tar.lzma}
    } elseif {[tbool use_tar]} {
        return {.tar}
    } elseif {[tbool use_xz]} {
        return {.tar.xz}
    } elseif {[tbool use_zip]} {
        return {.zip}
    } elseif {[tbool use_7z]} {
        return {.7z}
    } elseif {[tbool use_lzip]} {
        return {.tar.lz}
    } elseif {[tbool use_dmg]} {
        return {.dmg}
    }
    return {.tar.gz}
}

proc portextract::set_extract_type {option action args} {
    # Make the use_* options act like radio buttons - if one is turned
    # on, all the others turn off.
    if {${action} eq "set" && [string is true -strict $args]} {
        variable all_use_options
        global {*}$all_use_options
        foreach opt $all_use_options {
            if {$opt ne $option} {
                unset -nocomplain $opt
            }
        }
    }
}

proc portextract::add_extract_deps {} {
    variable all_use_options
    global {*}$all_use_options
    if {[tbool use_bzip2] && ![catch {findBinary lbzip2}]} {
        depends_extract-append bin:lbzip2:lbzip2
    } elseif {[tbool use_lzma]} {
        depends_extract-append bin:lzma:xz
    } elseif {[tbool use_xz]} {
        depends_extract-append bin:xz:xz
    } elseif {[tbool use_zip]} {
        depends_extract-append bin:unzip:unzip
    } elseif {[tbool use_7z]} {
        depends_extract-append bin:7za:p7zip
    } elseif {[tbool use_lzip]} {
        depends_extract-append bin:lzip:lzip
    }
}
port::register_callback portextract::add_extract_deps

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
    global UI_PREFIX extract.dir extract.mkdir use_dmg

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
    if {[tbool use_dmg]} {
        variable dmg_mount [mkdtemp "/tmp/mports.XXXXXXXX"]
    }
}

proc portextract::extract_main {args} {
    global UI_PREFIX filespath extract.dir use_dmg

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

    if {[option extract.rename] && ![file exists [option worksrcpath]]} {
        global workpath distname
        # rename whatever directory exists in $workpath to $distname
        set worksubdirs [glob -nocomplain -types d -directory $workpath *]
        if {[llength $worksubdirs] == 1} {
            set origpath [lindex $worksubdirs 0]
            set newpath [file join $workpath $distname]
            if {$newpath ne $origpath} {
                ui_debug [format [msgcat::mc "extract.rename: Renaming %s -> %s"] [file tail $origpath] $distname]
                move $origpath $newpath
            }
        } elseif {[llength $worksubdirs] == 0} {
            return -code error "extract.rename: no directories exist in $workpath"
        } else {
            return -code error "extract.rename: multiple directories exist in ${workpath}: $worksubdirs"
        }
    }

    return 0
}
