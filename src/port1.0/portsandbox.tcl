# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# $Id$
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

namespace eval portsandbox {
}

options portsandbox_supported portsandbox_active portsandbox_profile
default portsandbox_supported {[file executable $portutil::autoconf::sandbox_exec_path]}
default portsandbox_active {[expr $portsandbox_supported && $sandbox_enable]}
default portsandbox_profile {}

# set up a suitable profile to pass to sandbox-exec, based on the target
# command line usage would be:
# sandbox-exec -p '(version 1) (allow default) (deny file-write*) (allow file-write* <filter>)' some-command
proc portsandbox::set_profile {target} {
    global os.major portsandbox_profile workpath distpath altprefix \
        package.destpath configure.ccache ccache_dir rpm.srcdir rpm.tmpdir

    switch $target {
        activate -
        deactivate -
        dmg -
        mdmg -
        load -
        unload {
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
            set allow_dirs [list ${package.destpath}]
        }
        rpm -
        srpm {
            set allow_dirs [list ${rpm.srcdir} ${rpm.tmpdir}]
        }
    }

    # TODO: remove altprefix support
    lappend allow_dirs $workpath $altprefix
    if {${configure.ccache}} {
        lappend allow_dirs $ccache_dir
    }

    set portsandbox_profile "(version 1) (allow default) (deny file-write*) \
(allow file-write-data (literal \"/dev/null\") (literal \"/dev/zero\") \
(literal \"/dev/dtracehelper\") (literal \"/dev/tty\") \
(literal \"/dev/stdin\") (literal \"/dev/stdout\") (literal \"/dev/stderr\") \
(regex #\"^/dev/fd/\")) (allow file-write* \
(regex #\"^(/private)?(/var)?/tmp/\" #\"^(/private)?/var/folders/\"))"

    foreach dir $allow_dirs {
        append portsandbox_profile " (allow file-write* ("
        if {${os.major} > 9} {
            append portsandbox_profile "subpath \"${dir}\"))"
        } else {
            append portsandbox_profile "regex #\"^${dir}/\"))"
        }
    }
}
