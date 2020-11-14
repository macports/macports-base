# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
#
# Copyright (c) 2012-2013 The MacPorts Project
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of The MacPorts Project nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

package provide portsandbox 1.0
package require porttrace 1.0
package require portutil 1.0

namespace eval portsandbox {
}

options portsandbox_supported portsandbox_active portsandbox_profile
default portsandbox_supported {[file executable $portutil::autoconf::sandbox_exec_path]}
default portsandbox_active {[expr {$portsandbox_supported && $sandbox_enable}]}
default portsandbox_profile {}

# set up a suitable profile to pass to sandbox-exec, based on the target
# command line usage would be:
# sandbox-exec -p '(version 1) (allow default) (deny file-write*) (allow file-write* <filter>)' some-command
proc portsandbox::set_profile {target} {
    global os.major portsandbox_profile workpath distpath \
        package.destpath configure.ccache ccache_dir \
        sandbox_network configure.distcc porttrace prefix_frozen

    switch $target {
        activate -
        deactivate -
        dmg -
        mdmg -
        load -
        unload -
        reload {
            set portsandbox_profile ""
            return
        }
        install -
        uninstall {
            set allow_dirs [list [file dirname [get_portimage_path]]]
        }
        fetch -
        mirror -
        clean {
            set allow_dirs [list $distpath]
        }
        pkg {
            if {${os.major} == 12} {
                # FIXME: fails on Mountain Lion with the current profile
                set portsandbox_profile ""
                return
            } else {
                set allow_dirs [list ${package.destpath}]
            }
        }
    }

    lappend allow_dirs $workpath ${portutil::autoconf::trace_sipworkaround_path}
    if {${configure.ccache}} {
        lappend allow_dirs $ccache_dir
    }

    set portsandbox_profile "(version 1) (allow default) (deny file-write*) \
(allow file-write-data (literal \"/dev/null\") (literal \"/dev/zero\") \
(literal \"/dev/dtracehelper\") (literal \"/dev/tty\") \
(literal \"/dev/stdin\") (literal \"/dev/stdout\") (literal \"/dev/stderr\") \
(literal \"/dev/random\") (literal \"/dev/urandom\") \
(regex #\"^/dev/fd/\")) (allow file-write* \
(regex #\"^(/private)?(/var)?/tmp/\" #\"^(/private)?/var/folders/\" #\"^(/private)?/var/db/mds/\"))"

    # allow access to ptys
    append portsandbox_profile "\
(allow file-write-data (regex #\"^/dev/ttys\") (literal \"/dev/ptmx\")) \
(allow file-write-mode (regex #\"^/dev/ttys\"))"

    set perms [list file-write*]
    if {${os.major} >= 17} {
        lappend perms file-write-setugid
    }


    # If ${prefix} is own its own volume, grant access to its
    # temporary items directory, used by Xcode tools
    if {[catch {get_mountpoint ${prefix_frozen}} mountpoint]} {
        ui_debug "get_mountpoint failed: $mountpoint"
        set mountpoint /
    }

    if {$mountpoint ne "/"} {
        set extradir [file join $mountpoint ".TemporaryItems"]

        if {[file isdirectory $extradir]} {
            ui_debug "adding $extradir to allowed Sandbox paths"
            lappend allow_dirs $extradir
        }
    }

    foreach dir $allow_dirs {
        foreach perm $perms {
            append portsandbox_profile " (allow $perm ("
            if {${os.major} > 9} {
                append portsandbox_profile "subpath \"${dir}\"))"
            } else {
                append portsandbox_profile "regex #\"^${dir}/\"))"
            }
        }
    }

    if {${sandbox_network}} {
        if {$target ne "fetch" && $target ne "mirror"} {
            if {${configure.distcc}} {
                ui_warn "Sandbox will not deny network access due to distcc"
            } else {
                append portsandbox_profile " (deny network*)"
                if {$porttrace} {
                    # allow accessing the darwintrace fifo in trace mode
                    set template [string trimright ${porttrace::fifo_mktemp_template} "X"]
                    append portsandbox_profile " (allow network-outbound (to unix-socket) (regex #\"^${template}\"))"
                }
            }
        }
    }
}
