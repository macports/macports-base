# eti:ts=4
# portbuild.tcl
# $Id$
#
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

package provide portbuild 1.0
package require portutil 1.0

set com.apple.build [target_new com.apple.build build_main]
target_provides ${com.apple.build} build
target_requires ${com.apple.build} main fetch extract checksum patch configure
target_prerun ${com.apple.build} build_start

# define options
options build.target
commands build
# defaults
default build.dir {${workpath}/${worksrcdir}}
default build.cmd {[build_getmaketype]}
default build.pre_args {${build.target}}
default build.target "all"

set_ui_prefix

proc build_getmaketype {args} {
    if {![exists build.type]} {
	return make
    }
    switch -exact -- [option build.type] {
	bsd {
	    if {[option os.platform] == "darwin"} {
		return bsdmake
	    } else {
		return make
	    }
	}
	gnu {
	    if {[option os.platform] == "darwin"} {
		return gnumake
	    } else {
		return gmake
	    }
	}
	pbx {
	    set pbxbuild "pbxbuild"
	    set xcodebuild "xcodebuild"
	    
	    if {[option os.platform] != "darwin"} {
		return -code error "[format [msgcat::mc "This port requires 'pbxbuild/xcodebuild', which is not available on %s."] [option os.platform]]"
	    }
	    
	    if {[catch {set xcodebuild [binaryInPath $xcodebuild]}] == 0} {
		return $xcodebuild
	    } elseif {[catch {set pbxbuild [binaryInPath $pbxbuild]}] == 0} {
		return $pbxbuild
	    } else {
  		return -code error "Neither pbxbuild nor xcodebuild were found on this system!"
  	    }
	}
	default {
	    ui_warn "[format [msgcat::mc "Unknown build.type %s, using 'gnumake'"] [option build.type]]"
	    return gnumake
	}
    }
}

proc build_start {args} {
    global UI_PREFIX
    
    if {[string length [option build.target]]} {
	ui_msg "$UI_PREFIX [format [msgcat::mc "Building %s with target %s"] [option portname] [option build.target]]"
    } else {
	ui_msg "$UI_PREFIX [format [msgcat::mc "Building %s"] [option portname]]"
    }
}

proc build_main {args} {
    command_exec build
    return 0
}
