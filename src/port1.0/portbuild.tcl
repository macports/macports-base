# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# portbuild.tcl
#
# Copyright (c) 2007 - 2013 The MacPorts Project
# Copyright (c) 2002 - 2004 Apple Inc.
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

package provide portbuild 1.0
package require portutil 1.0
package require portprogress 1.0

set org.macports.build [target_new org.macports.build portbuild::build_main]
target_provides ${org.macports.build} build
target_requires ${org.macports.build} main fetch checksum extract patch configure
target_prerun ${org.macports.build} portbuild::build_start

namespace eval portbuild {
}

# define options
options build.asroot \
        build.jobs \
        build.jobs_arg \
        build.mem_per_job \
        build.target \
        use_parallel_build
commands build
# defaults
default build.asroot no
default build.dir {${worksrcpath}}
default build.cmd {[portbuild::build_getmaketype]}
default build.nice {${buildnicevalue}}
default build.jobs {[portbuild::build_getjobs]}
default build.jobs_arg {[portbuild::build_getjobsarg]}
default build.mem_per_job 1024
default build.pre_args {[portbuild::build_getargs]}
default build.target all
default build.type default
default use_parallel_build yes

set_ui_prefix

# Automatically called from macports1.0 after evaluating the Portfile. If
# ${build.type} == bsd, ensures bsdmake is present by adding a bin:-style
# dependency.
proc portbuild::add_automatic_buildsystem_dependencies {} {
    global build.type.add_deps build.type os.platform
    if {!${build.type.add_deps}} {
        return
    }
    if {${build.type} eq "bsd" && ${os.platform} eq "darwin"} {
        ui_debug "build.type is BSD, adding bin:bsdmake:bsdmake build dependency"
        depends_build-delete bin:bsdmake:bsdmake
        depends_build-append bin:bsdmake:bsdmake
    } elseif {${build.type} eq "gnu" && ${os.platform} eq "freebsd"} {
        ui_debug "build.type is GNU, adding bin:gmake:gmake build dependency"
        depends_build-delete bin:gmake:gmake
        depends_build-append bin:gmake:gmake
    }
}
# Register the above procedure as a callback after Portfile evaluation
port::register_callback portbuild::add_automatic_buildsystem_dependencies
# and an option to turn it off if required
options build.type.add_deps
default build.type.add_deps yes

proc portbuild::build_getmaketype {args} {
    global build.type os.platform
    macports_try -pass_signal {
        if {${build.type} eq "default"} {
            return [findBinary make $portutil::autoconf::make_path]
        }
        switch -exact -- ${build.type} {
            bsd {
                if {${os.platform} eq "darwin"} {
                    return [findBinary bsdmake $portutil::autoconf::bsdmake_path]
                } elseif {${os.platform} eq "freebsd"} {
                    return [findBinary make $portutil::autoconf::make_path]
                } else {
                    return [findBinary pmake $portutil::autoconf::bsdmake_path]
                }
            }
            gnu {
                if {${os.platform} eq "darwin"} {
                    return [findBinary gnumake $portutil::autoconf::gnumake_path]
                } elseif {${os.platform} eq "linux"} {
                    return [findBinary make $portutil::autoconf::make_path]
                } else {
                    return [findBinary gmake $portutil::autoconf::gnumake_path]
                }
            }
            pbx -
            xcode {
                if {${os.platform} ne "darwin"} {
                    error "[format [msgcat::mc "This port requires 'xcodebuild', which is not available on %s."] ${os.platform}]"
                }

                global xcodebuildcmd
                if {$xcodebuildcmd ne "none"} {
                    return $xcodebuildcmd
                } else {
                    error "xcodebuild was not found on this system!"
                }
            }
            default {
                ui_warn "[format [msgcat::mc "Unknown build.type %s, using 'gnumake'"] ${build.type}]"
                return [findBinary gnumake $portutil::autoconf::gnumake_path]
            }
        }
    } on error {eMessage} {
        ui_warn $eMessage
        ui_warn "Unable to find build command for build.type '${build.type}'"
    }
    return ""
}

proc portbuild::build_getjobs {args} {
    global buildmakejobs use_parallel_build
    set jobs $buildmakejobs
    # If parallel disabled disabled, return 1
    if {![tbool use_parallel_build]} {
        ui_debug "port disallows a parallel build, setting build jobs to 1"
        set jobs 1
    }
    # if set to '0', use the number of cores for the number of jobs
    if {$jobs == 0} {
        macports_try -pass_signal {
            set jobs [sysctl hw.activecpu]
        } on error {} {
            set jobs 2
            ui_warn "failed to determine the number of available CPUs (probably not supported on this platform)"
            ui_warn "defaulting to $jobs jobs, consider setting buildmakejobs to a nonzero value in macports.conf"
        }

        macports_try -pass_signal {
            set memsize [sysctl hw.memsize]
            global build.mem_per_job
            set jobs_limit_mem [expr {int($memsize / (${build.mem_per_job} * 1024 * 1024)) + 1}]
            if {$jobs > $jobs_limit_mem} {
                set jobs $jobs_limit_mem
            }
        } on error {} {}
    }
    if {![string is integer -strict $jobs] || $jobs <= 1} {
        set jobs 1
    }
    return $jobs
}

proc portbuild::build_getargs {args} {
    global build.type os.platform build.cmd build.target
    if {((${build.type} eq "default" && ${os.platform} ne "freebsd") || \
         (${build.type} eq "gnu")) \
        && [regexp "^(/\\S+/|)(g|gnu|)make(\\s+.*|)$" ${build.cmd}]} {
        # Print "Entering directory" lines for better log debugging
        return "-w ${build.target}"
    }

    return ${build.target}
}

proc portbuild::build_getjobsarg {args} {
    global build.cmd build.jobs
    set cmdname [file tail [lindex ${build.cmd} 0]]
    if {![exists build.jobs] || \
            !([string match "*make" $cmdname] || \
              "ninja" eq $cmdname || \
              "scons" eq $cmdname)} {
        return ""
    }

    set jobs ${build.jobs}
    if {![string is integer -strict $jobs] || $jobs < 1 || ($cmdname ne "ninja" && $jobs < 2)} {
        return ""
    }
    return " -j$jobs"
}

proc portbuild::build_start {args} {
    global UI_PREFIX subport

    ui_notice "$UI_PREFIX [format [msgcat::mc "Building %s"] ${subport}]"
}

proc portbuild::build_main {args} {
    global build.cmd build.jobs_arg

    if {${build.cmd} eq ""} {
        error "No build command found"
    }

    set realcmd ${build.cmd}
    append build.cmd ${build.jobs_arg}
    command_exec -callback portprogress::target_progress_callback build
    set build.cmd ${realcmd}
    return 0
}
