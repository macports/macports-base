# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# Copyright (c) 2002-2003 Apple Inc.
# Copyright (c) 2004 Robert Shaw <rshaw@opendarwin.org>
# Copyright (c) 2006-2007 Markus W. Weissmann <mww@macports.org>
# Copyright (c) 2004-2026 The MacPorts Project
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

package provide portlib 1.0

# Code for use in Portfiles which is more efficient to load once
# and alias in to the child interpreters.

namespace eval portlib {
    namespace eval archive_sites {
        # Normal sites defined in the ports tree
        variable sites [dict create]
        # Sites defined in archive_sites.conf
        variable conf_sites

        # Return URLs for a given site name
        proc get_archive_site_urls {mirrorfile site} {
            variable conf_sites
            if {[dict exists $conf_sites urls $site]} {
                return [dict get $conf_sites urls $site]
            }
            variable sites
            return [dict getwithdefault $sites $mirrorfile urls $site {}]
        }

        proc get_archive_site_archivetype {mirrorfile site} {
            variable conf_sites
            if {[dict exists $conf_sites archivetype $site]} {
                return [dict get $conf_sites archivetype $site]
            }
            variable sites
            return [dict getwithdefault $sites $mirrorfile archivetype $site {}]
        }

        proc get_archive_site_sigtype {mirrorfile site} {
            variable conf_sites
            if {[dict exists $conf_sites sigtype $site]} {
                return [dict get $conf_sites sigtype $site]
            }
            variable sites
            return [dict getwithdefault $sites $mirrorfile sigtype $site {}]
        }

        proc get_archive_site_pubkey {mirrorfile site} {
            variable conf_sites
            if {[dict exists $conf_sites pubkey $site]} {
                return [dict get $conf_sites pubkey $site]
            }
            variable sites
            return [dict getwithdefault $sites $mirrorfile pubkey $site {}]
        }

        # Default value for archive_sites Portfile option
        proc get_default_archive_sites {mirrorfile} {
            variable sites
            if {![dict exists $sites $mirrorfile]} {
                load_global_sites $mirrorfile
            }
            set ret [dict get $sites $mirrorfile archive_sites]
            variable conf_sites
            if {![info exists conf_sites]} {
                load_conf_sites
            }
            lappend ret {*}[dict getwithdefault $conf_sites archive_sites {}]
            return $ret
        }

        # load archive site info from ports tree resources
        proc load_global_sites {mirrorfile} {
            if {[file exists $mirrorfile]} {
                # evaluate archive_sites.tcl in a safe interpreter
                set workername [interp create -safe]
                $workername expose source
                global macports::os_platform macports::os_major
                $workername eval [list set os.platform $os_platform]
                $workername eval [list set os.major $os_major]
                $workername eval [list source $mirrorfile]
                $workername eval {
                    set site_dict [dict create]
                    foreach var {archive_applications_dir archive_frameworks_dir \
                                archive_prefix archive_type \
                                archive_cxx_stdlib archive_delete_la_files \
                                archive_sigtype archive_pubkey sites} {
                        dict set site_dict $var [array get ::portfetch::mirror_sites::$var]
                    }
                }
                set site_dict [$workername eval [list set site_dict]]
                interp delete $workername
            } else {
                set site_dict {}
            }
            load_compatible_sites $site_dict sites $mirrorfile
        }

        # get archive_sites.conf values
        proc load_conf_sites {} {
            load_compatible_sites [get_archive_sites_conf_values] conf_sites {}
        }

        # Given a dict of site info, saves the sites with compatible
        # settings in a namespace variable chosen by dest_var.
        proc load_compatible_sites {site_dict dest_var dest_dict_key} {
            global macports::prefix macports::frameworks_dir_frozen \
                macports::applications_dir macports::cxx_stdlib \
                macports::delete_la_files
            variable $dest_var

            if {$dest_dict_key ne {}} {
                dict set $dest_var $dest_dict_key [dict create]
            } else {
                set $dest_var [dict create]
            }
            set archive_sites [list]

            foreach site [dict keys [dict getwithdefault $site_dict archive_prefix {}]] {
                set missing 0
                foreach var {archive_frameworks_dir archive_applications_dir \
                            archive_type archive_cxx_stdlib archive_delete_la_files} {
                    if {![dict exists $site_dict $var $site]} {
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
                    set $var [dict get $site_dict $var $site]
                    if {[catch {set ${var}_norm [realpath [set $var]]}]} {
                        set ${var}_norm [file normalize [set $var]]
                    }
                }
                set site_urls [dict get $site_dict sites $site]
                set archive_type [dict get $site_dict archive_type $site]
                if {$site_urls ne {} &&
                    $archive_prefix_norm eq $prefix &&
                    $archive_frameworks_dir_norm eq $frameworks_dir_frozen &&
                    $archive_applications_dir_norm eq $applications_dir &&
                    [dict get $site_dict archive_cxx_stdlib $site] eq $cxx_stdlib &&
                    [dict get $site_dict archive_delete_la_files $site] eq $delete_la_files &&
                    ![catch {::portlib::util::archiveTypeIsSupported $archive_type}]} {
                    # using the archive type as a tag
                    lappend archive_sites ${site}::$archive_type
                    dict set $dest_var {*}$dest_dict_key urls $site $site_urls
                    dict set $dest_var {*}$dest_dict_key sigtype $site [dict getwithdefault $site_dict archive_sigtype $site {}]
                    dict set $dest_var {*}$dest_dict_key pubkey $site [dict getwithdefault $site_dict archive_pubkey $site {}]
                    dict set $dest_var {*}$dest_dict_key archivetype $site $archive_type
                }
            }
            dict set $dest_var {*}$dest_dict_key archive_sites $archive_sites
        }

        # read archive_sites.conf and return a dict of values
        proc get_archive_sites_conf_values {} {
            global macports::archive_sites_conf
            set site_dict [dict create]
            if {[file isfile $archive_sites_conf]} {
                global macports::os_platform macports::os_major
                set all_names [list]
                set defaults [dict create applications_dir /Applications/MacPorts prefix /opt/local type tbz2 sigtype rmd160]
                if {$os_platform eq "darwin" && $os_major <= 12} {
                    dict set defaults cxx_stdlib libstdc++
                    dict set defaults delete_la_files no
                } else {
                    dict set defaults cxx_stdlib libc++
                    dict set defaults delete_la_files yes
                }
                set conf_options [list applications_dir cxx_stdlib delete_la_files frameworks_dir name prefix type urls]
                set line_re {^(\w+)([ \t]+(.*))?$}
                set fd [open $archive_sites_conf r]
                while {[gets $fd line] >= 0} {
                    if {[regexp $line_re $line match option ignore val] == 1} {
                        if {$option in $conf_options} {
                            if {$option eq "name"} {
                                set cur_name $val
                                lappend all_names $val
                            } elseif {[info exists cur_name]} {
                                set trimmedval [string trim $val]
                                if {$option eq "urls"} {
                                    set processed_urls [list]
                                    foreach url $trimmedval {
                                        lappend processed_urls ${url}:nosubdir
                                    }
                                    dict set site_dict sites $cur_name $processed_urls
                                } else {
                                    dict set site_dict archive_$option $cur_name $trimmedval
                                }
                            } else {
                                ui_warn "archive_sites.conf: ignoring '$option' occurring before name"
                            }
                        } else {
                            ui_warn "archive_sites.conf: ignoring unknown key '$option'"
                        }
                    }
                }
                close $fd

                # check for unspecified values and set to defaults
                foreach cur_name $all_names {
                    foreach key [dict keys $defaults] {
                        if {![dict exists $site_dict archive_$key $cur_name]} {
                            dict set site_dict archive_$key $cur_name [dict get $defaults $key]
                        }
                    }
                    if {![dict exists $site_dict archive_frameworks_dir $cur_name]} {
                        dict set site_dict archive_frameworks_dir $cur_name [dict get $site_dict archive_prefix $cur_name]/Library/Frameworks
                    }
                    if {![dict exists $site_dict sites $cur_name]} {
                        ui_warn "archive_sites.conf: no urls set for $cur_name"
                        dict set site_dict sites $cur_name [list]
                    }
                }
            }
            return $site_dict
        }
    }

    namespace eval extract {
        # Map a given file name to a canonical extract method name
        proc method_for_suffix {filename} {
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

        proc get_extract_cmd {method} {
            switch $method {
                gzip {
                    return [macports::findBinary gzip ${::portlib::autoconf::gzip_path}]
                }
                bzip2 {
                    if {![catch {macports::findBinary lbzip2} result]} {
                        return $result
                    } else {
                        return [macports::findBinary bzip2 ${::portlib::autoconf::bzip2_path}]
                    }
                }
                xz {
                    return [macports::findBinary xz ${::portlib::autoconf::xz_path}]
                }
                zip {
                    return [macports::findBinary unzip ${::portlib::autoconf::unzip_path}]
                }
                zstd {
                    return [macports::binaryInPath zstd]
                }
                lzma {
                    return [macports::findBinary lzma ${::portlib::autoconf::lzma_path}]
                }
                tar {
                    return [macports::findBinary tar ${::portlib::autoconf::tar_command}]
                }
                7z {
                    return [macports::binaryInPath 7za]
                }
                lzip {
                    return [macports::binaryInPath lzip]
                }
                dmg {
                    return [macports::findBinary hdiutil ${::portlib::autoconf::hdiutil_path}]
                }
            }
            return {}
        }

        proc get_extract_pre_args {method} {
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
    }

    namespace eval fetch {
        # Mirror sites defined in the ports tree
        variable sites [dict create]
        # URLs for sites
        variable urls [dict create]

        # Return URLs for a given mirror site name
        proc get_mirror_site_urls {mirrorfile site} {
            variable urls
            if {![dict exists $urls $mirrorfile]} {
                load_mirror_sites $mirrorfile
            }
            return [dict getwithdefault $urls $mirrorfile $site {}]
        }

        # load mirror site info from ports tree resources
        proc load_mirror_sites {mirrorfile} {
            if {[file exists $mirrorfile]} {
                # evaluate mirror_sites.tcl in a safe interpreter
                set workername [interp create -safe]
                $workername expose source
                global macports::os_platform macports::os_major
                $workername eval [list set os.platform $os_platform]
                $workername eval [list set os.major $os_major]
                $workername eval [list source $mirrorfile]
                set site_dict [$workername eval [list array get ::portfetch::mirror_sites::sites]]
                interp delete $workername
            } else {
                set site_dict {}
            }
            variable sites
            variable urls
            dict set sites $mirrorfile [dict keys $site_dict]
            dict set urls $mirrorfile $site_dict
        }

        # percent-encode all characters in str that are not unreserved in URIs
        proc percent_encode {str} {
            set outstr {}
            set len [string length $str]
            for {set i 0} {$i < $len} {incr i} {
                set char [string index $str $i]
                switch -- $char {
                    {-} -
                    {.} -
                    {_} -
                    {~} {
                        append outstr $char
                    }
                    default {
                        if {[string is ascii -strict $char] && [string is alnum -strict $char]} {
                            append outstr $char
                        } else {
                            foreach {a b} [split [format %02X [scan $char %c]] {}] {
                                append outstr %${a}${b}
                            }
                        }
                    }
                }
            }
            return $outstr
        }

        # Given a site url and the name of the distfile, assemble url and
        # return it.
        proc assemble_url {site distfile} {
            if {[string index $site end] ne "/"} {
                append site /
            }
            return ${site}[percent_encode ${distfile}]
        }

        # Given a *_sites entry that possibly has a tag on the end, return a
        # list consisting of the part of the entry preceding the tag, and the
        # tag itself.
        proc separate_tag {element} {
            # tag will be after the last colon after the
            # first slash after the ://
            set lastcolon [string last : $element]
            set aftersep [expr {[string first : $element] + 3}]
            set firstslash [string first / $element $aftersep]
            if {$firstslash != -1 && $firstslash < $lastcolon} {
                set tag [string range $element ${lastcolon}+1 end]
                set element [string range $element 0 ${lastcolon}-1]
            } else {
                set tag {}
            }
            return [list $element $tag]
        }
    }

    namespace eval util {
        # check if archive type is supported by current system
        # returns an error code if it is not
        proc archiveTypeIsSupported {type} {
            set errmsg ""
            switch -regex $type {
                aar {
                    set aa "aa"
                    if {[catch {set aa [macports::findBinary $aa ${::portlib::autoconf::aa_path}]} errmsg] == 0} {
                        return 0
                    }
                }
                cp(io|gz) {
                    set pax "pax"
                    if {[catch {set pax [macports::findBinary $pax ${::portlib::autoconf::pax_path}]} errmsg] == 0} {
                        if {[regexp {z$} $type]} {
                            set gzip "gzip"
                            if {[catch {set gzip [macports::findBinary $gzip ${::portlib::autoconf::gzip_path}]} errmsg] == 0} {
                                return 0
                            }
                        } else {
                            return 0
                        }
                    }
                }
                t(ar|bz|lz|xz|gz) {
                    set tar "tar"
                    if {[catch {set tar [macports::findBinary $tar ${::portlib::autoconf::tar_path}]} errmsg] == 0} {
                        if {[regexp {z2?$} $type]} {
                            if {[regexp {bz2?$} $type]} {
                                set gzip "bzip2"
                            } elseif {[regexp {lz$} $type]} {
                                set gzip "lzma"
                            } elseif {[regexp {xz$} $type]} {
                                set gzip "xz"
                            } else {
                                set gzip "gzip"
                            }
                            if {[info exists ::portlib::autoconf::${gzip}_path]} {
                                set hint [set ::portlib::autoconf::${gzip}_path]
                            } else {
                                set hint ""
                            }
                            if {[catch {set gzip [macports::findBinary $gzip $hint]} errmsg] == 0} {
                                return 0
                            }
                        } else {
                            return 0
                        }
                    }
                }
                xar {
                    set xar "xar"
                    if {[catch {set xar [macports::findBinary $xar ${::portlib::autoconf::xar_path}]} errmsg] == 0} {
                        return 0
                    }
                }
                zip {
                    set zip "zip"
                    if {[catch {set zip [macports::findBinary $zip ${::portlib::autoconf::zip_path}]} errmsg] == 0} {
                        set unzip "unzip"
                        if {[catch {set unzip [macports::findBinary $unzip ${::portlib::autoconf::unzip_path}]} errmsg] == 0} {
                            return 0
                        }
                    }
                }
                default {
                    return -code error [format [msgcat::mc "Invalid port archive type '%s' specified!"] $type]
                }
            }
            return -code error [format [msgcat::mc "Unsupported port archive type '%s': %s"] $type $errmsg]
        }

        # return list of archive types that we can extract
        proc supportedArchiveTypes {} {
            variable supported_archive_types
            if {![info exists supported_archive_types]} {
                set supported_archive_types [list]
                foreach type [list tbz2 tbz tgz tar txz tlz xar zip cpgz cpio aar] {
                    if {[catch {archiveTypeIsSupported $type}] == 0} {
                        lappend supported_archive_types $type
                    }
                }
            }
            return $supported_archive_types
        }

        # If the given path is in a git checkout, return the currently checked
        # out commit. If not, return an empty string.
        proc get_path_commit {path} {
            set result {}
            if {![catch {macports::findBinary git} git] && ![catch {file type $path} ftype]} {
                if {$ftype ne "directory"} {
                    set path [file dirname $path]
                }
                # Recent git refuses to run if the current user doesn't own
                # the checkout, unless safe.directory is set.
                if {[catch {exec -ignorestderr $git -c safe.directory=* -C $path rev-parse HEAD 2> /dev/null} result]} {
                    ui_debug "get_path_commit: git rev-parse failed: $result"
                    set result {}
                }
            }
            return $result
        }

        # If all the given paths are in a git repo with no uncommitted
        # changes, return the timestamp of the latest commit affecting
        # any of them. Otherwise, return an empty string.
        proc get_latest_commit_time {checkpaths} {
            if {[catch {macports::findBinary git} git]} {
                return {}
            }
            set checkdirs [lmap p $checkpaths {expr {[file isdirectory $p] ? $p : [file dirname $p]}}]
            foreach d $checkdirs {
                if {[catch {exec -ignorestderr $git -c safe.directory=* -C $d rev-parse --is-inside-work-tree 2> /dev/null}]} {
                    return {}
                }
            }
            # Use time of last commit only if there are no uncommitted changes
            set any_uncommitted 0
            foreach p $checkpaths d $checkdirs {
                if {[catch {exec -ignorestderr $git -c safe.directory=* -C $d status --porcelain $p 2> /dev/null} result]} {
                    ui_debug "get_latest_commit_time: git status failed: $result"
                    return {}
                } elseif {$result ne ""} {
                    ui_debug "get_latest_commit_time: uncommitted changes to $p"
                    return {}
                }
            }
            set newest 0
            foreach p $checkpaths d $checkdirs {
                if {![catch {exec -ignorestderr $git -c safe.directory=* -C $d log -1 --pretty=%ct $p 2> /dev/null} result]} {
                    if {$result > $newest} {
                        set newest $result
                    }
                } else {
                    ui_debug "get_latest_commit_time: git log failed: $result"
                    return {}
                }
            }
            return $newest
        }

        # return the latest mtime of any file at or under the given paths
        proc get_latest_path_mtime {checkpaths} {
            set newest 0
            fs-traverse fullpath $checkpaths {
                if {[catch {
                    if {[file type $fullpath] eq "file"} {
                        set mtime [file mtime $fullpath]
                        if {$mtime > $newest} {
                            set newest $mtime
                        }
                    }
                } result]} {
                    ui_debug "get_latest_path_mtime: $result"
                }
            }
            return $newest
        }

        ########### Distname utility functions ###########

        # Given a distribution file name, return the appended tag
        # Example: getdisttag distfile.tar.gz:tag1 returns "tag1"
        # / isn't included in the regexp, thus allowing port specification in URLs.
        proc getdisttag {filename} {
            if {[regexp {.+:([0-9A-Za-z_-]+)$} $filename match tag]} {
                return $tag
            } else {
                return {}
            }
        }

        # Given a distribution file name, return the name without an attached tag
        # Example : getdistname distfile.tar.gz:tag1 returns "distfile.tar.gz"
        # / isn't included in the regexp, thus allowing port specification in URLs.
        proc getdistname {filename} {
            regexp {(.+):[0-9A-Za-z_-]+$} $filename match filename
            return $filename
        }

        # ldelete
        # Deletes a value from the supplied list
        proc ldelete {list value} {
            set ix [lsearch -exact $list $value]
            if {$ix >= 0} {
                lpop list $ix
            }
            return $list
        }

        # reinplace
        # Provides "sed in place" functionality
        proc reinplace {dir tempdir args}  {
            global env macports::ui_prefix
            set extended 0
            set suppress 0
            set quiet 0
            set oldlocale_exists 0
            set oldlocale {}
            set locale {}
            while {1} {
                set arg [lindex $args 0]
                if {[string index $arg 0] eq "-"} {
                    set args [lrange $args 1 end]
                    switch -- [string range $arg 1 end] {
                        locale {
                            set oldlocale_exists [info exists env(LC_CTYPE)]
                            if {$oldlocale_exists} {
                                set oldlocale $env(LC_CTYPE)
                            }
                            set locale [lindex $args 0]
                            set args [lrange $args 1 end]
                        }
                        E {
                            set extended 1
                        }
                        n {
                            set suppress 1
                        }
                        q {
                            set quiet 1
                        }
                        W {
                            set dir [lindex $args 0]
                            set args [lrange $args 1 end]
                        }
                        - {
                            break
                        }
                        default {
                            error "reinplace: unknown flag '$arg'"
                        }
                    }
                } else {
                    break
                }
            }
            if {[llength $args] < 2} {
                error "reinplace ?-E? ?-n? ?-q? ?-W dir? pattern file ..."
            }
            set pattern [lindex $args 0]
            set files [lrange $args 1 end]

            if {![file isdirectory ${tempdir}]} {
                set tempdir [file tempdir]
            }

            foreach file $files {
                # if $file is an absolute path already, file join will just return the
                # absolute path, otherwise it is $dir/$file
                set file [file join $dir $file]

                if {[catch {set tmpfd [file tempfile tmpfile ${tempdir}/[file tail $file].sed]} error]} {
                    ui_debug $::errorInfo
                    ui_error "reinplace: $error"
                    return -code error "reinplace failed"
                }

                set cmdline [list $::portlib::autoconf::sed_command]
                if {$extended} {
                    lappend cmdline -E
                }
                if {$suppress} {
                    lappend cmdline -n
                }
                lappend cmdline $pattern "<$file" ">@$tmpfd"
                if {$locale ne ""} {
                    set env(LC_CTYPE) $locale
                }
                ui_info "$ui_prefix [format [msgcat::mc "Patching %s: %s"] [file tail $file] $pattern]"
                ui_debug "Executing reinplace: $cmdline"
                if {[catch {exec -ignorestderr -- {*}$cmdline} error]} {
                    ui_debug $::errorInfo
                    ui_error "reinplace: $error"
                    file delete "$tmpfile"
                    if {$locale ne ""} {
                        if {$oldlocale_exists} {
                            set env(LC_CTYPE) $oldlocale
                        } else {
                            unset env(LC_CTYPE)
                        }
                    }
                    close $tmpfd
                    return -code error "reinplace sed(1) failed"
                }

                if {$locale ne ""} {
                    if {$oldlocale_exists} {
                        set env(LC_CTYPE) $oldlocale
                    } else {
                        unset env(LC_CTYPE)
                    }
                }
                close $tmpfd

                if {!$quiet && ![catch {exec -ignorestderr cmp -s $file $tmpfile}]} {
                    ui_warn "[format [msgcat::mc "reinplace %1\$s didn't change anything in %2\$s"] $pattern $file]"
                }

                set attributes [file attributes $file]
                chownAsRoot $file

                # We need to overwrite this file
                if {[catch {file attributes $file -permissions u+w} error]} {
                    ui_debug $::errorInfo
                    ui_error "reinplace: $error"
                    file delete "$tmpfile"
                    return -code error "reinplace permissions failed"
                }

                if {[catch {file copy -force $tmpfile $file} error]} {
                    ui_debug $::errorInfo
                    ui_error "reinplace: $error"
                    file delete "$tmpfile"
                    return -code error "reinplace copy failed"
                }

                fileAttrsAsRoot $file $attributes

                file delete $tmpfile
            }
        }

        # touch
        # mimics the BSD touch command
        proc touch {dir args} {
            while {[string match "-*" [lindex $args 0]]} {
                set arg [string range [lindex $args 0] 1 end]
                set args [lrange $args 1 end]
                switch -- $arg {
                    a -
                    c -
                    m {set options($arg) yes}
                    r -
                    t {
                        set narg [lindex $args 0]
                        set args [lrange $args 1 end]
                        if {$narg eq ""} {
                            return -code error "touch: option requires an argument -- $arg"
                        }
                        set options($arg) $narg
                        set options(rt) $arg ;# later option overrides earlier
                    }
                    W {
                        set dir [lindex $args 0]
                        set args [lrange $args 1 end]
                    }
                    - break
                    default {return -code error "touch: illegal option -- $arg"}
                }
            }

            # parse the r/t options
            if {[info exists options(rt)]} {
                if {$options(rt) eq "r"} {
                    # -r
                    # get atime/mtime from the file
                    if {[file exists $options(r)]} {
                        set atime [file atime $options(r)]
                        set mtime [file mtime $options(r)]
                    } else {
                        return -code error "touch: $options(r): No such file or directory"
                    }
                } else {
                    # -t
                    # parse the time specification
                    # turn it into a CCyymmdd hhmmss
                    set timespec {^(?:(\d\d)?(\d\d))?(\d\d)(\d\d)(\d\d)(\d\d)(?:\.(\d\d))?$}
                    if {[regexp $timespec $options(t) {} CC YY MM DD hh mm SS]} {
                        if {$YY eq ""} {
                            set year [clock format [clock seconds] -format %Y]
                        } elseif {$CC eq ""} {
                            if {$YY >= 69 && $YY <= 99} {
                                set year 19$YY
                            } else {
                                set year 20$YY
                            }
                        } else {
                            set year $CC$YY
                        }
                        if {$SS eq ""} {
                            set SS 00
                        }
                        set atime [clock scan "$year$MM$DD $hh$mm$SS"]
                        set mtime $atime
                    } else {
                        return -code error \
                            {touch: out of range or illegal time specification: [[CC]YY]MMDDhhmm[.SS]}
                    }
                }
            } else {
                set atime [clock seconds]
                set mtime [clock seconds]
            }

            # do we have any files to process?
            if {[llength $args] == 0} {
                # print usage
                return -code error {usage: touch [-a] [-c] [-m] [-r file] [-t [[CC]YY]MMDDhhmm[.SS]] [-W dir] file ...}
            }

            foreach file $args {
                # if $file is an absolute path already, file join will just
                # return the absolute path, otherwise it is $dir/$file
                set file [file join $dir $file]

                if {![file exists $file]} {
                    if {[info exists options(c)]} {
                        continue
                    } else {
                        close [open $file w]
                    }
                }

                if {[info exists options(a)] || ![info exists options(m)]} {
                    file atime $file $atime
                }
                if {[info exists options(m)] || ![info exists options(a)]} {
                    file mtime $file $mtime
                }
            }
        }

        # copy
        # Wrapper for file copy
        proc copy {args} {
            file copy {*}$args
        }

        # delete
        # Wrapper for file delete -force
        proc delete {args} {
            file delete -force -- {*}$args
        }

        # move
        # Wrapper for file rename that handles case-only renames
        proc move {args} {
            set options [list]
            while {[string match "-*" [lindex $args 0]]} {
                set arg [string range [lpop args 0] 1 end]
                switch -- $arg {
                    force {lappend options -$arg}
                    - break
                    default {return -code error "move: illegal option -- $arg"}
                }
            }
            lappend options --
            if {[llength $args] == 2} {
                set oldname [lindex $args 0]
                set newname [lindex $args 1]
                if {[string equal -nocase $oldname $newname] && $oldname ne $newname} {
                    # case-only rename
                    set tempdir [mkdtemp ${oldname}-XXXXXXXX]
                    set tempname $tempdir/[file tail $oldname]
                    file rename {*}$options $oldname $tempname
                    file rename {*}$options $tempname $newname
                    delete $tempdir
                    return
                }
            }
            file rename {*}$options {*}$args
        }

        # ln
        # Mimics the BSD ln implementation
        # ln [-f] [-h] [-s] [-v] source_file [target_file]
        # ln [-f] [-h] [-s] [-v] source_file ... target_dir
        proc ln {args} {
            while {[string match "-*" [lindex $args 0]]} {
                set arg [string range [lindex $args 0] 1 end]
                if {[string length $arg] > 1} {
                    set remainder -[string range $arg 1 end]
                    set arg [string range $arg 0 0]
                    lset args 0 $remainder
                } else {
                    lpop args 0
                }
                switch -- $arg {
                    f -
                    h -
                    s -
                    v {set options($arg) yes}
                    - break
                    default {return -code error "ln: illegal option -- $arg"}
                }
            }

            if {[llength $args] == 0} {
                return -code error [join {{usage: ln [-f] [-h] [-s] [-v] source_file [target_file]}
                                          {       ln [-f] [-h] [-s] [-v] file ... directory}} "\n"]
            } elseif {[llength $args] == 1} {
                set files $args
                set target ./
            } else {
                set files [lrange $args 0 end-1]
                set target [lindex $args end]
            }

            set target_dir 0
            set append_path 0
            if {[file isdirectory $target]} {
                set target_dir 1
                if {[file type $target] ne "link" || ![info exists options(h)]} {
                    set append_path 1
                }
            }

            foreach file $files {
                if {[file isdirectory $file] && ![info exists options(s)]} {
                    return -code error "ln: $file: Is a directory"
                }

                if {$append_path} {
                    set linktarget [file join $target [file tail $file]]
                } else {
                    set linktarget $target
                }

                if {![catch {file type $linktarget}]} {
                    if {[info exists options(f)]} {
                        file delete $linktarget
                    } else {
                        return -code error "ln: $linktarget: File exists"
                    }
                }

                if {[llength $files] > 1} {
                    if {!$append_path && ![file exists $linktarget]} {
                        return -code error "ln: $linktarget: No such file or directory"
                    } elseif {!$target_dir} {
                        # this error isn't strictly what BSD ln gives, but I think it's more useful
                        return -code error "ln: $target: Not a directory"
                    }
                }

                if {[info exists options(v)]} {
                    ui_notice "ln: $linktarget -> $file"
                }
                if {[info exists options(s)]} {
                    symlink $file $linktarget
                } else {
                    file link -hard $linktarget $file
                }
            }
        }

        # recursive dependency search for portname
        proc recursive_collect_deps {portname {depsfound {}}} \
        {
            # Get the active port from the registry
            set entries [registry::entry installed $portname]
            if {[llength $entries < 1]} {
                ui_warn "recursive_collect_deps: '$portname' is registered as a dependency but is not active"
                return $depsfound
            }
            # There can be only one port version active at a time, so take the first result only
            set regentry [lindex $entries 0]

            # Get port dependencies from the registry
            foreach item [$regentry dependencies] {
                set depname [string tolower [$item name]]
                if {![dict exists $depsfound $depname]} {
                    dict set depsfound $depname 1
                    set depsfound [recursive_collect_deps $depname $depsfound]
                }
            }

            return $depsfound
        }

        # Given a list of variant specifications, return a canonical string form
        # for the registry.
        # The strategy is as follows: regardless of how some collection of variants
        # was turned on or off, a particular instance of the port is uniquely
        # characterized by the set of variants that are *on*. Thus, record those
        # variants in a string in a standard order as +var1+var2 etc.
        # Can also do the same for -variants, for recording the negated list.
        proc canonicalize_variants {variants {sign "+"}} {
            set result {}
            set vlist [lsort -ascii [dict keys $variants]]
            foreach v $vlist {
                if {[dict get $variants $v] eq $sign} {
                    append result ${sign}${v}
                }
            }
            return $result
        }

        proc adduser {username args} {
            global macports::os_platform

            if {[getuid] != 0} {
                ui_warn "adduser only works when running as root."
                ui_warn "The requested user '$username' was not created."
                return
            }

            set passwd {*}
            set uid [nextuid]
            set gid [existsgroup nogroup]
            set realname ${username}
            set home /var/empty
            set shell /usr/bin/false

            set keyval_re {([a-z]*)=(.*)}
            foreach arg $args {
                if {[regexp $keyval_re $arg match key val]} {
                    set $key $val
                }
            }

            if {[existsuser ${username}] != -1 || [existsuser ${uid}] != -1} {
                return
            }

            if {[geteuid] != 0} {
                seteuid 0; setegid 0
                set escalated 1
            }

            if {${os_platform} eq "darwin"} {
                set dscl [findBinary dscl $::portlib::autoconf::dscl_path]
                set failed? 0
                macports_try {
                    exec -ignorestderr $dscl . -create /Users/${username} UniqueID ${uid}

                    # These are implicitly added on Mac OS X Lion.  AuthenticationAuthority
                    # causes the user to be visible in the Users & Groups Preference Pane,
                    # and the others are just noise, so delete them.
                    # https://trac.macports.org/ticket/30168
                    exec -ignorestderr $dscl . -delete /Users/${username} AuthenticationAuthority
                    exec -ignorestderr $dscl . -delete /Users/${username} PasswordPolicyOptions
                    exec -ignorestderr $dscl . -delete /Users/${username} dsAttrTypeNative:KerberosKeys
                    exec -ignorestderr $dscl . -delete /Users/${username} dsAttrTypeNative:ShadowHashData

                    exec -ignorestderr $dscl . -create /Users/${username} RealName ${realname}
                    exec -ignorestderr $dscl . -create /Users/${username} Password ${passwd}
                    exec -ignorestderr $dscl . -create /Users/${username} PrimaryGroupID ${gid}
                    exec -ignorestderr $dscl . -create /Users/${username} NFSHomeDirectory ${home}
                    exec -ignorestderr $dscl . -create /Users/${username} UserShell ${shell}
                } on error {{CHILDKILLED *} eCode eMessage} {
                    # the foreachs are a simple workaround for Tcl 8.4, which doesn't
                    # seem to have lassign
                    foreach {- pid sigName msg} $eCode {
                        ui_error "dscl($pid) was killed by $sigName: $msg"
                        ui_debug "dscl printed: $eMessage"
                    }

                    set failed? 1
                } on error {{CHILDSTATUS *} eCode eMessage} {
                    foreach {- pid code} $eCode {
                        ui_error "dscl($pid) terminated with an exit status of $code"
                        ui_debug "dscl printed: $eMessage"
                    }

                    set failed? 1
                } on error {{POSIX *} eCode eMessage} {
                    foreach {- errName msg} {
                        ui_error "failed to execute $dscl: $errName: $msg"
                        ui_debug "dscl printed: $eMessage"
                    }

                    set failed? 1
                } finally {
                    if {${failed?}} {
                        # creating the user properly failed and we're bailing out
                        # anyway, try to delete the half-created user to revert to the
                        # state before the error
                        ui_debug "Attempting to clean up failed creation of user $username"
                        macports_try {
                            exec -ignorestderr $dscl . -delete /Users/${username}
                        } on error {{CHILDKILLED *} eCode eMessage} {
                            foreach {- pid sigName msg} {
                                ui_warn "dscl($pid) was killed by $sigName: $msg while trying to clean up failed creation of user $username."
                                ui_debug "dscl printed: $eMessage"
                            }
                        } on error {{CHILDSTATUS *} eCode eMessage} {
                            # ignoring childstatus failure, because that probably means
                            # the first call failed and the user wasn't even created
                        } on error {{POSIX *} eCode eMessage} {
                            foreach {- errName msg} {
                                ui_warn "failed to execute $dscl: $errName: $msg while trying to clean up failed creation of user $username."
                                ui_debug "dscl printed: $eMessage"
                            }
                        }

                        # drop privileges if they were escalated before
                        if {[info exists escalated]} {
                            dropPrivileges
                        }

                        # and raise an error to abort
                        error "dscl failed to create required user $username."
                    }
                }
            } else {
                # XXX adduser is only available for darwin, add more support here
                ui_warn "adduser is not implemented on ${os_platform}."
                ui_warn "The requested user '$username' was not created."
            }

            if {[info exists escalated]} {
                dropPrivileges
            }
        }

        proc addgroup {groupname args} {
            global macports::os_platform

            if {[getuid] != 0} {
                ui_warn "addgroup only works when running as root."
                ui_warn "The requested group '$groupname' was not created."
                return
            }

            set gid [nextgid]
            set realname ${groupname}
            set passwd {*}
            set users ""

            set keyval_re {([a-z]*)=(.*)}
            foreach arg $args {
                if {[regexp $keyval_re $arg match key val]} {
                    set $key $val
                }
            }

            if {[existsgroup ${groupname}] != -1 || [existsgroup ${gid}] != -1} {
                return
            }

            if {[geteuid] != 0} {
                seteuid 0; setegid 0
                set escalated 1
            }

            if {${os_platform} eq "darwin"} {
                set dscl [findBinary dscl $::portlib::autoconf::dscl_path]
                set failed? 0
                macports_try {
                    exec -ignorestderr $dscl . -create /Groups/${groupname} Password ${passwd}
                    exec -ignorestderr $dscl . -create /Groups/${groupname} RealName ${realname}
                    exec -ignorestderr $dscl . -create /Groups/${groupname} PrimaryGroupID ${gid}
                    if {${users} ne ""} {
                        exec -ignorestderr $dscl . -create /Groups/${groupname} GroupMembership ${users}
                    }
                } on error {{CHILDKILLED *} eCode eMessage} {
                    # the foreachs are a simple workaround for Tcl 8.4, which doesn't
                    # seem to have lassign
                    foreach {- pid sigName msg} $eCode {
                        ui_error "dscl($pid) was killed by $sigName: $msg"
                        ui_debug "dscl printed: $eMessage"
                    }

                    set failed? 1
                } on error {{CHILDSTATUS *} eCode eMessage} {
                    foreach {- pid code} $eCode {
                        ui_error "dscl($pid) terminated with an exit status of $code"
                        ui_debug "dscl printed: $eMessage"
                    }

                    set failed? 1
                } on error {{POSIX *} eCode eMessage} {
                    foreach {- errName msg} {
                        ui_error "failed to execute $dscl: $errName: $msg"
                        ui_debug "dscl printed: $eMessage"
                    }

                    set failed? 1
                } finally {
                    if {${failed?}} {
                        # creating the user properly failed and we're bailing out
                        # anyway, try to delete the half-created user to revert to the
                        # state before the error
                        ui_debug "Attempting to clean up failed creation of group $groupname"
                        macports_try {
                            exec -ignorestderr $dscl . -delete /Groups/${groupname}
                        } on error {{CHILDKILLED *} eCode eMessage} {
                            foreach {- pid sigName msg} {
                                ui_warn "dscl($pid) was killed by $sigName: $msg while trying to clean up failed creation of group $groupname."
                                ui_debug "dscl printed: $eMessage"
                            }
                        } on error {{CHILDSTATUS *} eCode eMessage} {
                            # ignoring childstatus failure, because that probably means
                            # the first call failed and the user wasn't even created
                        } on error {{POSIX *} eCode eMessage} {
                            foreach {- errName msg} {
                                ui_warn "failed to execute $dscl: $errName: $msg while trying to clean up failed creation of group $groupname."
                                ui_debug "dscl printed: $eMessage"
                            }
                        }

                        if {[info exists escalated]} {
                            dropPrivileges
                        }

                        # and raise an error to abort
                        error "dscl failed to create required group $groupname."
                    }
                }
            } else {
                # XXX addgroup is only available for darwin, add more support here
                ui_warn "addgroup is not implemented on ${os_platform}."
                ui_warn "The requested group was not created."
            }

            if {[info exists escalated]} {
                dropPrivileges
            }
        }

        # proc to calculate size of a directory
        # moved here from portpkg.tcl
        proc dirSize {dir} {
            set size    0;
            foreach file [readdir $dir] {
                if {[file type [file join $dir $file]] eq "link" } {
                    continue
                }
                if {[file isdirectory [file join $dir $file]]} {
                    incr size [dirSize [file join $dir $file]]
                } else {
                    incr size [file size [file join $dir $file]];
                }
            }
            return $size;
        }

        # return the specified pieces of metadata from the +CONTENTS file in the given archive
        proc extract_archive_metadata {archive_location archive_type metadata_types tempdir} {
            set qflag ${::portlib::autoconf::tar_q}
            set raw_contents {}

            if {$archive_type in {xar cpgz cpio aar}} {
                set twostep 1
                if {[file isdirectory $tempdir]} {
                    set tempdir [file tempdir ${tempdir}/portarchive]
                } else {
                    set tempdir [file tempdir portarchive]
                }
            }

            switch -- $archive_type {
                tbz -
                tbz2 {
                    set raw_contents [exec -ignorestderr [macports::findBinary tar ${::portlib::autoconf::tar_path}] -xOj${qflag}f $archive_location ./+CONTENTS]
                }
                tgz {
                    set raw_contents [exec -ignorestderr [macports::findBinary tar ${::portlib::autoconf::tar_path}] -xOz${qflag}f $archive_location ./+CONTENTS]
                }
                tar {
                    set raw_contents [exec -ignorestderr [macports::findBinary tar ${::portlib::autoconf::tar_path}] -xO${qflag}f $archive_location ./+CONTENTS]
                }
                txz {
                    set raw_contents [exec -ignorestderr [macports::findBinary tar ${::portlib::autoconf::tar_path}] -xO${qflag}f $archive_location --use-compress-program [macports::findBinary xz ""] ./+CONTENTS]
                }
                tlz {
                    set raw_contents [exec -ignorestderr [macports::findBinary tar ${::portlib::autoconf::tar_path}] -xO${qflag}f $archive_location --use-compress-program [macports::findBinary lzma ""] ./+CONTENTS]
                }
                xar {
                    system -W ${tempdir} "[macports::findBinary xar ${::portlib::autoconf::xar_path}] -xf [shellescape $archive_location] +CONTENTS"
                }
                zip {
                    set raw_contents [exec -ignorestderr [macports::findBinary unzip ${::portlib::autoconf::unzip_path}] -p $archive_location +CONTENTS]
                }
                cpgz {
                    system -W ${tempdir} "[macports::findBinary pax ${::portlib::autoconf::pax_path}] -rzf [shellescape $archive_location] +CONTENTS"
                }
                cpio {
                    system -W ${tempdir} "[macports::findBinary pax ${::portlib::autoconf::pax_path}] -rf [shellescape $archive_location] +CONTENTS"
                }
                aar {
                    system -W ${tempdir} "[macports::findBinary aa ${::portlib::autoconf::aa_path}] extract -i [shellescape $archive_location] -include-path +CONTENTS"
                }
            }
            if {[info exists twostep]} {
                set fd [open "${tempdir}/+CONTENTS"]
                set raw_contents [read -nonewline $fd]
                close $fd
                file delete -force $tempdir
            }
            set ret [dict create]
            foreach metadata_type $metadata_types {
                switch -- $metadata_type {
                    contents {
                        set contents [list]
                        set binary_info [list]
                        set ignore 0
                        set sep [file separator]
                        foreach line [split $raw_contents \n] {
                            if {$ignore} {
                                set ignore 0
                                continue
                            }
                            if {[string index $line 0] ne "@"} {
                                lappend contents "${sep}${line}"
                            } elseif {$line eq "@ignore"} {
                                set ignore 1
                            } elseif {[string range $line 0 15] eq "@comment binary:"} {
                                lappend binary_info [lindex $contents end] [string range $line 16 end]
                            }
                        }
                        dict set ret contents [list $contents $binary_info]
                    }
                    portname {
                        set portname {}
                        foreach line [split $raw_contents \n] {
                            if {[lindex $line 0] eq "@portname"} {
                                set portname [lindex $line 1]
                                break
                            }
                        }
                        dict set ret portname $portname
                    }
                    cxx_info {
                        set val_cxx_stdlib ""
                        set val_cxx_stdlib_overridden ""
                        foreach line [split $raw_contents \n] {
                            if {[lindex $line 0] eq "@cxx_stdlib"} {
                                set val_cxx_stdlib [lindex $line 1]
                                if {$val_cxx_stdlib_overridden ne ""} {
                                    break
                                }
                            } elseif {[lindex $line 0] eq "@cxx_stdlib_overridden"} {
                                set val_cxx_stdlib_overridden [lindex $line 1]
                                if {$val_cxx_stdlib ne ""} {
                                    break
                                }
                            }
                        }
                        dict set ret cxx_info [list $val_cxx_stdlib $val_cxx_stdlib_overridden]
                    }
                    default {
                        return -code error "unknown metadata_type: $metadata_type"
                    }
                }
            }
            return $ret
        }

        ##
        # Escape a string for safe use in regular expressions
        #
        # @param str the string to be quoted
        # @return the escaped string
        proc quotemeta {str} {
            regsub -all {(\W)} $str {\\\1} str
            return $str
        }

        ##
        # Recursively chown the given file or directory to the specified user.
        #
        # @param path the file/directory to be chowned
        # @param user the user to chown file to
        proc chown {path user} {
            lchown $path $user

            if {[file isdirectory $path]} {
                fs-traverse myfile [list $path] {
                    lchown $myfile $user
                }
            }
        }

        ##
        # Recursively chown the given file or directory to $macportsuser, using root privileges.
        #
        # @param path the file/directory to be chowned
        proc chownAsRoot {path} {
            if {[getuid] == 0} {
                global macports::macportsuser
                if {[geteuid] != 0} {
                    # if started with sudo but have dropped the privileges
                    seteuid 0; setegid 0
                    ui_debug "euid/egid changed to: [geteuid]/[getegid]"
                    set drop_after 1
                }
                chown $path $macportsuser
                ui_debug "chowned $path to $macportsuser"
                if {[info exists drop_after]} {
                    setegid [uname_to_gid $macportsuser]
                    seteuid [name_to_uid $macportsuser]
                    ui_debug "euid/egid changed to: [geteuid]/[getegid]"
                }
            }
        }

        ##
        # Change attributes of file while running as root
        #
        # @param file the file in question
        # @param attributes the attributes for the file
        proc fileAttrsAsRoot {file attributes} {
            if {[getuid] == 0} {
                if {[geteuid] != 0} {
                    # Started as root, but not root now
                    seteuid 0; setegid 0
                    ui_debug "euid/egid changed to: [geteuid]/[getegid]"
                    set drop_after 1
                }
                ui_debug "setting attributes on $file"
                file attributes $file {*}$attributes
                if {[info exists drop_after]} {
                    global macports::macportsuser
                    setegid [uname_to_gid $macportsuser]
                    seteuid [name_to_uid $macportsuser]
                    ui_debug "euid/egid changed to: [geteuid]/[getegid]"
                }
            } else {
                # not root, so can't set owner/group
                set permissions [lindex $attributes [lsearch -exact $attributes "-permissions"]+1]
                file attributes $file -permissions $permissions
            }
        }

        ##
        # Elevate privileges back to root.
        #
        # @param action the action for which privileges are being elevated
        proc elevateToRoot {action} {
            if {[getuid] != 0} {
                return -code error "MacPorts requires root privileges for this action"
            }
            if {[geteuid] != 0} {
                # if started with sudo but have dropped the privileges
                seteuid 0; setegid 0
                ui_debug "elevating privileges for $action: euid changed to [geteuid], egid changed to [getegid]."
            }
        }

        ##
        # de-escalate privileges from root to those of $macportsuser.
        #
        proc dropPrivileges {} {
            if {[geteuid] == 0} {
                global macports::macportsuser
                if { [catch {
                        if {[name_to_uid $macportsuser] != 0} {
                            setegid [uname_to_gid $macportsuser]
                            seteuid [name_to_uid $macportsuser]
                            ui_debug "dropping privileges: euid changed to [geteuid], egid changed to [getegid]."
                        }
                    }]
                } {
                    ui_debug $::errorInfo
                    ui_error "Failed to de-escalate privileges."
                }
            } else {
                ui_debug "Privilege de-escalation not attempted as not running as root."
            }
        }

        # get the mountpoint providing a given directory
        proc get_mountpoint {target_dir} {
            file stat $target_dir target_stat
            set cur_dir $target_dir
            while {$cur_dir ne "/"} {
                set next_parent [file dirname $cur_dir]
                file stat $next_parent stat

                if {$stat(dev) != $target_stat(dev)} {
                    return $cur_dir
                }

                set cur_dir $next_parent
            }

            return $cur_dir
        }

    }
}
