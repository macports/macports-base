# ex:ts=4
# portconfigure.tcl
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

package provide portconfigure 1.0
package require portutil 1.0

register com.apple.configure target configure_main configure_init
register com.apple.configure provides configure
register com.apple.configure requires main fetch extract checksum patch depends_build depends_lib

# define options
commands configure automake autoconf xmkmf libtool
# defaults
default configure.pre_args {--prefix=${prefix}}
default configure.cmd ./configure
default use_configure yes

set UI_PREFIX "---> "

proc configure_init {args} {
    return 0
}

proc configure_main {args} {
    global [info globals]
    global global configure configure.type configure.args configure.dir automake automake.env automake.args automake.dir autoconf autoconf.env autoconf.args autoconf.dir xmkmf libtool portname portpath workdir worksrcdir prefix workpath UI_PREFIX use_configure use_autoconf use_automake

    if [info exists configure.dir] {
	set configpath ${portpath}/${workdir}/${worksrcdir}/${configure.dir}
    } else {
	set configpath ${portpath}/${workdir}/${worksrcdir}
    }

    if [tbool use_automake] {
	# XXX depend on automake
	system "[command automake]"
    }

    if [tbool use_autoconf] {
	# XXX depend on autoconf
	system "[command autoconf]"
    }

    cd $configpath
    if [tbool use_configure] {
        ui_msg "$UI_PREFIX Running configure script"
	system "[command configure]"
    }
    return 0
}
