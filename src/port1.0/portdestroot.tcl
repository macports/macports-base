# et:ts=4
# portdestroot.tcl
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

package provide portdestroot 1.0
package require portutil 1.0

set com.apple.destroot [target_new com.apple.destroot destroot_main]
target_runtype ${com.apple.destroot} always
target_provides ${com.apple.destroot} destroot
target_requires ${com.apple.destroot} main fetch extract checksum patch configure build
target_prerun ${com.apple.destroot} destroot_start
target_postrun ${com.apple.destroot} destroot_finish

# define options
options destroot.target destroot.location destroot.clean
commands install

# Set defaults
default destroot.dir {${build.dir}}
default destroot.cmd {${build.cmd}}
default destroot.pre_args {${destroot.target}}
default destroot.target install
default destroot.post_args {${install.destroot}}
default destroot.location {DESTDIR=${destroot}}
default destroot.clean no

set UI_PREFIX "---> "

proc destroot_start {args} {
    global UI_PREFIX prefix portname destroot portresourcepath os.platform destroot.clean

    ui_msg "$UI_PREFIX [format [msgcat::mc "Staging %s into destroot"] ${portname}]"

    if { ${destroot.clean} == "yes" } {
	system "rm -Rf \"${destroot}\""
    }

    file mkdir "${destroot}"
    if { ${os.platform} == "darwin" } {
	system "cd \"${destroot}\" && mtree -d -e -U -f ${portresourcepath}/install/macosx.mtree"
    }
    file mkdir "${destroot}/${prefix}"
    system "cd \"${destroot}/${prefix}\" && mtree -d -e -U -f ${portresourcepath}/install/prefix.mtree"
}

proc destroot_main {args} {
    system "[command destroot]"
    return 0
}

proc destroot_finish {args} {
    global destroot

    # Prune empty directories in ${destroot}
    catch {system "find \"${destroot}\" -depth -type d -print | xargs rmdir 2>/dev/null"}
    return 0
}
