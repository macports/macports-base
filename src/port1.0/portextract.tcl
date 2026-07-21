# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
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

package provide portextract 1.0

set org.macports.extract [target_new org.macports.extract portextract::extract_main]
target_provides ${org.macports.extract} extract
target_requires ${org.macports.extract} main fetch checksum
target_prerun ${org.macports.extract} portextract::extract_start
target_runpkg ${org.macports.extract} portextract_run

namespace eval portextract {
    variable all_use_options [list use_7z use_bzip2 use_dmg use_lzip use_lzma use_tar use_xz use_zip]
    variable default_suffix_map [dict create use_bzip2 .tar.bz2 use_lzma .tar.lzma use_tar .tar \
        use_xz .tar.xz use_zip .zip use_7z .7z use_lzip .tar.lz use_dmg .dmg]
    variable dmg_mount {/tmp/mports.XXXXXXXX}
}

# define options
options extract.only extract.mkdir extract.rename extract.suffix extract.asroot \
        {*}${portextract::all_use_options} extract.methods extract.add_deps
commands extract

# Set up defaults
default extract.asroot no
# This cleans the distfiles list of all site tags
default extract.only {[portextract::disttagclean $distfiles]}

default extract.dir {${workpath}}
default extract.cmd {[portextract::get_extract_cmd]}
default extract.pre_args {[portextract::get_extract_pre_args]}
default extract.post_args {[portextract::get_extract_post_args]}
default extract.suffix .tar.gz
default extract.methods {}
default extract.mkdir no
default extract.rename no
default extract.add_deps yes

foreach _extract_use_option ${portextract::all_use_options} {
    option_proc ${_extract_use_option} portextract::set_extract_type
}
unset _extract_use_option

# Map a given file name to a canonical extract method name
proc portextract::method_for_suffix {filename} {
    switch -glob -nocase -- $filename {
        *.tgz -
        *.tar.gz {
            return gzip
        }
        *.tbz -
        *.tbz2 -
        *.tar.bz2 {
            return bzip2
        }
        *.txz -
        *.tar.xz {
            return xz
        }
        *.zip {
            return zip
        }
        *.tzst -
        *.tar.zst {
            return zstd
        }
        *.tlz -
        *.tar.lzma {
            return lzma
        }
        *.tar {
            return tar
        }
        *.7z {
            return 7z
        }
        *.tar.lz {
            return lzip
        }
        *.dmg {
            return dmg
        }
    }
    return {}
}

proc portextract::get_extract_cmd {{method {}}} {
    if {$method eq {}} {
        global extract.suffix
        set method [method_for_suffix ${extract.suffix}]
    }
    switch $method {
        gzip {
            return [findBinary gzip ${::portutil::autoconf::gzip_path}]
        }
        bzip2 {
            if {![catch {findBinary lbzip2} result]} {
                return $result
            } else {
                return [findBinary bzip2 ${::portutil::autoconf::bzip2_path}]
            }
        }
        xz {
            return [findBinary xz ${::portutil::autoconf::xz_path}]
        }
        zip {
            return [findBinary unzip ${::portutil::autoconf::unzip_path}]
        }
        zstd {
            return [binaryInPath zstd]
        }
        lzma {
            return [findBinary lzma ${::portutil::autoconf::lzma_path}]
        }
        tar {
            return [findBinary tar ${::portutil::autoconf::tar_command}]
        }
        7z {
            return [binaryInPath 7za]
        }
        lzip {
            return [binaryInPath lzip]
        }
        dmg {
            return [findBinary hdiutil ${::portutil::autoconf::hdiutil_path}]
        }
    }
    return {}
}

proc portextract::get_extract_pre_args {{method {}}} {
    if {$method eq {}} {
        global extract.suffix
        set method [method_for_suffix ${extract.suffix}]
    }
    switch $method {
        bzip2 -
        gzip -
        lzip -
        lzma -
        xz -
        zstd {
            return {-dc}
        }
        zip {
            return {-q}
        }
        tar {
            return {-xf}
        }
        7z {
            return {x}
        }
        dmg {
            return {attach}
        }
    }
    return {}
}

proc portextract::get_extract_post_args {{method {}}} {
    if {$method eq {}} {
        global extract.suffix
        set method [method_for_suffix ${extract.suffix}]
    }
    switch $method {
        bzip2 -
        gzip -
        lzip -
        lzma -
        xz -
        zstd {
            return "| ${::portutil::autoconf::tar_command} -xf -"
        }
        zip {
            global extract.dir
            return "-d [shellescape ${extract.dir}]"
        }
        7z -
        tar {
            return {}
        }
        dmg {
            global distname extract.dir
            variable dmg_mount
            return "-private -readonly -nobrowse -mountpoint [shellescape ${dmg_mount}] && cd [shellescape ${dmg_mount}] && [findBinary find ${::portutil::autoconf::find_path}] . -depth -perm -+r -print0 | [findBinary cpio ${::portutil::autoconf::cpio_path}] -0 -p -d -m -u [shellescape ${extract.dir}/${distname}]; status=\$?; cd / && [get_extract_cmd $method] detach [shellescape ${dmg_mount}] && [findBinary rmdir ${::portutil::autoconf::rmdir_path}] [shellescape ${dmg_mount}]; exit \$status"
        }
    }
    return {}
}

proc portextract::set_extract_type {option action args} {
    # Make the use_* options act like radio buttons - if one is turned
    # on, all the others turn off.
    if {${action} in {set delete}} {
        variable all_use_options
        global {*}$all_use_options extract.suffix
        if {${action} eq "set" && [string is true -strict $args]} {
            foreach opt $all_use_options {
                if {$opt ne $option} {
                    unset -nocomplain $opt
                }
            }
            variable default_suffix_map
            default extract.suffix [dict get $default_suffix_map $option]
        } else {
            # restore default extract.suffix if all use_* options are unset
            foreach opt $all_use_options {
                if {[tbool $opt]} {
                    set any_on 1
                    break
                }
            }
            if {![info exists any_on]} {
                default extract.suffix .tar.gz
            }
        }
    }
}

proc portextract::find_methods {} {
    variable methods_used
    if {[info exists methods_used]} {
        return
    }
    global extract.only extract.methods
    set methods_used [dict create]
    # record a deduplicated set of extract methods used
    foreach distfile ${extract.only} {
        if {[dict exists ${extract.methods} $distfile]} {
            dict set methods_used [dict get ${extract.methods} $distfile] 1
        } else {
            dict set methods_used [method_for_suffix $distfile] 1
        }
    }
}
port::register_callback portextract::find_methods

proc portextract::add_extract_deps {} {
    global depends_extract extract.add_deps
    if {!${extract.add_deps}} {
        return
    }
    variable methods_used
    if {![info exists methods_used]} {
        find_methods
    }
    # add deps for each method
    foreach method [dict keys $methods_used] {
        set depspec {}
        switch $method {
            bzip2 {
                if {![catch {findBinary lbzip2}]} {
                    set depspec bin:lbzip2:lbzip2
                }
            }
            xz {
                set depspec bin:xz:xz
            }
            zip {
                set depspec bin:unzip:unzip
            }
            zstd {
                set depspec bin:zstd:zstd
            }
            lzip {
                set depspec bin:lzip:lzip
            }
            lzma {
                set depspec bin:lzma:xz
            }
            7z {
                set depspec bin:7za:p7zip
            }
        }
        if {$depspec ne {} && (![info exists depends_extract] || $depspec ni $depends_extract)} {
            depends_extract-append $depspec
        }
    }
}
port::register_callback portextract::add_extract_deps

# Helper function that strips all tag names from a list
# Used to clean ${distfiles} for setting the ${extract.only} default
proc portextract::disttagclean {list} {
    return [lmap fname $list {getdistname $fname}]
}
