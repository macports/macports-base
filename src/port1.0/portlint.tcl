# et:ts=4
# portlint.tcl
# $Id: portlint.tcl $

package provide portlint 1.0
package require portutil 1.0

set org.macports.lint [target_new org.macports.lint lint_main]
target_runtype ${org.macports.lint} always
target_state ${org.macports.lint} no
target_provides ${org.macports.lint} lint
target_requires ${org.macports.lint} main
target_prerun ${org.macports.lint} lint_start

set_ui_prefix

set lint_portsystem \
	"1.0"

set lint_platforms [list \
	"macosx" \
	"darwin" \
	"freebsd" \
	"openbsd" \
	"netbsd" \
	"linux" \
	"sunos" \
	]

set lint_categories [list \
	"aqua" \
	"archivers" \
	"audio" \
	"benchmarks" \
	"cad" \
	"comms" \
	"cross" \
	"databases" \
	"devel" \
	"editors" \
	"emulators" \
	"fuse" \
	"games" \
	"genealogy" \
	"gnome" \
	"gnustep" \
	"graphics" \
	"iphone" \
	"irc" \
	"java" \
	"kde" \
	"lang" \
	"mail" \
	"math" \
	"multimedia" \
	"net" \
	"news" \
	"palm" \
	"perl" \
	"print" \
	"python" \
	"ruby" \
	"science" \
	"security" \
	"shells" \
	"sysutils" \
	"tex" \
	"textproc" \
	"www" \
	"x11" \
	"xfce" \
	"zope" \
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

set lint_variants [list \
	"universal" \
	"docs" \
	"aqua" \
	"x11" \
	]


proc seems_utf8 {str} {
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


proc lint_start {args} {
    global UI_PREFIX portname
    ui_msg "$UI_PREFIX [format [msgcat::mc "Verifying Portfile for %s"] ${portname}]"
}

proc lint_main {args} {
	global UI_PREFIX portname portpath portresourcepath
	set portfile ${portpath}/Portfile
	set portdirs [split ${portpath} /]
	set last [llength $portdirs]
	incr last -1
	set portdir [lindex $portdirs $last]
	incr last -1
	set portcatdir [lindex $portdirs $last]
	set groupdir ${portresourcepath}/group

	set warnings 0
	set errors 0

    ###################################################################
    ui_debug "$portfile"

    set topline_number 1
    set require_blank false
    set require_after ""
    set seen_portsystem false
    set seen_portgroup false
    set in_description false

    set local_variants [list]

    set f [open $portfile RDONLY]
    # read binary (to check UTF-8)
    fconfigure $f -encoding binary
    set lineno 1
    while {1} {
        set line [gets $f]
        if {[eof $f]} {
            seek $f -1 end
            set last [read $f 1]
            if {![string match "\n" $last]} {
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

        if {[string equal "PortSystem" $require_after] && \
            [string match "PortGroup*" $line]} {
            set require_blank false
        }

        if {$require_blank && ($line != "")} {
            ui_warn "Line $lineno should be a newline (after $require_after)"
            incr warnings
        }
        set require_blank false

        if {[regexp {\S[ \t]+$} $line]} {
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

        if {[string match "PortSystem*" $line]} {
            if {$seen_portsystem} {
                 ui_error "Line $lineno repeats PortSystem information"
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
            if {$seen_portgroup} {
                 ui_error "Line $lineno repeats PortGroup information"
                 incr errors
            }
            regexp {PortGroup\s+([a-z0-9]+)\s+([0-9.]+)} $line -> portgroup portgroupversion
            if {![info exists portgroup]} {
                 ui_error "Line $lineno has unrecognized PortGroup"
                 incr errors
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

        ### TODO: more checks to Portfile syntax

        incr lineno
    }

    ###################################################################

    global os.platform os.arch os.version
    global portversion portrevision portepoch
    # hoping for "noarch" :
    set portarch ${os.arch}
    global description long_description platforms categories all_variants
    global maintainers homepage master_sites checksums patchfiles
    global depends_lib depends_build depends_run fetch.type
    
    global lint_portsystem lint_platforms lint_categories 
    global lint_required lint_optional lint_variants

    if (!$seen_portsystem) {
        ui_error "Didn't find PortSystem specification"
        incr errors
    }  elseif {$portsystem != $lint_portsystem} {
        ui_error "Unknown PortSystem: $portsystem"
        incr errors
    } else {
        ui_info "OK: Found PortSystem $portsystem"
    }
    if (!$seen_portgroup) {
        # PortGroup is optional, so missing is OK
    }  elseif {![file exists $groupdir/$portgroup-$portgroupversion.tcl]} {
        ui_error "Unknown PortGroup: $portgroup-$portgroupversion"
        incr errors
    } else {
        ui_info "OK: Found PortGroup $portgroup-$portgroupversion"
    }

    foreach req_var $lint_required {
        if {$req_var == "name"} {
            set var "portname"
        } elseif {$req_var == "version"} {
            set var "portversion"
        } else {
            set var $req_var
        }

       if {$var == "master_sites" && ${fetch.type} != "standard"} {
             ui_info "OK: $var not required for fetch.type ${fetch.type}"
             continue
       }
       
       if {![info exists $var]} {
            ui_error "Missing required variable: $req_var"
            incr errors
        } else {
            ui_info "OK: Found required variable: $req_var"
        }
    }

    foreach opt_var $lint_optional {
       if {$opt_var == "epoch"} {
            set var "portepoch"
        } elseif {$opt_var == "revision"} {
            set var "portrevision"
        } else {
            set var $opt_var
       }
       if {[info exists $var]} {
            # TODO: check whether it was seen (or default)
            ui_info "OK: Found optional variable: $opt_var"
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
        set category [lindex $categories 0]
        if {[lsearch -exact $lint_categories $category] == -1} {
            ui_error "Unknown category: $category"
            incr errors
        } else {
            ui_info "OK: Found category: $category"
        }
        foreach secondary $categories {
            if {[string match $secondary $category]} {
                continue
            }
            ui_info "OK: Found category: $secondary"
        }
    }

    if {![string is integer -strict $portepoch]} {
        ui_error "Port epoch is not numeric:  $portepoch"
        incr errors
    }
    if {![string is integer -strict $portrevision]} {
        ui_error "Port revision is not numeric: $portrevision"
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
                    [lsearch -exact $lint_variants $variantname] == -1} {
                    ui_warn "Variant $variantname does not have a description"
                    incr warnings
                    set desc_ok false
                } elseif {$variantdesc == ""} {
                    set variantdesc "(pre-defined variant)"
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
    if {[info exists depends_lib]} { eval "lappend all_depends $depends_lib" }
    if {[info exists depends_build]} { eval "lappend all_depends $depends_build" }
    if {[info exists depends_run]} { eval "lappend all_depends $depends_run" }
    foreach depspec $all_depends {
        set dep [lindex [split $depspec :] end]
        if {[catch {set res [mport_search "^$dep\$"]} error]} {
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

    if {[regexp "^(.+)nomaintainer(@macports.org)?(.+)$" $maintainers] } {
        ui_error "Using nomaintainer together with other maintainer"
        incr errors
    }

    if {[regexp "^openmaintainer(@macports.org)?$" $maintainers] } {
        ui_error "Using openmaintainer without any other maintainer"
        incr errors
    }

    if {[string match "*darwinports@opendarwin.org*" $maintainers]} {
        ui_warn "Using legacy email address for no/open maintainer"
        incr warnings
    }

    if {[string match "*nomaintainer@macports.org*" $maintainers] ||
        [string match "*openmaintainer@macports.org*" $maintainers]} {
        ui_warn "Using full email address for no/open maintainer"
        incr warnings
    }

    # these checks are only valid for ports stored in the regular tree directories
    if {$portcatdir != $category} {
        ui_error "Portfile parent directory $portcatdir does not match primary category $category"
        incr errors
    } else {
        ui_info "OK: Portfile parent directory matches primary category"
    }
    if {$portdir != $portname} {
        ui_error "Portfile directory $portdir does not match port name $portname"
        incr errors
    } else {
        ui_info "OK: Portfile directory matches port name"
    }

    if {[info exists patchfiles]} {
        foreach patchfile $patchfiles {
            if {![string match "patch-*.diff" $patchfile] && [file exists "$portpath/files/$patchfile"]} {
                ui_warn "Patchfile $patchfile does not follow the source patch naming policy \"patch-*.diff\""
                incr warnings
            }
        }
    }

    ### TODO: more checks to Tcl variables/sections

    ui_debug "Name: $portname"
    ui_debug "Epoch: $portepoch"
    ui_debug "Version: $portversion"
    ui_debug "Revision: $portrevision"
    ui_debug "Arch: $portarch"
    ###################################################################

	ui_msg "$UI_PREFIX [format [msgcat::mc "%d errors and %d warnings found."] $errors $warnings]"

	return {$errors > 0}
}
