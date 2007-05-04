# et:ts=4
# portextract.tcl
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

package provide portextract 1.0
package require portutil 1.0

set org.macports.extract [target_new org.macports.extract extract_main]
target_init ${org.macports.extract} extract_init
target_provides ${org.macports.extract} extract
target_requires ${org.macports.extract} fetch checksum
target_prerun ${org.macports.extract} extract_start

# define options
options extract.only
commands extract

# Set up defaults
# XXX call out to code in portutil.tcl XXX
# This cleans the distfiles list of all site tags
default extract.only {[disttagclean $distfiles]}

default extract.dir {${workpath}}
default extract.cmd gzip
default extract.pre_args -dc
default extract.post_args {"| ${portutil::autoconf::tar_command} -xf -"}

set_ui_prefix

proc extract_init {args} {
    global extract.only extract.dir extract.cmd extract.pre_args extract.post_args distfiles use_bzip2 use_zip workpath
    
    if {[tbool use_bzip2]} {
	option extract.cmd [binaryInPath "bzip2"]
    } elseif {[tbool use_zip]} {
	option extract.cmd [binaryInPath "unzip"]
	option extract.pre_args -q
	option extract.post_args "-d [option extract.dir]"
    }
}

proc extract_start {args} {
    global UI_PREFIX
    
    ui_msg "$UI_PREFIX [format [msgcat::mc "Extracting %s"] [option portname]]"
}

proc extract_main {args} {
    global UI_PREFIX
    
    if {![exists distfiles] && ![exists extract.only]} {
	# nothing to do
	return 0
    }
    
    foreach distfile [option extract.only] {
	ui_info "$UI_PREFIX [format [msgcat::mc "Extracting %s"] $distfile]"
	option extract.args "[option distpath]/$distfile"
	if {[catch {command_exec extract} result]} {
	    return -code error "$result"
	}
    }
    return 0
}
