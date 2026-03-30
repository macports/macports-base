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
target_postrun ${org.macports.extract} portextract::file_extract_execute

namespace eval portextract {
    variable all_use_options [list use_7z use_bzip2 use_dmg use_lzip use_lzma use_tar use_xz use_zip]
    variable dmg_mount {/tmp/mports.XXXXXXXX}

    # Ordered mapping of file suffixes to extraction type names.
    variable suffix_to_type {
        .tar.gz     gzip
        .tgz        gzip
        .tar.bz2    bzip2
        .tbz        bzip2
        .tbz2       bzip2
        .tar.xz     xz
        .txz        xz
        .tar.lzma   lzma
        .tlz        lzma
        .tar.lz     lzip
        .tar.zst    zstd
        .tzst       zstd
        .tar.Z      compress
        .tZ         compress
        .taZ        compress
        .tar        tar
        .zip        zip
        .7z         7z
        .dmg        dmg
    }

    # Mapping of extraction type names to port dependency spec.
    variable type_to_dep {
        bzip2       bin:bzip2:bzip2
        xz          bin:xz:xz
        lzma        bin:lzma:xz
        lzip        bin:lzip:lzip
        zstd        bin:zstd:zstd
        zip         bin:unzip:unzip
        7z          bin:7za:p7zip
    }

    # Queue of file_extract arg-lists to be processed during extract phase.
    variable file_extract_queue {}
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

# portextract::find_archive --
#     Locate an archive file by name.  Absolute paths are checked
#     directly; relative names are searched in filespath then distpath.
#
# Arguments:
#     name - Filename or absolute path to look for.
#
# Returns:
#     The resolved absolute path if found, or an empty string.
proc portextract::find_archive {name} {
    global filespath distpath
    if {[file pathtype $name] eq "absolute"} {
        if {[file exists $name]} {
            return $name
        }
    } elseif {[info exists filespath] && [file exists [file join $filespath $name]]} {
        return [file join $filespath $name]
    } elseif {[info exists distpath] && [file exists [file join $distpath $name]]} {
        return [file join $distpath $name]
    }
    return ""
}

# portextract::detect_type --
#     Determine the extraction type for a file from its suffix.
#
# Arguments:
#     filename - Filename or path to examine.
#
# Returns:
#     An extraction type name (e.g. "gzip", "bzip2", "xz", "zstd",
#     "tar", "zip", "7z", "dmg"). Matching is case-insensitive.
#
# Errors:
#     Throws if the suffix is not recognised.
proc portextract::detect_type {filename} {
    variable suffix_to_type
    foreach {suffix type} $suffix_to_type {
        if {[string match -nocase *$suffix $filename]} {
            return $type
        }
    }
    return -code error "file_extract: unsupported file type: $filename"
}

# portextract::add_dep_for_type --
#     Append a depends_extract entry for the given extraction type,
#     if one is needed.  Types not listed in type_to_dep are silently
#     skipped.
#
# Arguments:
#     type - Extraction type name as returned by detect_type.
proc portextract::add_dep_for_type {type} {
    variable type_to_dep
    if {[dict exists $type_to_dep $type]} {
        depends_extract-append [dict get $type_to_dep $type]
    }
}

# portextract::extract_dmg --
#     Extract a DMG file by mounting it, copying its contents into
#     a ${distname} subdirectory of the target directory, and
#     detaching.  Handles privilege escalation and chownAsRoot.
#
# Arguments:
#     filepath - Absolute path to the DMG file.
#     dirname  - Absolute path to the target directory.
#
# Errors:
#     Throws if a required binary cannot be found or extraction fails.
#     Privileges are always dropped before propagating errors.
proc portextract::extract_dmg {filepath dirname} {
    global distname

    set hdiutil [findBinary hdiutil ${portutil::autoconf::hdiutil_path}]
    set find_cmd [findBinary find ${portutil::autoconf::find_path}]
    set cpio_cmd [findBinary cpio ${portutil::autoconf::cpio_path}]
    set rmdir_cmd [findBinary rmdir ${portutil::autoconf::rmdir_path}]

    set dmg_mount [mkdtemp "/tmp/mports.XXXXXXXX"]

    set cmdstring "cd [shellescape $dirname] && $hdiutil attach [shellescape $filepath] -private -readonly -nobrowse -mountpoint [shellescape $dmg_mount] && cd [shellescape $dmg_mount] && $find_cmd . -depth -perm -+r -print0 | $cpio_cmd -0 -p -d -m -u [shellescape $dirname/$distname]; status=\$?; cd / && $hdiutil detach [shellescape $dmg_mount] && $rmdir_cmd [shellescape $dmg_mount]; exit \$status"

    elevateToRoot {extract dmg}
    set code [catch {system $cmdstring} result]
    dropPrivileges

    if {$code} {
        return -code error $result
    }

    chownAsRoot $dirname
}

# portextract::build_extract_command --
#     Build a shell command string that extracts an archive of the
#     given type into the given directory.
#
# Arguments:
#     type     - Extraction type name as returned by detect_type (e.g.
#                "gzip", "bzip2", "xz", "lzma", "lzip", "zstd",
#                "compress", "tar", "zip", "7z").  DMG is handled
#                separately by extract_dmg.
#     filepath - Absolute path to the archive file.
#     dirname  - Absolute path to the target directory.
#
# Returns:
#     A shell command string suitable for [system].
#
# Errors:
#     Throws if a required binary cannot be found or the type is
#     unknown.
proc portextract::build_extract_command {type filepath dirname} {
    set tar [findBinary tar ${portutil::autoconf::tar_command}]
    set escaped_file [shellescape $filepath]
    set escaped_dir [shellescape $dirname]

    switch -- $type {
        gzip - compress {
            set cmd [findBinary gzip ${portutil::autoconf::gzip_path}]
        }
        bzip2 {
            set cmd [findBinary bzip2 ${portutil::autoconf::bzip2_path}]
        }
        xz {
            set cmd [findBinary xz ${portutil::autoconf::xz_path}]
        }
        lzma {
            set cmd [findBinary lzma ${portutil::autoconf::lzma_path}]
        }
        lzip {
            set cmd [binaryInPath lzip]
        }
        zstd {
            set cmd [binaryInPath zstd]
        }
        tar {
            return "cd $escaped_dir && $tar -xf $escaped_file"
        }
        zip {
            set cmd [findBinary unzip ${portutil::autoconf::unzip_path}]
            return "$cmd -q $escaped_file -d $escaped_dir"
        }
        7z {
            set cmd [binaryInPath 7za]
            return "cd $escaped_dir && $cmd x $escaped_file"
        }
        default {
            return -code error "file_extract: unknown type: $type"
        }
    }

    return "cd $escaped_dir && $cmd -dc $escaped_file | $tar -xf -"
}

# file_extract --
#     Register one or more archive files for extraction during the
#     extract phase.  The archive format is automatically detected
#     from the file suffix.
#
#     This is the user-facing command intended for use in Portfiles.
#     It validates options, registers any required extraction
#     dependencies, and queues the request for later execution by
#     file_extract_execute (which runs as a target_postrun on the
#     extract target).
#
# Usage:
#     file_extract ?-dirname dir? ?-type type? ?--? filename ...
#
# Options:
#     -dirname dir  - Extract into dir.  Defaults to ${workpath}.
#     -type type    - Force an extraction type instead of detecting it
#                     from the suffix.  Applies to all files in the
#                     same invocation.
#     --            - End of options.
#
# Filename resolution:
#     Absolute paths are used as-is.  Relative names are looked up
#     first in ${filespath}, then in ${distpath}. Distfile tags are
#     ignored for lookup and suffix detection.
#
# Notes:
#     The destination directory is created if it does not already exist.
#     After extraction, the target directory is chowned to
#     ${macportsuser}.  DMG extraction additionally elevates to
#     root for hdiutil and extracts into a ${distname} subdirectory.
#
# Errors:
#     Throws at parse time if option syntax is invalid, no filenames
#     are given, or a file suffix is unrecognised (and -type was not
#     given).  Throws at extract time if a file cannot be found, the
#     destination directory cannot be created, or extraction fails.
#
# Examples:
#     file_extract foo.tar.xz
#     file_extract -dirname ${worksrcpath}/extra extra-data.tar.gz
#     file_extract -type gzip renamed-archive.bin
#     file_extract a.tar.gz b.zip c.tar.xz
proc file_extract {args} {
    portextract::file_extract_setup {*}$args
}

# portextract::file_extract_setup --
#     Parse and validate file_extract options, register extraction
#     dependencies, and queue the request for the extract phase.
#     Called at Portfile parse time via the file_extract command.
#
# Arguments:
#     args - The arguments as passed to file_extract.
proc portextract::file_extract_setup {args} {
    global workpath

    set dirname ""
    set type ""

    while {[string match "-*" [lindex $args 0]]} {
        set arg [string range [lindex $args 0] 1 end]
        set args [lrange $args 1 end]
        switch -- $arg {
            dirname {
                set dirname [lindex $args 0]
                set args [lrange $args 1 end]
                if {$dirname eq ""} {
                    return -code error "file_extract: option requires an argument -- dirname"
                }
            }
            type {
                set type [lindex $args 0]
                set args [lrange $args 1 end]
                if {$type eq ""} {
                    return -code error "file_extract: option requires an argument -- type"
                }
            }
            - break
            default {
                return -code error "file_extract: illegal option -- $arg"
            }
        }
    }

    if {[llength $args] == 0} {
        return -code error "file_extract: no filename specified"
    }

    if {$dirname eq ""} {
        set dirname $workpath
    }

    # Register dependencies and validate type for each file now,
    # so errors surface at parse time rather than extract time.
    foreach filename $args {
        set lookup_name [getdistname $filename]
        if {$type ne ""} {
            set filetype $type
        } else {
            set filetype [portextract::detect_type $lookup_name]
        }
        portextract::add_dep_for_type $filetype
    }

    # Queue the fully parsed request for extract-phase execution.
    variable file_extract_queue
    lappend file_extract_queue [list $dirname $type $args]
}

# portextract::file_extract_execute --
#     Process the file_extract queue.  Registered as a target_postrun
#     on the extract target so it runs after extract_main (or any
#     user-provided extract override) completes.
#
# Arguments:
#     args - Ignored (required by target_postrun signature).
proc portextract::file_extract_execute {args} {
    global UI_PREFIX
    variable file_extract_queue

    while {[llength $file_extract_queue] > 0} {
        set entry [lindex $file_extract_queue 0]
        set file_extract_queue [lrange $file_extract_queue 1 end]

        lassign $entry dirname type filenames

        foreach filename $filenames {
            set lookup_name [getdistname $filename]

            set filepath [portextract::find_archive $lookup_name]
            if {$filepath eq ""} {
                return -code error "file_extract: could not find $filename"
            }

            if {$type ne ""} {
                set filetype $type
            } else {
                set filetype [portextract::detect_type $lookup_name]
            }

            if {[file exists $dirname]} {
                set dir_created no
            } else {
                set dir_created yes
            }
            file mkdir $dirname

            ui_info "$UI_PREFIX [format [msgcat::mc "Extracting %s (%s)"] $lookup_name $filetype]"
            if {$dir_created} {
                ui_debug "file_extract: created directory $dirname"
            }
            ui_debug "file_extract: extracting $filepath (type: $filetype) to $dirname"

            if {$filetype eq "dmg"} {
                portextract::extract_dmg $filepath $dirname
            } else {
                set cmdstring [portextract::build_extract_command $filetype $filepath $dirname]
                system $cmdstring
                chownAsRoot $dirname
            }
        }
    }
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
