# ex:ts=4
# portextract.tcl
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

package provide portextract 1.0
package require portutil 1.0

register com.apple.extract target extract_main
register com.apple.extract init extract_init
register com.apple.extract provides extract
register com.apple.extract requires fetch checksum depends_extract

# define options
options extract.only
commands extract

# Set up defaults
default extract.only {$distfiles}
default extract.dir {${portpath}/${workdir}}
default extract.cmd gzip
default extract.pre_args -dc
default extract.post_args {{| tar -xf -}}

set UI_PREFIX "---> "

proc extract_init {args} {
    global extract.only extract.cmd extract.pre_args extract.post_args distfiles use_bzip2 use_zip portpath workdir

    if [info exists use_bzip2] {
	set extract.cmd bzip2
    } elseif [info exists use_zip] {
	set extract.cmd unzip
	set extract.pre_args -q
	set extract.post_args "-d $portpath/$workdir"
    }
}

proc extract_main {args} {
    global portname portpath workdir distname distpath distfiles use_bzip2 extract.only extract.cmd extract.before_args extract.after_args extract.args UI_PREFIX

    if {![info exists distfiles] && ![info exists extract.only]} {
	# nothing to do
	return 0
    }

    ui_msg "$UI_PREFIX Extracting for $distname"

    foreach distfile ${extract.only} {
	ui_info "$UI_PREFIX Extracting $distfile ... " -nonewline
	set extract.args "$distpath/$distfile"
	if [catch {system "[command extract]"} result] {
	    ui_error "$result"
	    return -1
	}
	ui_info "Done"
    }
    return 0
}
