# et:ts=4
# portzip.tcl
#
# Copyright (c) 2003 Kevin Van Vechten <kevin@opendarwin.org>
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

PortTarget 1.0

name			org.opendarwin.extract.zip
#version		1.0
maintainers		kevin@opendarwin.org
description		Extract files using bzip2(1)
requires		checksum
provides		extract zip

proc set_defaults {args} {
	default extract.sufx .zip
	default extract.cmd unzip
	default extract.pre_args -q
	default extract.post_args {-d [option extract.dir]}
}

set UI_PREFIX "---> "

proc main {args} {
    global UI_PREFIX

    if {![exists distfile]} {
		# nothing to do
		return 0
    }
	
	set distfile [option distfile]
	if {![string match *.zip $distfile]} {
		ui_debug "skipping non-zip file: ${distfile}"
		# not one of our files
		return 1
	}
	
	ui_msg "$UI_PREFIX [format [msgcat::mc "Extracting %s"] $distfile] ... " -nonewline
	
	set distpath [option distpath]
	set dir [option extract.dir]
	set preargs [option extract.pre_args]
	set postargs [option extract.post_args]
	# XXX: fix this up when we have better default handling for "use"
	set preargs -q
	set postargs "-d ${dir}"
	
	ui_debug "cd \"${dir}\" && unzip ${preargs} \"${distpath}/${distfile}\" ${postargs}"
	if [catch {system "cd \"${dir}\" && unzip ${preargs} \"${distpath}/${distfile}\" ${postargs}"} result] {
		return -code error "$result"
	}

	ui_msg [msgcat::mc "Done"]

    return 0
}
