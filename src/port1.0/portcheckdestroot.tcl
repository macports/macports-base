# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# portcheckdestroot.tcl

package provide portcheckdestroot 1.0
package require portutil 1.0
package require Pextlib 1.0


set org.macports.checkdestroot [target_new org.macports.checkdestroot portcheckdestroot::checkdestroot_main]
target_provides ${org.macports.checkdestroot} checkdestroot
target_requires ${org.macports.checkdestroot} main destroot
target_prerun ${org.macports.checkdestroot} portcheckdestroot::checkdestroot_start

namespace eval portcheckdestroot {
}
#options
options destroot.violate_mtree destroot.asroot depends_lib

#defaults
default destroot.violate_mtree no
default destroot.depends_lib {}

set_ui_prefix

# Starting procedure from checkdestroot phase. Check for permissions.
proc portcheckdestroot::checkdestroot_start {args} {
    if { [getuid] == 0 && [geteuid] != 0 } {
        # if started with sudo but have dropped the privileges
        ui_debug "Can't run checkdestroot under sudo without elevated privileges (due to mtree)."
        ui_debug "Run destroot without sudo to avoid root privileges."
        ui_debug "Going to escalate privileges back to root."
        setegid $egid
        seteuid $euid
        ui_debug "euid changed to: [geteuid]. egid changed to: [getegid]."
    }
}

# escape chars in order to be usable as regexp. This function is for internal use. 
proc portcheckdestroot::escape_chars {str} {
    return [regsub -all {\W} $str {\\&}]
}

# List all links on a directory recursively. This function is for internal use.
proc portcheckdestroot::links_list {dir} {
    return [types_list $dir "l"]
}

# List all binary files on a directory recursively. This function is for internal use.
proc portcheckdestroot::bin_list {dir} {
    return [types_list $dir "f" 1]
}

# List all files on a directory recursively. This function is for internal use.
proc portcheckdestroot::files_list {dir} {
    return [types_list $dir "f"]
}

# List all files of a type on a directory recursively. This function is for internal use.
proc portcheckdestroot::types_list {dir type {bin 0} } {
    set ret {}
    foreach item [glob -nocomplain -type "d $type" -directory $dir *] {
        if {[file isdirectory $item]} {
            set ret [concat $ret [types_list $item $type $bin]]
        } else {
            #is from the correct type
            if { $bin } {
                lappend ret $item
            } else {
                lappend ret $item
            }
        }
    }
    return $ret
}

# List dependencies from the current package
proc portcheckdestroot::get_dependencies {} {
    global destroot destroot.depends_lib subport depends_lib
    set deps {}
    if {[info exists depends_lib]} {
        foreach dep $depends_lib {
            set dep_portname [_get_dep_port $dep]
            lappend deps $dep_portname
        }
    }
    return $deps
}

# Check for errors on port symlinks
proc portcheckdestroot::checkdestroot_symlinks {} {
    global UI_PREFIX destroot prefix
    ui_notice "$UI_PREFIX Checking symlinks"
    foreach link [links_list $destroot] {
        set points_to [file link $link]
        if { [file pathtype $points_to] eq {absolute} } {
            #This might be changed for RegExp support
            if {[regexp $destroot$prefix $points_to]} {
                return -code error "$link is an absolute link to a path inside destroot"
            } else {
                ui_debug "$link is an absolute link to a path outside destroot"
            }
        } elseif {[file pathtype $points_to] eq {relative}} {
            if {[regexp $destroot$prefix [file normalize [file join [file dirname $link] $points_to]]]} {
                ui_debug "$link is a relative link to a path inside destroot"
            } else {
                return -code error "$link is a relative link to a path outside destroot"
            }
        }
    }
}

# Check for erros that violates the macports directory tree.
proc portcheckdestroot::checkdestroot_mtree {} {

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

# Check for dynamic links that aren't in the dependency list
proc portcheckdestroot::checkdestroot_libs {} {
    global destroot prefix UI_PREFIX subport
    global files_whitelist folders_whitelist

    ui_notice "$UI_PREFIX Checking for wrong dynamic links"

    #Get dependencies files list.
    set dep_files {}
    foreach dep [get_dependencies] {
        lappend dep_files [registry_port_registered $dep]
    }

    set self_files [bin_list $destroot$prefix]
    set dep_files [concat $dep_files $self_files]

    #Get package files
    foreach file [files_list $destroot] {
        set file_libs [list_dlibs $file]
        ui_debug "File $file has $file_libs libs"
        foreach file_lib $file_libs {
            set valid_lib 0
            # File itself
            if { [regexp [escape_chars $file_lib] $file] } {
                set valid_lib 1
            }

            # File from the package or its depended ports
            if { ! $valid_lib } {
                foreach dep_file $dep_files {
                    if { [regexp [escape_chars $file_lib] $dep_file] } {
                        set valid_lib 1
                        ui_debug "$file_lib binary dependency is met"
                    }
                }
            }
            # on files whitelist
            if { ! $valid_lib } {
                foreach dep_file $files_whitelist {
                    if { [regexp [escape_chars $dep_file] [file tail $file_lib]] } {
                        ui_debug "$file_lib binary dependency folder is on whitelist"
                        set valid_lib 1
                        break
                    }
                }
            }
            # on folders whitelist
            if { ! $valid_lib } {
                foreach dep_folder $folders_whitelist {
                    if { [regexp "^$dep_folder" [regsub $prefix $file_lib ""]] } {
                        ui_debug "$file_lib binary dependency folder is on whitelist"
                        set valid_lib 1
                        break
                    }
                }
            }
            if { ! $valid_lib } {
                   return -code error "$file '$file_lib' binary dependencies are NOT met"
            }
        }
    }
}

# Check for arch constraints
proc portcheckdestroot::checkdestroot_arch {} {
    global UI_PREFIX destroot
    ui_notice "$UI_PREFIX Checking for archs"
    set archs [get_canonical_archs]
    if { [expr {$archs ne "noarch"}] } {
        foreach file [files_list $destroot] {
            set file_archs [list_archs $file]
            ui_debug "File $file has $file_archs archs"
            if { [expr {$file_archs ne {}}] } {
                foreach arch $file_archs {
                    if { [lsearch $arch $archs] == -1 } {
                        return -code error "$file supports the arch $arch, and should not"
                    }
                }
                foreach arch $archs {
                    if { [lsearch $arch $file_archs] == -1 } {
                        return -code error "$file does not suport the arch $arch, and it should"
                    }
                }
            }
        }
    }
}

proc portcheckdestroot::checkdestroot_main {args} {
    global UI_PREFIX
    ui_notice "$UI_PREFIX Executing check-destroot phase"

    checkdestroot_symlinks
    checkdestroot_mtree
    checkdestroot_libs
    checkdestroot_arch
    return 0
}
