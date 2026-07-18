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
    }
}
