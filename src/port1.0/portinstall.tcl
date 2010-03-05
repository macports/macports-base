# et:ts=4
# portinstall.tcl
# $Id$
#
# Copyright (c) 2002 - 2003 Apple Computer, Inc.
# Copyright (c) 2004 Robert Shaw <rshaw@opendarwin.org>
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
# 3. Neither the name of Apple Computer, Inc. nor the names of its contributors
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

package provide portinstall 1.0
package require portutil 1.0
package require registry2 2.0

set org.macports.install [target_new org.macports.install portinstall::install_main]
target_provides ${org.macports.install} install
target_runtype ${org.macports.install} always
if {[option portarchivemode] == "yes"} {
    target_requires ${org.macports.install} main unarchive fetch extract checksum patch configure build destroot archive
} else {
    target_requires ${org.macports.install} main fetch extract checksum patch configure build destroot
}
target_prerun ${org.macports.install} portinstall::install_start

namespace eval portinstall {
}

# define options
options install.asroot

# Set defaults
default install.asroot no

set_ui_prefix

proc portinstall::install_start {args} {
    global UI_PREFIX name version revision portvariants
    global prefix registry_open registry.format registry.path
    ui_msg "$UI_PREFIX [format [msgcat::mc "Installing %s @%s_%s%s"] $name $version $revision $portvariants]"
    
    # start gsoc08-privileges
    if { ![file writable $prefix] } {
        # if install location is not writable, need root privileges to install
        elevateToRoot "install"
    }
    # end gsoc08-privileges
    
    if {${registry.format} == "receipt_sqlite" && ![info exists registry_open]} {
        registry::open [file join ${registry.path} registry registry.db]
        set registry_open yes
    }
}

proc portinstall::install_element {src_element dst_element} {
    # don't recursively copy directories
    if {[file isdirectory $src_element] && [file type $src_element] != "link"} {
        file mkdir $dst_element
    } else {
        file copy -force $src_element $dst_element
    }
    
    # if the file is a symlink, do not try to set file attributes
    if {[file type $src_element] != "link"} {
        # tclsh on 10.6 doesn't like the combination of 0444 perm and
        # '-creator {}' (which is returned from 'file attributes <file>'; so
        # instead just set the attributes which are needed
        set wantedattrs {owner group permissions}
        set file_attr_cmd {file attributes $dst_element}
        foreach oneattr $wantedattrs {
            set file_attr_cmd "$file_attr_cmd -$oneattr \[file attributes \$src_element -$oneattr\]"
        }
        eval $file_attr_cmd
        # set mtime on installed element
        file mtime $dst_element [file mtime $src_element]
    }
}

proc portinstall::directory_dig {rootdir workdir imagedir {cwd ""} {prepend 1}} {
    global installPlist
    set pwd [pwd]
    if {[catch {_cd $workdir} err]} {
        puts $err
        return
    }

    set root [file join [file separator] $imagedir]
    foreach name [readdir .] {
        set element [file join $cwd $name]

        set dst_element [file join $root $element]
        set src_element [file join $rootdir $element]
        # overwrites files but not directories
        if {![file exists $dst_element] || ![file isdirectory $dst_element]} {
            if {[file type $src_element] == "link"} {
                ui_debug "installing link: $dst_element"
            } elseif {[file isdirectory $src_element]} {
                ui_debug "installing directory: $dst_element"
            } else {
                ui_debug "installing file: $dst_element"
            }
            install_element $src_element $dst_element
            # only track files/links for registry, not directories
            if {[file type $dst_element] != "directory"} {
                if {$prepend} {
                    lappend installPlist $dst_element
                } else {
                    lappend installPlist [file join [file separator] $element]
                }
            }
        }
        if {[file isdirectory $name] && [file type $name] != "link"} {
            directory_dig $rootdir $name $imagedir [file join $cwd $name] $prepend
        }
    }
    _cd $pwd
}

proc portinstall::install_main {args} {
    global name version portpath categories description long_description \
    homepage depends_run installPlist package-install uninstall workdir \
    worksrcdir UI_PREFIX destroot revision maintainers ports_force \
    portvariants default_variants targets depends_lib PortInfo epoch license \
    registry.installtype registry.path registry.format \
    os.arch configure.build_arch configure.universal_archs supported_archs \
    os.platform os.major

    if {[string equal ${registry.format} "receipt_sqlite"]} {
        # registry2.0

        # can't do this inside the write transaction due to deadlock issues with _get_dep_port
        set dep_portnames [list]
        foreach deplist {depends_lib depends_run} {
            if {[info exists $deplist]} {
                foreach dep [set $deplist] {
                    set dep_portname [_get_dep_port $dep]
                    if {$dep_portname != ""} {
                        lappend dep_portnames $dep_portname
                    }
                }
            }
        }

        registry::write {

            set regref [registry::entry create $name $version $revision $portvariants $epoch]

            $regref os_platform ${os.platform}
            $regref os_major ${os.major}
            if {$supported_archs == "noarch"} {
                $regref archs noarch
            } elseif {[variant_exists universal] && [variant_isset universal]} {
                $regref archs [lsort -ascii ${configure.universal_archs}]
            } elseif {${configure.build_arch} != ""} {
                $regref archs ${configure.build_arch}
            } else {
                $regref archs ${os.arch}
            }
            # Trick to have a portable GMT-POSIX epoch-based time.
            $regref date [expr [clock scan now -gmt true] - [clock scan "1970-1-1 00:00:00" -gmt true]]
            if {[info exists default_variants]} {
                $regref default_variants $default_variants
            }

            foreach dep_portname $dep_portnames {
                $regref depends $dep_portname
            }

            if {${registry.installtype} == "image"} {
                $regref installtype image
                $regref state imaged
                set imagedir [file join ${registry.path} software ${name} ${version}_${revision}${portvariants}]
            } else {
                $regref installtype direct
                $regref state installed
                set imagedir ""
            }
            $regref location $imagedir

            # Install the files, requesting that the list not have the image dir prepended
            directory_dig ${destroot} ${destroot} ${imagedir} "" 0
            
            if {[info exists installPlist]} {
                # register files
                $regref map $installPlist
            }
            
            # store portfile
            set fd [open [file join ${portpath} Portfile]]
            $regref portfile [read $fd]
            close $fd
        }
    } else {
        # Begin the registry entry
        set regref [registry_new $name $version $revision $portvariants $epoch]

        set imagedir ""
        if { [registry_prop_retr $regref installtype] == "image" } {
            set imagedir [registry_prop_retr $regref imagedir]
        }
        # Install the files
        directory_dig ${destroot} ${destroot} ${imagedir}

        registry_prop_store $regref categories $categories

        registry_prop_store $regref os_platform ${os.platform}
        registry_prop_store $regref os_major ${os.major}
        if {$supported_archs == "noarch"} {
            registry_prop_store $regref archs noarch
        } elseif {[variant_exists universal] && [variant_isset universal]} {
            registry_prop_store $regref archs [lsort -ascii ${configure.universal_archs}]
        } elseif {${configure.build_arch} != ""} {
            registry_prop_store $regref archs ${configure.build_arch}
        } else {
            registry_prop_store $regref archs ${os.arch}
        }

        if {[info exists description]} {
            registry_prop_store $regref description [string map {\n \\n} ${description}]
        }
        if {[info exists long_description]} {
            registry_prop_store $regref long_description [string map {\n \\n} ${long_description}]
        }
        if {[info exists license]} {
            registry_prop_store $regref license ${license}
        }
        if {[info exists homepage]} {
            registry_prop_store $regref homepage ${homepage}
        }
        if {[info exists maintainers]} {
            registry_prop_store $regref maintainers ${maintainers}
        }
        if {[info exists depends_run]} {
            registry_prop_store $regref depends_run $depends_run
            registry_register_deps $depends_run $name
        }
        if {[info exists depends_lib]} {
            registry_prop_store $regref depends_lib $depends_lib
            registry_register_deps $depends_lib $name
        }
        if {[info exists installPlist]} {
            registry_prop_store $regref contents [registry_fileinfo_for_index $installPlist]
            if { [registry_prop_retr $regref installtype] != "image" } {
                registry_bulk_register_files [registry_fileinfo_for_index $installPlist] $name
            }
        }
        if {[info exists package-install]} {
            registry_prop_store $regref package-install ${package-install}
        }
        if {[info proc pkg_uninstall] == "pkg_uninstall"} {
            registry_prop_store $regref uninstall [proc_disasm pkg_uninstall]
        }

        registry_write $regref
    }

    return 0
}

proc portinstall::proc_disasm {pname} {
    set p "proc "
    append p $pname " \{"
    set space ""
    foreach arg [info args $pname] {
        if {[info default $pname $arg value]} {
            append p "$space{" [list $arg $value] "}"
        } else {
            append p $space $arg
        }
        set space " "
    }
    append p "\} \{" [info body $pname] "\}"
    return $p
}
