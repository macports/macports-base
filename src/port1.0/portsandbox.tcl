# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# $Id$
#
# Copyright (c) 2012 The MacPorts Project
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

namespace eval portsandbox {
}

options portsandbox_supported portsandbox_profile
default portsandbox_supported {[file executable $portutil::autoconf::sandbox_exec_path]}
default portsandbox_profile {[portsandbox::get_default_profile]}

# produce a suitable profile to pass to sandbox-exec
# command line usage would be:
# sandbox-exec -p '(version 1) (allow default) (deny file* (subpath "/usr/local") (subpath "/Library/Frameworks"))' some-command
proc portsandbox::get_default_profile {} {
    global os.major prefix frameworks_dir
    set prefix_conflict [expr {$prefix == "/usr/local" || [string match $prefix "/usr/local/*"]}]
    set frameworks_conflict [expr {$frameworks_dir == "/Library/Frameworks" || [string match $frameworks_dir "/Library/Frameworks/*"]}]
    if {$prefix_conflict && $frameworks_conflict} {
        return ""
    }
    set profile "(version 1) (allow default) (deny "
    if {${os.major} > 9} {
        append profile "file* "
        if {!$prefix_conflict} {
            append profile {(subpath "/usr/local")}
        }
        if {!$frameworks_conflict} {
            append profile { (subpath "/Library/Frameworks")}
        }
    } else {
        append profile "file-read* file-write* (regex "
        if {!$prefix_conflict} {
            append profile {#"^/usr/local/"}
        }
        if {!$frameworks_conflict} {
            append profile { #"^/Library/Frameworks/"}
        }
        append profile ")"
    }
    append profile ")"
    return $profile
}
