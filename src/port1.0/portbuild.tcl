# ex:ts=4
# portbuild.tcl
#
# Copyright (c) 2002 Apple Computer, Inc.
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

package provide portbuild 1.0
package require portutil 1.0

register com.apple.build target build_main
register com.apple.build provides build 
register com.apple.build requires main fetch extract checksum patch configure
register com.apple.build deplist depends_build depends_lib

# define options
options build.target.all
commands build
# defaults
default build.dir {${workpath}/${worksrcdir}}
default build.cmd {[build_getmaketype]}
default build.pre_args {${build.target.current}}
default build.target.all all

set UI_PREFIX "---> "

proc build_getmaketype {args} {
    global build.type build.cmd os.name

    if ![info exists build.type] {
	return make
    }
    switch -exact -- ${build.type} {
	bsd {
	    if {${os.name} == "darwin"} {
		return bsdmake
	    } else {
		return make
	    }
	}
	gnu {
	    if {${os.name} == "darwin"} {
		return gnumake
	    } else {
		return gmake
	    }
	}
	pbx {
	    return pbxbuild
	}
	default {
	    ui_warning "Unknown build.type ${build.type}, using 'gnumake'"
	    return gnumake
	}
    }
}

proc build_main {args} {
    global portname portpath workdir prefix build.type build.cmd build.env build.target.all build.target.current UI_PREFIX worksrcdir

    ui_msg "$UI_PREFIX Building $portname with target ${build.target.all}"
    set build.target.current ${build.target.all}
    system "[command build]"
    return 0
}
