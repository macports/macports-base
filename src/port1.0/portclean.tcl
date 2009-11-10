# et:ts=4
# portclean.tcl
# $Id$
#
# Copyright (c) 2004 Robert Shaw <rshaw@opendarwin.org>
# Copyright (c) 2002 - 2003 Apple Computer, Inc.
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

# the 'clean' target is provided by this package

package provide portclean 1.0
package require portutil 1.0
package require Pextlib 1.0

set org.macports.clean [target_new org.macports.clean portclean::clean_main]
target_runtype ${org.macports.clean} always
target_state ${org.macports.clean} no
target_provides ${org.macports.clean} clean
target_requires ${org.macports.clean} main
target_prerun ${org.macports.clean} portclean::clean_start

namespace eval portclean {
}

set_ui_prefix

proc portclean::clean_start {args} {
    global UI_PREFIX

    ui_msg "$UI_PREFIX [format [msgcat::mc "Cleaning %s"] [option name]]"
}

proc portclean::clean_main {args} {
    global UI_PREFIX
    global ports_clean_dist ports_clean_work ports_clean_archive ports_clean_logs
    global ports_clean_all usealtworkpath 
    global	keeplogs

    if {[info exists ports_clean_all] && $ports_clean_all == "yes" || \
        [info exists ports_clean_dist] && $ports_clean_dist == "yes"} {
        ui_info "$UI_PREFIX [format [msgcat::mc "Removing distfiles for %s"] [option name]]"
        clean_dist
    }
    if {[info exists ports_clean_all] && $ports_clean_all == "yes" || \
        [info exists ports_clean_archive] && $ports_clean_archive == "yes"} {
        ui_info "$UI_PREFIX [format [msgcat::mc "Removing archives for %s"] [option name]]"
        clean_archive
    }
    if {[info exists ports_clean_all] && $ports_clean_all == "yes" || \
        [info exists ports_clean_work] && $ports_clean_work == "yes" || \
        (!([info exists ports_clean_archive] && $ports_clean_archive == "yes"))} {
         ui_info "$UI_PREFIX [format [msgcat::mc "Removing build directory for %s"] [option name]]"
         clean_work
    }
    if {([info exists ports_clean_logs] && $ports_clean_logs == "yes") || ($keeplogs == "no")} {
        clean_logs
    }

    # start gsoc-08 privileges
    if {[info exists usealtworkpath] && $usealtworkpath == "yes"} {
        ui_info "$UI_PREFIX [format [msgcat::mc "Removing alt source directory for %s"] [option name]]"
        clean_altsource
    }
    # end gsoc-08 privileges

    return 0
}

proc portclean::clean_altsource {args} {
    global usealtworkpath worksymlink

    set sourcepath [string map {"work" ""} $worksymlink]

    if {[file isdirectory $sourcepath]} {
        ui_debug "Removing directory: ${sourcepath}"
        if {[catch {delete $sourcepath} result]} {
            ui_debug "$::errorInfo"
            ui_error "$result"
        }
    } else {
        ui_debug "No alt source directory found to remove."
    }

    return 0
}

#
# Remove the directory where the distfiles reside.
# This is crude, but works.
#
proc portclean::clean_dist {args} {
    global ports_force name distpath dist_subdir distfiles

    # remove known distfiles for sure (if they exist)
    set count 0
    foreach file $distfiles {
        if {[info exist distpath] && [info exists dist_subdir]} {
            set distfile [file join $distpath $dist_subdir $file]
        } else {
            set distfile [file join $distpath $file]
        }
        if {[file isfile $distfile]} {
            ui_debug "Removing file: $distfile"
            if {[catch {delete $distfile} result]} {
                ui_debug "$::errorInfo"
                ui_error "$result"
            }
            set count [expr $count + 1]
        }
    }
    if {$count > 0} {
        ui_debug "$count distfile(s) removed."
    } else {
        ui_debug "No distfiles found to remove at $distpath"
    }

    # next remove dist_subdir if only needed for this port,
    # or if user forces us to
    set dirlist [list]
    if {($dist_subdir != $name)} {
        if {[info exists dist_subdir]} {
            set distfullpath [file join $distpath $dist_subdir]
            if {!([info exists ports_force] && $ports_force == "yes")
                && [file isdirectory $distfullpath]
                && [llength [readdir $distfullpath]] > 0} {
                ui_warn [format [msgcat::mc "Distfiles directory '%s' may contain distfiles needed for other ports, use the -f flag to force removal" ] [file join $distpath $dist_subdir]]
            } else {
                lappend dirlist $dist_subdir
                lappend dirlist $name
            }
        } else {
            lappend dirlist $name
        }
    } else {
        lappend dirlist $name
    }
    # loop through directories
    set count 0
    foreach dir $dirlist {
        set distdir [file join $distpath $dir]
        if {[file isdirectory $distdir]} {
            ui_debug "Removing directory: ${distdir}"
            if {[catch {delete $distdir} result]} {
                ui_debug "$::errorInfo"
                ui_error "$result"
            }
            set count [expr $count + 1]
        }
    }
    if {$count > 0} {
        ui_debug "$count distfile directory(s) removed."
    } else {
        ui_debug "No distfile directory found to remove."
    }
    return 0
}

proc portclean::clean_work {args} {
    global portbuildpath worksymlink

    if {[file isdirectory $portbuildpath]} {
        ui_debug "Removing directory: ${portbuildpath}"
        if {[catch {delete $portbuildpath} result]} {
            ui_debug "$::errorInfo"
            ui_error "$result"
        }
    } else {
        ui_debug "No work directory found to remove at ${portbuildpath}"
    }

    # Clean symlink, if necessary
    if {![catch {file type $worksymlink} result] && $result eq "link"} {
        ui_debug "Removing symlink: $worksymlink"
        delete $worksymlink
    }

    return 0
}
proc portclean::clean_logs {args} {
    global portbuildpath worksymlink name portverbose keeplogs prefix
 	  set logpath "${prefix}/var/macports/logs/${name}"
  	if {[file isdirectory $logpath]} {
        ui_debug "Removing directory: ${logpath}"
        if {[catch {delete $logpath} result]} {
            ui_debug "$::errorInfo"
            ui_error "$result"
        }
    } else {
        ui_debug "No log directory found to remove at ${logpath}"
    }           	
    return 0
}

proc portclean::clean_archive {args} {
    global workpath portarchivepath name version ports_version_glob
    global configure.build_arch configure.universal_archs

    # Define archive destination directory, target filename, regex for archive name,
    # and universal arch string
    if {$portarchivepath ne $workpath && $portarchivepath ne ""} {
        if {[variant_exists universal] && [variant_isset universal]} {
            set archstring [join [lsort -ascii ${configure.universal_archs}] -]
            set archivepath [file join $portarchivepath [option os.platform] "universal"]
            set regexstring "^$name-\[-_a-zA-Z0-9\.\]+_\[0-9\]*\[+-_a-zA-Z0-9\]*\[\.\]${archstring}\[\.\]\[a-z2\]+\$"
        } else {
            set archivepath [file join $portarchivepath [option os.platform] ${configure.build_arch}]
            set regexstring "^$name-\[-_a-zA-Z0-9\.\]+_\[0-9\]*\[+-_a-zA-Z0-9\]*\[\.\]${configure.build_arch}\[\.\]\[a-z2\]+\$"
        }
    }

    if {[info exists ports_version_glob]} {
        # Match all possible archive variants that match the version
        # glob specified by the user for this OS.
        if {[variant_exists universal] && [variant_isset universal]} {
            set fileglob "$name-[option ports_version_glob]*+universal.${archstring}.*"
        } else {
            set fileglob "$name-[option ports_version_glob]*.${configure.build_arch}.*"
        }
    } else {
        # Match all possible archive variants for the current version on
        # this OS. If you want to delete previous versions, use the
        # version glob argument to clean.
        #
        # We do this because if we don't, then ports that match the
        # first part of the name (e.g. trying to remove foo-* will
        # pick up anything foo-bar-* as well, which is undesirable).
        if {[variant_exists universal] && [variant_isset universal]} {
            set fileglob "$name-$version*+universal.${archstring}.*"
        } else {
            set fileglob "$name-$version*.${configure.build_arch}.*"
        }
    }

    # Remove the archive files
    set count 0
    if {![catch {set archivelist [glob [file join $archivepath $fileglob]]} result]} {
        foreach path $archivelist {
            set file [file tail $path]
            # Make sure file is truly a port archive file, and not
            # an accidental match with some other file that might exist.
            if {[regexp $regexstring $file]} {
                if {[file isfile $path]} {
                    ui_debug "Removing archive: $path"
                    if {[catch {delete $path} result]} {
                        ui_debug "$::errorInfo"
                        ui_error "$result"
                    }
                    set count [expr $count + 1]
                }
            }
        }
    }
    if {$count > 0} {
        ui_debug "$count archive(s) removed."
    } else {
        ui_debug "No archives found to remove at $archivepath"
    }

    return 0
}

