# et:ts=4
# portlint.tcl
# $Id$

package provide portlint 1.0
package require portutil 1.0

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
            if {$nitpick} {
                seek $f -1 end
                set last [read $f 1]
                if {![string match "\n" $last]} {
                    ui_warn "Line $lineno has missing newline (at end of file)"
                    incr warnings
                }
            }
            close $f
            break
        }
        ui_debug "$lineno: $line"

        if {![seems_utf8 $line]} {
            ui_error "Line $lineno seems to contain an invalid UTF-8 sequence"
            incr errors
        }

        if {($require_after == "PortSystem" || $require_after == "PortGroup") && \
            [string match "PortGroup*" $line]} {
            set require_blank false
        }

        if {$nitpick && $require_blank && ($line != "")} {
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
        }
        if {($lineno == $topline_number) && ![string match "*\$Id*\$" $line]} {
            ui_warn "Line $lineno is missing RCS tag (\$Id\$)"
            incr warnings
        } elseif {($lineno == $topline_number)} {
            ui_info "OK: Line $lineno has RCS tag (\$Id\$)"
            set require_blank true
            set require_after "RCS tag"
        }
        
        # skip the rest for comment lines (not perfectly accurate...)
        if {[regexp {^\s*#} $line]} {
            incr lineno
            continue
        }

        if {[string match "PortSystem*" $line]} {
            if {$seen_portsystem} {
                ui_error "Line $lineno repeats PortSystem declaration"
                incr errors
            }
            regexp {PortSystem\s+([0-9.]+)} $line -> portsystem
            if {![info exists portsystem]} {
                ui_error "Line $lineno has unrecognized PortSystem"
                incr errors
            }
            set seen_portsystem true
            set require_blank true
            set require_after "PortSystem"
        }
        if {[string match "PortGroup*" $line]} {
            regexp {PortGroup\s+([a-z0-9_]+)\s+([0-9.]+)} $line -> portgroup portgroupversion
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

        if {[string match "long_description*" $line]} {
            set in_description true
        }
        if {$in_description && ([string range $line end end] != "\\")} {
            set in_description false
            #set require_blank true
            #set require_after "long_description"
        } elseif {$in_description} {
            set require_blank false
        }

        if {[string match "variant*" $line]} {
            regexp {variant\s+(\w+)} $line -> variantname
            if {[info exists variantname]} {
                lappend local_variants $variantname
            }
        }
        
        if {[string match "platform\[ \t\]*" $line]} {
            regexp {platform\s+(?:\w+\s+(?:\w+\s+)?)?(\w+)} $line -> platform_arch
            if {$platform_arch == "ppc"} {
                ui_error "Arch 'ppc' in platform on line $lineno should be 'powerpc'"
                incr errors
            }
        }

        if {[string match "*adduser*" $line]} {
            ui_warn "Line $lineno calling adduser directly; consider setting add_users instead"
            incr warnings
        }

        if {[regexp {(^|\s)configure\s+\{\s*\}} $line]} {
            ui_warn "Line $lineno should say \"use_configure no\" instead of declaring an empty configure phase"
            incr warnings
        }

        # Check for hardcoded version numbers
        if {$nitpick} {
            # Support for skipping checksums lines
            if {[regexp {^checksums} $line]} {
                # We enter a series of one or more lines containing checksums
                set hashline true
            }
    
            if {!$hashline
                    && ![regexp {^\s*PortSystem|^\s*PortGroup|^\s*version} $line]
                    && ![regexp {^\s*[a-z0-9]+\.setup} $line]
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
            
        ### TODO: more checks to Portfile syntax

        incr lineno
    }

    ###################################################################

    global os.platform os.arch os.version version revision epoch \
           description long_description platforms categories all_variants \
           maintainers license homepage master_sites checksums patchfiles \
           depends_fetch depends_extract depends_lib depends_build \
           depends_run distfiles fetch.type lint_portsystem lint_platforms \
           lint_required lint_optional
    set portarch [get_canonical_archs]

    if (!$seen_portsystem) {
        ui_error "Didn't find PortSystem specification"
        incr errors
    }  elseif {$portsystem != $lint_portsystem} {
        ui_error "Unknown PortSystem: $portsystem"
        incr errors
    } else {
        ui_info "OK: Found PortSystem $portsystem"
    }

    if ($seen_portgroup) {
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

        if {$req_var == "master_sites"} {
            if {${fetch.type} != "standard"} {
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
            if {[lsearch -exact $lint_platforms $platform] == -1} {
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

    if {![string is integer -strict $epoch]} {
        ui_error "Port epoch is not numeric:  $epoch"
        incr errors
    }
    if {![string is integer -strict $revision]} {
        ui_error "Port revision is not numeric: $revision"
        incr errors
    }

    set variantnumber 1
    foreach variant $all_variants {
        set variantname [ditem_key $variant name] 
        set variantdesc [lindex [ditem_key $variant description] 0]
        if {![info exists variantname] || $variantname == ""} {
            ui_error "Variant number $variantnumber does not have a name"
            incr errors
        } else {
            set name_ok true
            set desc_ok true

            if {![regexp {^[A-Za-z0-9_]+$} $variantname]} {
                ui_error "Variant name $variantname is not valid; use \[A-Za-z0-9_\]+ only"
                incr errors
                set name_ok false
            }

            if {![info exists variantdesc] || $variantdesc == ""} {
                # don't warn about missing descriptions for global variants
                if {[lsearch -exact $local_variants $variantname] != -1 &&
                    [variant_desc $porturl $variantname] == ""} {
                    ui_warn "Variant $variantname does not have a description"
                    incr warnings
                    set desc_ok false
                } elseif {$variantdesc == ""} {
                    set variantdesc "(pre-defined variant)"
                }
            } else {
                if {[variant_desc $porturl $variantname] != ""} {
                    ui_warn "Variant $variantname overrides global description"
                    incr warnings
                }
            }

            # Check if conflicting variants actually exist
            foreach vconflict [ditem_key $variant conflicts] {
                set exists 0
                foreach v $all_variants {
                    if {$vconflict == [ditem_key $v name]} {
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
    if {[info exists depends_fetch]} { eval "lappend all_depends $depends_fetch" }
    if {[info exists depends_extract]} { eval "lappend all_depends $depends_extract" }
    if {[info exists depends_lib]} { eval "lappend all_depends $depends_lib" }
    if {[info exists depends_build]} { eval "lappend all_depends $depends_build" }
    if {[info exists depends_run]} { eval "lappend all_depends $depends_run" }
    foreach depspec $all_depends {
        set dep [lindex [split $depspec :] end]
        if {[catch {set res [mport_lookup $dep]} error]} {
            global errorInfo
            ui_debug "$errorInfo"
            continue
        }
        if {$res == ""} {
            ui_error "Unknown dependency: $dep"
            incr errors
        } else {
            ui_info "OK: Found dependency: $dep"
        }
    }

    # Check for multiple dependencies
    foreach deptype {depends_extract depends_lib depends_build depends_run} {
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

    if {[regexp "^(.+)nomaintainer(@macports.org)?(.+)$" $maintainers] } {
        ui_error "Using nomaintainer together with other maintainer"
        incr errors
    }

    if {[regexp "^openmaintainer(@macports.org)?$" $maintainers] } {
        ui_error "Using openmaintainer without any other maintainer"
        incr errors
    }

    foreach addr $maintainers {
        if {$addr == "nomaintainer@macports.org" ||
                $addr == "openmaintainer@macports.org"} {
            ui_warn "Using full email address for no/open maintainer"
            incr warnings
        } elseif [regexp "^(.+)@macports.org$" $addr -> localpart] {
            ui_warn "Maintainer email address for $localpart includes @macports.org"
            incr warnings
        } elseif {$addr == "darwinports@opendarwin.org"} {
            ui_warn "Using legacy email address for no/open maintainer"
            incr warnings
        } elseif [regexp "^(.+)@(.+)$" $addr -> localpart domain] {
            ui_warn "Maintainer email address should be obfuscated as $domain:$localpart"
            incr warnings
        }
    }

    if {$license == "unknown"} {
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

            # missing hyphen
            } elseif {![string equal -nocase "X11" $test]} {
                foreach subtest [split $test '-'] {
                    ui_debug "testing ${subtest}"

                    # license names start with letters: versions and empty strings need not apply
                    if {[string is alpha -strict [string index $subtest 0]]} {

                        # if the last character of license name is a number or plus sign
                        # then a hyphen is missing
                        set license_end [string index $subtest end]
                        if {[string equal "+" $license_end] || [string is integer -strict $license_end]} {
                            ui_error "invalid license '${test}': missing hyphen before version"
                        }
                    }
                }
            }

            if {[string equal -nocase "BSD-2" $test]} {
                # BSD-2 => BSD
                ui_error "Invalid license '${test}': use BSD instead"
            } elseif {[string equal -nocase "BSD-3" $test]} {
                # BSD-3 => BSD
                ui_error "Invalid license '${test}': use BSD instead"
            } elseif {[string equal -nocase "BSD-4" $test]} {
                # BSD-4 => BSD-old
                ui_error "Invalid license '${test}': use BSD-old instead"
            }

            set prev $test
        }

    }

    # these checks are only valid for ports stored in the regular tree directories
    if {[info exists category] && $portcatdir != $category} {
        ui_error "Portfile parent directory $portcatdir does not match primary category $category"
        incr errors
    } else {
        ui_info "OK: Portfile parent directory matches primary category"
    }
    if {$portdir != $name} {
        ui_error "Portfile directory $portdir does not match port name $name"
        incr errors
    } else {
        ui_info "OK: Portfile directory matches port name"
    }

    if {$nitpick && [info exists patchfiles]} {
        foreach patchfile $patchfiles {
            if {![string match "patch-*.diff" $patchfile] && [file exists "$portpath/files/$patchfile"]} {
                ui_warn "Patchfile $patchfile does not follow the source patch naming policy \"patch-*.diff\""
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
            if {$newoption != ""} {
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

    set svn_cmd ""
    catch {set svn_cmd [findBinary svn]}
    if {$svn_cmd != "" && ([file exists $portpath/.svn] || ![catch {exec $svn_cmd info $portpath > /dev/null 2>@1}])} {
        ui_debug "Checking svn properties"
        if [catch {exec $svn_cmd propget svn:keywords $portfile 2>@1} output] {
            ui_warn "Unable to check for svn:keywords property: $output"
        } else {
            ui_debug "Property svn:keywords is \"$output\", should be \"Id\""
            if {$output != "Id"} {
                ui_error "Missing subversion property on Portfile, please execute: svn ps svn:keywords Id Portfile"
                incr errors
            }
        }
        if [catch {exec $svn_cmd propget svn:eol-style $portfile 2>@1} output] {
            ui_warn "Unable to check for svn:eol-style property: $output"
        } else {
            ui_debug "Property svn:eol-style is \"$output\", should be \"native\""
            if {$output != "native"} {
                ui_error "Missing subversion property on Portfile, please execute: svn ps svn:eol-style native Portfile"
                incr errors
            }
        }
    }

    ###################################################################

    ui_notice "$UI_PREFIX [format [msgcat::mc "%d errors and %d warnings found."] $errors $warnings]"

    return {$errors > 0}
}
