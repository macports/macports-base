# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# portdestroot.tcl
#
# Copyright (c) 2002 - 2003 Apple Inc.
# Copyright (c) 2004 - 2005 Robert Shaw <rshaw@opendarwin.org>
# Copyright (c) 2004-2005, 2007-2013 The MacPorts Project
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

package provide portdestroot 1.0
package require portutil 1.0

set org.macports.destroot [target_new org.macports.destroot portdestroot::destroot_main]
target_provides ${org.macports.destroot} destroot
target_requires ${org.macports.destroot} main fetch checksum extract patch configure build
target_prerun ${org.macports.destroot} portdestroot::destroot_start
target_postrun ${org.macports.destroot} portdestroot::destroot_finish

namespace eval portdestroot {
    # Save old umask
    variable oldmask
}

# define options
options destroot.target destroot.destdir destroot.clean destroot.keepdirs destroot.umask \
        destroot.violate_mtree destroot.asroot destroot.delete_la_files
commands destroot

# Set defaults
default destroot.asroot no
default destroot.dir {${build.dir}}
default destroot.cmd {${build.cmd}}
default destroot.pre_args {[portdestroot::destroot_getargs]}
default destroot.target install
default destroot.post_args {${destroot.destdir}}
default destroot.destdir {DESTDIR=${destroot}}
default destroot.nice {${buildnicevalue}}
default destroot.umask {$system_options(destroot_umask)}
default destroot.clean no
default destroot.keepdirs ""
default destroot.violate_mtree no
default destroot.delete_la_files {${delete_la_files}}

set_ui_prefix

proc portdestroot::destroot_getargs {args} {
    if {(([option build.type] eq "default" && [option os.platform] ne "freebsd") || \
         ([option build.type] eq "gnu")) \
        && [regexp "^(/\\S+/|)(g|gnu|)make(\\s+.*|)$" [option destroot.cmd]]} {
        # Print "Entering directory" lines for better log debugging
        return "-w [option destroot.target]"
    }

    return "[option destroot.target]"
}

proc portdestroot::destroot_start {args} {
    global UI_PREFIX prefix subport porturl destroot os.platform destroot.clean portsharepath \
           destroot.umask destroot.asroot euid egid \
           applications_dir frameworks_dir
    variable oldmask

    ui_notice "$UI_PREFIX [format [msgcat::mc "Staging %s into destroot"] ${subport}]"

    # start gsoc08-privileges
    if { [getuid] == 0 && [geteuid] != 0 } {
    # if started with sudo but have dropped the privileges
        ui_debug "Can't run destroot under sudo without elevated privileges (due to mtree)."
        ui_debug "Run destroot without sudo to avoid root privileges."
        ui_debug "Going to escalate privileges back to root."
        seteuid $euid
        setegid $egid
        ui_debug "euid changed to: [geteuid]. egid changed to: [getegid]."
    }

    if { [tbool destroot.asroot] && [getuid] != 0 } {
        return -code error "You cannot run this port without root privileges. You need to re-run with 'sudo port'.";
    }

    # end gsoc08-privileges

    set oldmask [umask ${destroot.umask}]
    set mtree [findBinary mtree ${portutil::autoconf::mtree_path}]

    if { ${destroot.clean} eq "yes" } {
        delete "${destroot}"
    }

    file mkdir "${destroot}"
    if { ${os.platform} eq "darwin" } {
        system -W ${destroot} "${mtree} -e -U -f [shellescape [file join ${portsharepath} install macosx.mtree]]"
        file mkdir "${destroot}${applications_dir}"
        file mkdir "${destroot}${frameworks_dir}"
    }
    file mkdir "${destroot}${prefix}"
    system -W ${destroot}${prefix} "${mtree} -e -U -f [shellescape [file join ${portsharepath} install prefix.mtree]]"

    # Create startup-scripts/items
    portstartupitem::startupitem_create
}

proc portdestroot::destroot_main {args} {
    command_exec -callback portprogress::target_progress_callback destroot
    return 0
}

proc portdestroot::destroot_finish {args} {
    global UI_PREFIX destroot prefix subport destroot.violate_mtree \
           applications_dir frameworks_dir destroot.keepdirs destroot.delete_la_files \
           os.platform os.version
    variable oldmask

    foreach fileToDelete {share/info/dir lib/charset.alias} {
        if {[file exists "${destroot}${prefix}/${fileToDelete}"]} {
            ui_debug "Deleting stray ${fileToDelete} file."
            file delete "${destroot}${prefix}/${fileToDelete}"
        }
    }

    # Prevent overlinking due to glibtool .la files: https://trac.macports.org/ticket/38010
    ui_debug "Fixing glibtool .la files in destroot for ${subport}"
    set la_file_list [list]
    fs-traverse -depth fullpath [list $destroot] {
        if {[file extension $fullpath] eq ".la" && ([file type $fullpath] eq "file" || [file type $fullpath] eq "link")} {
            if {[file type $fullpath] eq "link" && [file pathtype [file link $fullpath]] ne "relative"} {
                # prepend $destroot to target of absolute symlinks
                set checkpath ${destroot}[file link $fullpath]
            } else {
                set checkpath $fullpath
            }
            # Make sure it is from glibtool ... "a libtool library file" will appear in the first line
            if {![catch {set fp [open $checkpath]}]} {
                if {[gets $fp line] > 0 && [string first "a libtool library file" $line] != -1} {
                    lappend la_file_list $fullpath
                }
            } else {
                ui_debug "Failed to open $checkpath"
            }
            catch {close $fp}
        }
    }
    foreach fullpath $la_file_list {
        if {${destroot.delete_la_files}} {
            ui_debug "Removing [file tail $fullpath]"
            file delete -force ${fullpath}
        } elseif {[file type $fullpath] eq "file"} {
            ui_debug "Clearing dependency_libs in [file tail $fullpath]"
            reinplace -q "/dependency_libs/ s/'.*'/''/" ${fullpath}
        }
    }

    # Prune empty directories in ${destroot}
    foreach path ${destroot.keepdirs} {
        if {![file isdirectory ${path}]} {
            xinstall -m 0755 -d ${path}
        }
        if {![file exists ${path}/.turd_${subport}]} {
            xinstall -c -m 0644 /dev/null ${path}/.turd_${subport}
        }
    }
    fs-traverse -depth dir [list ${destroot}] {
        if {[file type $dir] eq "directory"} {
            catch {file delete $dir}
        }
    }

    if {![file isdirectory ${destroot}]} {
        ui_error "No files have been installed in the destroot directory!"
        ui_error "Please make sure that this software supports\
                  'make install DESTDIR=\${destroot}' or implement an\
                  alternative destroot mechanism in the Portfile."
        ui_error "Files might have been installed directly into your system,\
                  check before proceeding."
        return -code error "Staging $subport into destroot failed"
    }

    # Compress all manpages with gzip (instead)
    set manpath "${destroot}${prefix}/share/man"
    set gzip [findBinary gzip ${portutil::autoconf::gzip_path}]
    set gunzip "$gzip -d"
    set bunzip2 "[findBinary bzip2 ${portutil::autoconf::bzip2_path}] -d"
    if {[file isdirectory ${manpath}] && [file type ${manpath}] eq "directory"} {
        ui_info "$UI_PREFIX [format [msgcat::mc "Compressing man pages for %s"] ${subport}]"
        set found 0
        set manlinks [list]
        set mandir_re {^(cat|man)(.)$}

        foreach mandir [readdir "${manpath}"] {
            if {![regexp ${mandir_re} ${mandir} match ignore manindex]} { continue }
            set gzfile_re "^(.*\[.\]${manindex}\[a-z\]*)\[.\]gz\$"
            set bz2file_re "^(.*\[.\]${manindex}\[a-z\]*)\[.\]bz2\$"
            set normalfile_re "\[.\]${manindex}\[a-z\]*\$"
            set mandirpath [file join ${manpath} ${mandir}]
            if {[file isdirectory ${mandirpath}] && [file type ${mandirpath}] eq "directory"} {
                ui_debug "Scanning ${mandir}"
                foreach manfile [readdir ${mandirpath}] {
                    set manfilepath [file join ${mandirpath} ${manfile}]
                    if {[file isfile ${manfilepath}] && [file type ${manfilepath}] eq "file"} {
                        if {[regexp ${gzfile_re} ${manfile} gzfile manfile]} {
                            set found 1
                            system -W ${manpath} \
                            "$gunzip -f [shellescape [file join ${mandir} ${gzfile}]] && \
                            $gzip -9vnf [shellescape [file join ${mandir} ${manfile}]]"
                        } elseif {[regexp ${bz2file_re} ${manfile} bz2file manfile]} {
                            set found 1
                            system -W ${manpath} \
                            "$bunzip2 -f [shellescape [file join ${mandir} ${bz2file}]] && \
                            $gzip -9vnf [shellescape [file join ${mandir} ${manfile}]]"
                        } elseif {[regexp ${normalfile_re} ${manfile}]} {
                            set found 1
                            system -W ${manpath} \
                            "$gzip -9vnf [shellescape [file join ${mandir} ${manfile}]]"
                        }
                        set gzmanfile ${manfile}.gz
                        set gzmanfilepath [file join ${mandirpath} ${gzmanfile}]
                        if {[file exists ${gzmanfilepath}]} {
                            set desired 00444
                            set current [file attributes ${gzmanfilepath} -permissions]
                            if {$current != $desired} {
                                ui_info "[file join ${mandir} ${gzmanfile}]: changing permissions from $current to $desired"
                                file attributes ${gzmanfilepath} -permissions $desired
                            }
                        }
                    } elseif {[file type ${manfilepath}] eq "link"} {
                        lappend manlinks [file join ${mandir} ${manfile}]
                    }
                }
            }
        }
        if {$found == 1} {
            # check man page links and rename/repoint them if necessary
            set gzext_re "\[.\]gz\$"
            foreach manlink $manlinks {
                set manlinkpath [file join $manpath $manlink]
                # if link destination is not gzipped, check it
                set manlinksrc [file readlink $manlinkpath]
                if {![regexp ${gzext_re} ${manlinksrc}]} {
                    set mandir [file dirname $manlink]
                    set mandirpath [file join $manpath $mandir]
                    set pwd [pwd]
                    if {[catch {_cd $mandirpath} err]} {
                        puts $err
                        return
                    }
                    # if link source is an absolute path, check for it under destroot
                    set mls_check "$manlinksrc"
                    if {[file pathtype $mls_check] eq "absolute"} {
                        set mls_check "${destroot}${mls_check}"
                    }
                    # if gzipped destination exists, fix link
                    if {[file isfile ${mls_check}.gz]} {
                        # if actual link name does not end with gz, rename it
                        if {![regexp ${gzext_re} ${manlink}]} {
                            ui_debug "renaming link: $manlink to ${manlink}.gz"
                            file rename $manlinkpath ${manlinkpath}.gz
                            set manlink ${manlink}.gz
                            set manlinkpath [file join $manpath $manlink]
                        }
                        # repoint the link
                        ui_debug "repointing link: $manlink from $manlinksrc to ${manlinksrc}.gz"
                        file delete $manlinkpath
                        ln -s "${manlinksrc}.gz" "${manlinkpath}"
                    }
                    _cd $pwd
                }
            }
        } else {
            ui_debug "No man pages found to compress."
        }
    }

    # test for violations of mtree
    if { ${destroot.violate_mtree} ne "yes" } {
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
                        if {$pfile ni $prefixPaths} {
                            ui_warn "violation by [file join $dfile $pfile]"
                            set mtree_violation "yes"
                        }
                    }
                } elseif {[string equal -length [expr {[string length $dfile] + 1}] $dfile/ $prefix]} {
                    # we've found a subpath of our prefix
                    lpush pathsToCheck $dfile
                } else {
                    set dir_allowed no
                    # these files are (at least potentially) outside of the prefix
                    foreach dir "$applications_dir $frameworks_dir /Library/LaunchAgents /Library/LaunchDaemons /Library/StartupItems" {
                        if {[string equal -length [expr {[string length $dfile] + 1}] $dfile/ $dir]} {
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
        if { ${mtree_violation} ne "no" } {
            ui_warn "[format [msgcat::mc "%s violates the layout of the ports-filesystems!"] [option subport]]"
            ui_warn "Please fix or indicate this misbehavior (if it is intended), it will be an error in future releases!"
            # error "mtree violation!"
        }
    } else {
        ui_warn "[format [msgcat::mc "%s installs files outside the common directory structure."] [option subport]]"
    }

    # Restore umask
    umask $oldmask

    return 0
}
