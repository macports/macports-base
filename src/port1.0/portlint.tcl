# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
#
# Copyright (c) 2007 - 2018, 2020 The MacPorts Project
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
# 3. Neither the name of The MacPorts Project nor the names of its contributors
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

package provide portlint 1.0
package require portutil 1.0
package require portchecksum 1.0

set org.macports.lint [target_new org.macports.lint portlint::lint_main]
target_runtype ${org.macports.lint} always
target_state ${org.macports.lint} no
target_provides ${org.macports.lint} lint
target_requires ${org.macports.lint} main
target_prerun ${org.macports.lint} portlint::lint_start

namespace eval portlint {
}

set_ui_prefix

set lint_portsystem \
    "1.0"

set lint_platforms [list \
    "darwin" \
    "freebsd" \
    "linux" \
    "macosx" \
    "netbsd" \
    "openbsd" \
    "puredarwin" \
    "solaris" \
    "sunos" \
    ]

set lint_required [list \
    "name" \
    "version" \
    "description" \
    "long_description" \
    "categories" \
    "maintainers" \
    "platforms" \
    "homepage" \
    "master_sites" \
    "checksums" \
    "license"
    ]

set lint_optional [list \
    "epoch" \
    "revision" \
    "worksrcdir" \
    "distname" \
    "use_automake" \
    "use_autoconf" \
    "use_autoreconf" \
    "use_configure" \
    ]

proc portlint::seems_utf8 {str} {
    set len [string length $str]
    for {set i 0} {$i<$len} {incr i} {
        set c [scan [string index $str $i] %c]
        if {$c < 0x80} {
            # ASCII
            continue
        } elseif {($c & 0xE0) == 0xC0} {
            set n 1
        } elseif {($c & 0xF0) == 0xE0} {
            set n 2
        } elseif {($c & 0xF8) == 0xF0} {
            set n 3
        } elseif {($c & 0xFC) == 0xF8} {
            set n 4
        } elseif {($c & 0xFE) == 0xFC} {
            set n 5
        } else {
            return false
        }
        for {set j 0} {$j<$n} {incr j} {
            incr i
            if {$i == $len} {
                return false
            } elseif {([scan [string index $str $i] %c] & 0xC0) != 0x80} {
                return false
            }
        }
    }
    return true
}

# lint_checksum_types
#
# Given a list of checksum types, return a list of strings which are warnings
# about deprecated checksum types, or missing recommended types.
#
# Returns an empty list if no issues are found.
proc portlint::lint_checksum_type_list {types} {
    set issues [list]
    set using_secure false

    foreach preferred $portchecksum::default_checksum_types {
        if {$preferred ni $types} {
            lappend issues "missing recommended checksum type: $preferred"
        } elseif {$preferred in $portchecksum::secure_checksum_types} {
            set using_secure true
        }
    }

    if {!$using_secure} {
        foreach type $types {
            if {$type ni $portchecksum::default_checksum_types} {
                lappend issues "checksum type is insecure on its own: $type"
            }
        }
    }

    return $issues
}

# lint_checksum
#
# Checks a given Portfile checksum string.  Returns a list of lists.
# The first member list is a list of error strings.
# The second member list is a list of warning strings.
#
# Returns a list containing two empty lists if no issues are found.
proc portlint::lint_checksum {checksum_string} {
    set errors [list]
    set warnings [list]

    set is_error false
    set ctr_start 0

    set filename ""
    set pfx ""
    set has_filenames false

    set types [list]

    # List of all tokens in the checksum string
    set checksum_tokens [regexp -all -inline {\S+} $checksum_string]

    if {[lindex $checksum_tokens 0] eq "checksum"} {
        incr ctr_start
    }

    for {set ctr $ctr_start} \
        {($ctr < [llength $checksum_tokens]) && !$is_error} \
        {} {

        set current [lindex $checksum_tokens $ctr]

        if {$current in $portchecksum::checksum_types} {
            set c_type  $current
            set c_value [lindex $checksum_tokens $ctr+1]

            switch [portchecksum::verify_checksum_format $c_type $c_value] {
                1 {
                    # checksum type recognized, and checksum looks good
                    incr ctr 2
                    lappend types $c_type
                }

                0 {
                    # checksum type recognized, but checksum looks bad
                    lappend errors "${pfx}checksum type $c_type, but\
                                    checksum is invalid: $c_value"
                    incr ctr 2
                }

                -1 {
                    # checksum type not recognized
                    lappend errors "${pfx}invalid checksum type: $c_type\
                                    $c_value"
                    set is_error true
                    continue
                }
            }

        } elseif {($ctr > $ctr_start) && !$has_filenames} {
            lappend errors "invalid checksum field: $current"
            set is_error true
            continue
        } else {
            if {$ctr == $ctr_start} {
                set has_filenames true
            } elseif {($ctr == ([llength $checksum_tokens] - 1)) || \
                         ([portchecksum::verify_checksum_format \
                            [lindex $checksum_tokens $ctr-2] \
                            [lindex $checksum_tokens $ctr-1] \
                          ] != 1)} {
                lappend errors "invalid checksum field: $current"
                set is_error true
                continue
            }

            if {[llength $types] > 0} {
                set types_lint [portlint::lint_checksum_type_list $types]
                foreach lint_issue $types_lint {
                    lappend warnings "${pfx}${lint_issue}"
                }
            }

            set filename $current
            set pfx "$filename - "
            set types [list]
            incr ctr
        }
    }

    if {[llength $types] > 0} {
        set types_lint [portlint::lint_checksum_type_list $types]
        foreach lint_issue $types_lint {
            lappend warnings "${pfx}${lint_issue}"
        }
    }

    return [list $errors $warnings]
}

proc portlint::lint_start {args} {
    global UI_PREFIX subport
    ui_notice "$UI_PREFIX [format [msgcat::mc "Verifying Portfile for %s"] ${subport}]"
}

proc portlint::lint_main {args} {
    global UI_PREFIX name portpath porturl ports_lint_nitpick
    set portfile ${portpath}/Portfile
    set portdirs [split ${portpath} /]
    set last [llength $portdirs]
    incr last -1
    set portdir [lindex $portdirs $last]
    incr last -1
    set portcatdir [lindex $portdirs $last]

    set warnings 0
    set errors 0

    ###################################################################
    ui_debug "$portfile"
    
    if {[info exists ports_lint_nitpick] && $ports_lint_nitpick eq "yes"} {
        set nitpick true
    } else {
        set nitpick false
    }

    set topline_number 1
    set require_blank false
    set require_after ""
    set seen_portsystem false
    set seen_portgroup false
    set in_description false
    set prohibit_tabs false

    array set portgroups {}

    set local_variants [list]

    set f [open $portfile RDONLY]
    # read binary (to check UTF-8)
    fconfigure $f -encoding binary
    set lineno 1
    set hashline false
    while {1} {
        set line [gets $f]
        if {[eof $f]} {
            seek $f -1 end
            set last [read $f 1]
            if {"\n" ne $last} {
                ui_warn "Line $lineno has missing newline (at end of file)"
                incr warnings
            }
            close $f
            break
        }
        ui_debug "$lineno: $line"

        if {![seems_utf8 $line]} {
            ui_error "Line $lineno seems to contain an invalid UTF-8 sequence"
            incr errors
        }

        if {($require_after eq "PortSystem" || $require_after eq "PortGroup") && \
            [regexp {^\s*PortGroup\s} $line]} {
            set require_blank false
        }

        if {$nitpick && $require_blank && ($line ne "")} {
            ui_warn "Line $lineno should be a newline (after $require_after)"
            incr warnings
        }
        set require_blank false

        if {$nitpick && [regexp {\S[ \t]+$} $line]} {
            # allow indented blank lines between blocks of code and such
            ui_warn "Line $lineno has trailing whitespace before newline"
            incr warnings
        }

        if {($lineno == $topline_number) && [string match "*-\*- *" $line]} {
            ui_info "OK: Line $lineno has emacs/vim Mode"
            incr topline_number
            set require_blank true
            set require_after "modeline"
            if {[regexp {\sindent-tabs-mode: nil[;\s]|[:\s](?:et|expandtab)(?:[:\s]|$)} $line]} {
                set prohibit_tabs true
            }
        }

        if {$prohibit_tabs && [string match "*\t*" $line]} {
            ui_warn "Line $lineno contains tab but modeline says tabs should be expanded"
            incr warnings
        }

        if {[string match "*\$Id*\$" $line]} {
            ui_warn "Line $lineno is using obsolete RCS tag (\$Id\$)"
            incr warnings
        }
        
        # skip the rest for comment lines (not perfectly accurate...)
        if {[regexp {^\s*#} $line]} {
            incr lineno
            continue
        }

        if {[regexp {^\s*PortSystem\s} $line]} {
            if {$seen_portsystem} {
                ui_error "Line $lineno repeats PortSystem declaration"
                incr errors
            }
            regexp {^\s*PortSystem\s+([0-9.]+)\s*$} $line -> portsystem
            if {![info exists portsystem]} {
                ui_error "Line $lineno has unrecognized PortSystem"
                incr errors
            }
            set seen_portsystem true
            set require_blank true
            set require_after "PortSystem"
        }
        if {[regexp {^\s*PortGroup\s} $line]} {
            regexp {^\s*PortGroup\s+([A-Za-z0-9_]+)\s+([0-9.]+)\s*$} $line -> portgroup portgroupversion
            if {![info exists portgroup]} {
                ui_error "Line $lineno has unrecognized PortGroup"
                incr errors
            } else {
                if {[info exists portgroups($portgroup)]} {
                    ui_error "Line $lineno repeats inclusion of PortGroup $portgroup"
                    incr errors
                } else {
                    set portgroups($portgroup) $portgroupversion
                }
            }
            set seen_portgroup true
            set require_blank true
            set require_after "PortGroup"
        }

        # TODO: check for repeated variable definitions
        # TODO: check the definition order of variables
        # TODO: check length of description against max

        if {[regexp {^\s*long_description\s} $line]} {
            set in_description true
        }
        if {$in_description && ([string range $line end end] ne "\\")} {
            set in_description false
            #set require_blank true
            #set require_after "long_description"
        } elseif {$in_description} {
            set require_blank false
        }

        if {[regexp {^\s*variant\s} $line]} {
            regexp {^\s*variant\s+(\w+)} $line -> variantname
            if {[info exists variantname]} {
                lappend local_variants $variantname
            }
        }
        
        if {[regexp {^\s*platform\s} $line]} {
            regexp {^\s*platform\s+(?:\w+\s+(?:\w+\s+)?)?(\w+)} $line -> platform_arch
            foreach {bad_platform_arch replacement_platform_arch} {
                arm64 arm
                intel i386
                ppc powerpc
                ppc64 powerpc
                x86_64 i386
            } {
                if {$platform_arch eq $bad_platform_arch} {
                    ui_error "Arch '$bad_platform_arch' in platform on line $lineno should be '$replacement_platform_arch'"
                    incr errors
                }
            }
        }

        if {[regexp {^\s*adduser\s} $line]} {
            ui_warn "Line $lineno calling adduser directly; consider setting add_users instead"
            incr warnings
        }

        if {[regexp {^\s*configure\s+\{\s*\}} $line]} {
            ui_warn "Line $lineno should say \"use_configure no\" instead of declaring an empty configure phase"
            incr warnings
        }

        if {[regexp {^\s*compiler\.blacklist(?:-[a-z]+)?\s.*(["{]\S+(?:\s+\S+){2,}["}])} $line -> blacklist] && ![info exists portgroups(compiler_blacklist_versions)]} {
            ui_error "Line $lineno uses compiler.blacklist entry $blacklist which requires the compiler_blacklist_versions portgroup which has not been included"
            incr errors
        }

        if {[regexp {(^.*)(\meval\s+)(.*)(\[glob\M)(.*$)} $line -> match_before match_eval match_between match_glob match_after]} {
            ui_warn "Line $lineno should use the expansion operator instead of the eval procedure. Change"
            ui_warn "$line"
            ui_warn "to"
            ui_warn "$match_before$match_between{*}$match_glob$match_after"
            incr warnings
        }

        # Check for hardcoded version numbers
        if {$nitpick} {
            # Support for skipping checksums lines
            if {[regexp {^\s*checksums\s} $line]} {
                # We enter a series of one or more lines containing checksums
                set hashline true
            }
    
            if {!$hashline
                    && ![regexp {^\s*(?:PortSystem|PortGroup|version|license|[A-Za-z0-9_]+\.setup)\s} $line]
                    && [string first [option version] $line] != -1} {
                ui_warn "Line $lineno seems to hardcode the version number, consider using \${version} instead"
                incr warnings
            }
    
            if {$hashline &&
                ![string match \\\\ [string index $line end]]} {
                    # if the last character is not a backslash we're done with
                    # line skipping
                    set hashline false
            }
        }

        # Check for hardcoded paths
        if {!$hashline
                && $name ne "MacPorts"
                && [string match "*/opt/local*" $line]
                && ![regexp {^\s*(?:reinplace\s|system.*\Wsed\W)} $line]} {
            ui_error "Line $lineno hardcodes /opt/local, use \${prefix} instead"
            incr errors
        }

        if {[regexp {\$\{?macosx_version} $line]} {
            ui_warn "Line $lineno using macosx_version; switch to macos_version or macos_version_major"
            incr warnings
        }

        ### TODO: more checks to Portfile syntax

        incr lineno
    }

    ###################################################################

    global os.platform os.arch os.version version revision epoch \
           description long_description platforms categories all_variants \
           maintainers license homepage master_sites checksums patchfiles \
           depends_fetch depends_extract depends_patch \
           depends_lib depends_build depends_run \
           depends_test distfiles fetch.type lint_portsystem lint_platforms \
           lint_required lint_optional replaced_by conflicts
    set portarch [get_canonical_archs]

    if {!$seen_portsystem} {
        ui_error "Didn't find PortSystem specification"
        incr errors
    }  elseif {$portsystem ne $lint_portsystem} {
        ui_error "Unknown PortSystem: $portsystem"
        incr errors
    } else {
        ui_info "OK: Found PortSystem $portsystem"
    }

    if {$seen_portgroup} {
        # Using a PortGroup is optional
        foreach {portgroup portgroupversion} [array get portgroups] {
            if {![file exists [getportresourcepath $porturl "port1.0/group/${portgroup}-${portgroupversion}.tcl"]]} {
                ui_error "Unknown PortGroup: $portgroup-$portgroupversion"
                incr errors
            } else {
                ui_info "OK: Found PortGroup $portgroup-$portgroupversion"
            }
        }
    }

    foreach req_var $lint_required {

        if {$req_var eq "master_sites"} {
            if {${fetch.type} ne "standard"} {
                ui_info "OK: $req_var not required for fetch.type ${fetch.type}"
                continue
            }
            if {[llength ${distfiles}] == 0} {
                ui_info "OK: $req_var not required when there are no distfiles"
                continue
            }
        }

        if {![info exists $req_var]} {
            ui_error "Missing required variable: $req_var"
            incr errors
        } else {
            ui_info "OK: Found required variable: $req_var"
        }
    }

    foreach opt_var $lint_optional {
        if {[info exists $opt_var]} {
            # TODO: check whether it was seen (or default)
            ui_info "OK: Found optional variable: $opt_var"
        }
    }
    
    if {[info exists name]} {
        if {[regexp {[^[:alnum:]_.-]} $name]} {
            ui_error "Port name '$name' contains unsafe characters. Names should only contain alphanumeric characters, underscores, dashes or dots."
            incr errors
        }
    }

    if {[info exists platforms]} {
        foreach platform $platforms {
            if {$platform ni $lint_platforms} {
                ui_error "Unknown platform: $platform"
                incr errors
            } else {
                ui_info "OK: Found platform: $platform"
            }
        }
    }

    if {[info exists categories]} {
        if {[llength $categories] > 0} {
            set category [lindex $categories 0]
            ui_info "OK: Found primary category: $category"
        } else {
            ui_error "Categories list is empty"
            incr errors
        }
    }

    set variantnumber 1
    foreach variant $all_variants {
        set variantname [ditem_key $variant name] 
        set variantdesc [lindex [ditem_key $variant description] 0]
        if {![info exists variantname] || $variantname eq ""} {
            ui_error "Variant number $variantnumber does not have a name"
            incr errors
        } else {
            set name_ok true
            set desc_ok true

            if {![regexp {^[A-Za-z0-9_.]+$} $variantname]} {
                ui_error "Variant name $variantname is not valid; use \[A-Za-z0-9_.\]+ only"
                incr errors
                set name_ok false
            }

            if {![info exists variantdesc] || $variantdesc eq ""} {
                # don't warn about missing descriptions for global variants
                if {$variantname in $local_variants &&
                    [variant_desc $porturl $variantname] eq ""} {
                    ui_warn "Variant $variantname does not have a description"
                    incr warnings
                    set desc_ok false
                } elseif {$variantdesc eq ""} {
                    set variantdesc "(pre-defined variant)"
                }
            } else {
                if {[variant_desc $porturl $variantname] ne ""} {
                    ui_warn "Variant $variantname overrides global description"
                    incr warnings
                }
            }

            # Check if conflicting variants actually exist
            foreach vconflict [ditem_key $variant conflicts] {
                set exists 0
                foreach v $all_variants {
                    if {$vconflict eq [ditem_key $v name]} {
                        set exists 1
                        break
                    }
                }
                if {!$exists} {
                    ui_warn "Variant $variantname conflicts with non-existing variant $vconflict"
                    incr warnings
                }
            }

            if {$name_ok} {
                if {$desc_ok} {
                    ui_info "OK: Found variant $variantname: $variantdesc"
                } else {
                    ui_info "OK: Found variant: $variantname"
                }
            }
        }
        incr variantnumber
    }

    set all_depends {}
    if {[info exists depends_fetch]} {
        lappend all_depends {*}$depends_fetch
    }
    if {[info exists depends_extract]} {
        lappend all_depends {*}$depends_extract
    }
    if {[info exists depends_patch]} {
        lappend all_depends {*}$depends_patch
    }
    if {[info exists depends_lib]} {
        lappend all_depends {*}$depends_lib
    }
    if {[info exists depends_build]} {
        lappend all_depends {*}$depends_build
    }
    if {[info exists depends_run]} {
        lappend all_depends {*}$depends_run
    }
    if {[info exists depends_test]} {
        lappend all_depends {*}$depends_test
    }
    foreach depspec $all_depends {
        set dep [lindex [split $depspec :] end]
        if {[catch {set res [mport_lookup $dep]} error]} {
            ui_debug $::errorInfo
            continue
        }
        if {$res eq ""} {
            ui_error "Unknown dependency: $dep"
            incr errors
        } else {
            ui_info "OK: Found dependency: $dep"
        }
    }

    # Check for multiple dependencies
    foreach deptype {depends_extract depends_patch depends_lib depends_build depends_run depends_test} {
        if {[info exists $deptype]} {
            array set depwarned {}
            foreach depspec [set $deptype] {
                if {![info exists depwarned($depspec)]
                        && [llength [lsearch -exact -all [set $deptype] $depspec]] > 1} {
                    ui_warn "Dependency $depspec specified multiple times in $deptype"
                    incr warnings
                    # Report each depspec only once
                    set depwarned($depspec) yes
                }
            }
        }
    }

    if {[info exists replaced_by]} {
        if {[regexp {[^[:alnum:]_.-]} $replaced_by]} {
            ui_error "replaced_by should be a single port name, invalid value: $replaced_by"
            incr errors
        } else {
            if {[catch {set res [mport_lookup $replaced_by]} error]} {
                ui_debug $::errorInfo
            }
            if {$res eq ""} {
                ui_error "replaced_by references unknown port: $replaced_by"
                incr errors
            } else {
                ui_info "OK: replaced_by $replaced_by"
            }
        }
    }

    if {[info exists checksums]} {
        set checksum_lint [portlint::lint_checksum $checksums]

        foreach err [lindex $checksum_lint 0] {
            ui_error $err
            incr errors
        }

        foreach warning [lindex $checksum_lint 1] {
            ui_warn $warning
            incr warnings
        }
    }

    if {[info exists conflicts]} {
        foreach cport $conflicts {
            if {[regexp {[^[:alnum:]_.-]} $cport]} {
                ui_error "conflicts lists invalid value, should be port name: $cport"
                incr errors
                continue
            }
            if {[catch {set res [mport_lookup $cport]} error]} {
                ui_debug $::errorInfo
                continue
            }
            if {$res eq ""} {
                ui_error "conflicts references unknown port: $cport"
                incr errors
            } else {
                ui_info "OK: conflicts $cport"
            }
        }
    }

    if {[regexp "^(.+)nomaintainer(@macports\.org)?(.+)$" $maintainers] } {
        ui_error "Using nomaintainer together with other maintainer"
        incr errors
    }

    if {[regexp "^openmaintainer(@macports\.org)?$" $maintainers] } {
        ui_error "Using openmaintainer without any other maintainer"
        incr errors
    }

    foreach maintainer $maintainers {
        foreach addr $maintainer {
            if {$addr eq "nomaintainer@macports.org" ||
                    $addr eq "openmaintainer@macports.org"} {
                ui_warn "Using full email address for no/open maintainer"
                incr warnings
            } elseif {[regexp "^(.+)@macports\.org$" $addr -> localpart]} {
                ui_warn "Maintainer email address for $localpart includes @macports.org"
                incr warnings
            } elseif {$addr eq "darwinports@opendarwin\.org"} {
                ui_warn "Using legacy email address for no/open maintainer"
                incr warnings
            } elseif {[regexp "^(.+)@(.+)$" $addr -> localpart domain]} {
                ui_warn "Maintainer email address should be obfuscated as $domain:$localpart"
                incr warnings
            }
        }
    }

    if {$license eq "unknown"} {
        ui_warn "no license set"
        incr warnings
    } else {

        # If maintainer set license, it must follow correct format

        set prev ''
        foreach test [split [string map { \{ '' \} ''} $license] '\ '] {
            ui_debug "Checking format of license '${test}'"

            # space instead of hyphen
            if {[string is double -strict $test]} {
                ui_error "Invalid license '${prev} ${test}': missing hyphen between ${prev} ${test}"
                incr errors

            # missing hyphen
            } elseif {![string equal -nocase "X11" $test]} {
                foreach subtest [split $test '-'] {
                    ui_debug "testing ${subtest}"

                    # license names start with letters: versions and empty strings need not apply
                    if {[string is alpha -strict [string index $subtest 0]]} {

                        # if the last character of license name is a number or plus sign
                        # then a hyphen is missing
                        set license_end [string index $subtest end]
                        if {"+" eq $license_end || [string is digit -strict $license_end]} {
                            ui_error "invalid license '${test}': missing hyphen before version"
                            incr errors
                        }
                    }
                }
            }

            if {[string equal -nocase "BSD-2" $test]} {
                # BSD-2 => BSD
                ui_error "Invalid license '${test}': use BSD instead"
                incr errors
            } elseif {[string equal -nocase "BSD-3" $test]} {
                # BSD-3 => BSD
                ui_error "Invalid license '${test}': use BSD instead"
                incr errors
            } elseif {[string equal -nocase "BSD-4" $test]} {
                # BSD-4 => BSD-old
                ui_error "Invalid license '${test}': use BSD-old instead"
                incr errors
            }

            set prev $test
        }

    }

    # these checks are only valid for ports stored in the regular tree directories
    if {[info exists category] && $portcatdir ne $category} {
        ui_error "Portfile parent directory $portcatdir does not match primary category $category"
        incr errors
    } else {
        ui_info "OK: Portfile parent directory matches primary category"
    }
    if {$portdir ne $name} {
        ui_error "Portfile directory $portdir does not match port name $name"
        incr errors
    } else {
        ui_info "OK: Portfile directory matches port name"
    }

    if {$nitpick && [info exists patchfiles]} {
        foreach patchfile $patchfiles {
            if {!([string match "*.diff" $patchfile] ||
                  [string match "*.patch" $patchfile]) &&
                 [file exists "$portpath/files/$patchfile"]} {
                ui_warn "Patchfile $patchfile does not follow the source patch naming policy \"*.diff\" or \"*.patch\""
                incr warnings
            }
        }
    }

    # Check for use of deprecated options
    set deprecated_options_name [get_deprecated_options]
    global $deprecated_options_name
    foreach option [array names $deprecated_options_name] {
        set newoption [lindex [set ${deprecated_options_name}($option)] 0]
        set refcount  [lindex [set ${deprecated_options_name}($option)] 1]

        if {$refcount > 0} {
            if {$newoption ne ""} {
                ui_warn "Using deprecated option '$option', superseded by '$newoption'"
            } else {
                ui_warn "Using deprecated option '$option'"
            }
            incr warnings
        }
    }

    ### TODO: more checks to Tcl variables/sections

    ui_debug "Name: $name"
    ui_debug "Epoch: $epoch"
    ui_debug "Version: $version"
    ui_debug "Revision: $revision"
    ui_debug "Archs: $portarch"

    ###################################################################

    ui_notice "$UI_PREFIX [format [msgcat::mc "%d errors and %d warnings found."] $errors $warnings]"

    return {$errors > 0}
}
