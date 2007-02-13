# et:ts=4
# portconfigure.tcl
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

package provide portconfigure 1.0
package require portutil 1.0

set com.apple.configure [target_new com.apple.configure configure_main]
target_provides ${com.apple.configure} configure
target_requires ${com.apple.configure} main fetch extract checksum patch
target_prerun ${com.apple.configure} configure_start

# define options
commands configure automake autoconf xmkmf libtool
# defaults
default configure.pre_args {--prefix=${prefix}}
default configure.cmd ./configure
default configure.dir {${worksrcpath}}
default autoconf.dir {${worksrcpath}}
default automake.dir {${worksrcpath}}
default xmkmf.cmd xmkmf
default xmkmf.dir {${worksrcpath}}
default use_configure yes

set_ui_prefix

proc configure_start {args} {
    global UI_PREFIX
    
    ui_msg "$UI_PREFIX [format [msgcat::mc "Configuring %s"] [option portname]]"
}

proc configure_main {args} {
    global [info globals]
    global configure configure.args configure.dir automake automake.env automake.args automake.dir autoconf autoconf.env autoconf.args autoconf.dir xmkmf libtool portname worksrcpath prefix workpath UI_PREFIX use_configure use_autoconf use_automake use_xmkmf
    
    if {[tbool use_automake]} {
	# XXX depend on automake
	if {[catch {system "[command automake]"} result]} {
	    return -code error "[format [msgcat::mc "%s failure: %s"] automake $result]"
	}
    }
    
    if {[tbool use_autoconf]} {
	# XXX depend on autoconf
	if {[catch {system "[command autoconf]"} result]} {
	    return -code error "[format [msgcat::mc "%s failure: %s"] autoconf $result]"
	}
    }
    
    if {[tbool use_xmkmf]} {
	# XXX depend on xmkmf
	if {[catch {system "[command xmkmf]"} result]} {
	    return -code error "[format [msgcat::mc "%s failure: %s"] xmkmf $result]"
	} else {
	    # XXX should probably use make command abstraction but we know that
	    # X11 will already set things up so that "make Makefiles" always works.
	    system "cd ${worksrcpath} && make Makefiles"
	}
    } elseif {[tbool use_configure]} {
	if {[catch {system "[command configure]"} result]} {
	    return -code error "[format [msgcat::mc "%s failure: %s"] configure $result]"
	}
    }
    return 0
}
