# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# portpostdestroot.tcl

package provide portpostdestroot 1.0
package require portutil 1.0

set org.macports.postdestroot [target_new org.macports.postdestroot portpostdestroot::postdestroot_main]
target_provides ${org.macports.postdestroot} postdestroot
target_requires ${org.macports.postdestroot} main destroot
target_prerun ${org.macports.postdestroot} portpostdestroot::postdestroot_start

namespace eval portpostdestroot {
}

#options
options destroot.violate_mtree destroot.asroot

#defaults
default destroot.violate_mtree no

set_ui_prefix


# Starting procedure from postdestroot phase. Check for permissions.
proc portpostdestroot::postdestroot_start {args} {
    if { [getuid] == 0 && [geteuid] != 0 } {
        # if started with sudo but have dropped the privileges
        ui_debug "Can't run destroot under sudo without elevated privileges (due to mtree)."
        ui_debug "Run destroot without sudo to avoid root privileges."
        ui_debug "Going to escalate privileges back to root."
        setegid $egid
        seteuid $euid
        ui_debug "euid changed to: [geteuid]. egid changed to: [getegid]."
    }
}

# List all links on a directory recursively. This function is for internal use.
proc portpostdestroot::links_list {dir} {
    set ret {}
    foreach item [glob -nocomplain -type {d l} -directory $dir *] {
        if {[file isdirectory $item]} {
            set ret [concat $ret [links_list $item]]
        } else {
            #is link
            lappend ret $item
        }
    }
    return $ret
}

# Check for erros on port symlinks
proc portpostdestroot::postdestroot_symlink_check {} {
    global UI_PREFIX destroot prefix
    ui_notice "$UI_PREFIX Checking for links"
    foreach link [links_list $destroot] {
        set points_to [file link $link]
        if { [string compare [file pathtype $points_to] {absolute}] == 0 } {
            if {[regexp $destroot $points_to]} {
                ui_debug "Absolute link path poiting to inside of destroot"
                return -code error "Absolute link path poiting to inside of destroot"
            } else {
                ui_debug "Absolute link path poiting to outside of destroot"
            }
        } elseif { [string compare [file pathtype $points_to] {relative}] == 0 } {
            regsub $destroot$prefix/ $link "" link_without_destroot
            set dir_depth [regexp -all / $link_without_destroot]
            set return_depth [regsub -all {\.\./} $points_to "" points_to_without_returns]
            set return_delta [expr $return_depth - [regexp -all / $points_to_without_returns]]
            if { $return_delta < $dir_depth } {
                ui_debug "Relative link path poiting to inside of destroot"
            } else {
                ui_debug "Relative link path poiting to outside of destroot"
                return -code error "Relative link path poiting to outside of destroot"
            }
        }
    }
}

# Check for erros that violates the macports directory tree.
proc portpostdestroot::postdestroot_mtree_check {} {

    global destroot prefix portsharepath destroot.violate_mtree
    global os.platform applications_dir frameworks_dir
    global UI_PREFIX

    set mtree [findBinary mtree ${portutil::autoconf::mtree_path}]

    # test for violations of mtree
    if { ${destroot.violate_mtree} != "yes" } {
        ui_notice "$UI_PREFIX Executing mtree check"
        ui_debug "checking for mtree violations"
        set mtree_violation "no"

        set prefixPaths [list bin etc include lib libexec sbin share src var www Applications Developer Library]

        set pathsToCheck [list /]
        while {[llength $pathsToCheck] > 0} {
            set pathToCheck [lshift pathsToCheck]
            foreach file [glob -nocomplain -directory $destroot$pathToCheck .* *] {
                if {[file tail $file] eq "." || [file tail $file] eq ".."} {
                    continue
                }
                if {[string equal -length [string length $destroot] $destroot $file]} {
                    # just double-checking that $destroot is a prefix, as is appropriate
                    set dfile [file join / [string range $file [string length $destroot] end]]
                } else {
                    throw MACPORTS "Unexpected filepath `${file}' while checking for mtree violations"
                }
                if {$dfile eq $prefix} {
                    # we've found our prefix
                    foreach pfile [glob -nocomplain -tails -directory $file .* *] {
                        if {$pfile eq "." || $pfile eq ".."} {
                            continue
                        }
                        if {[lsearch -exact $prefixPaths $pfile] == -1} {
                            ui_warn "violation by [file join $dfile $pfile]"
                            set mtree_violation "yes"
                        }
                    }
                } elseif {[string equal -length [expr [string length $dfile] + 1] $dfile/ $prefix]} {
                    # we've found a subpath of our prefix
                    lpush pathsToCheck $dfile
                } else {
                    set dir_allowed no
                    # these files are (at least potentially) outside of the prefix
                    foreach dir "$applications_dir $frameworks_dir /Library/LaunchAgents /Library/LaunchDaemons /Library/StartupItems" {
                        if {[string equal -length [expr [string length $dfile] + 1] $dfile/ $dir]} {
                            # it's a prefix of one of the allowed paths
                            set dir_allowed yes
                            break
                        }
                    }
                    if {$dir_allowed} {
                        lpush pathsToCheck $dfile
                    } else {
                        # not a prefix of an allowed path, so it's either the path itself or a violation
                        switch -- $dfile \
                            $applications_dir - \
                            $frameworks_dir - \
                            /Library/LaunchAgents - \
                            /Library/LaunchDaemons - \
                            /Library/StartupItems { ui_debug "port installs files in $dfile" } \
                            default {
                                ui_warn "violation by $dfile"
                                set mtree_violation "yes"
                            }
                    }
                }
            }
        }

        # abort here only so all violations can be observed
        if { ${mtree_violation} != "no" } {
            ui_warn "[format [msgcat::mc "%s violates the layout of the ports-filesystems!"] [option subport]]"
            ui_warn "Please fix or indicate this misbehavior (if it is intended), it will be an error in future releases!"
            # error "mtree violation!"
        }
    } else {
        ui_warn "[format [msgcat::mc "%s installs files outside the common directory structure."] [option subport]]"
    }
}

proc portpostdestroot::postdestroot_main {args} {
    global UI_PREFIX
    ui_notice "$UI_PREFIX Executing post-destroot phase"

    postdestroot_symlink_check
    postdestroot_mtree_check
    return 0
}
