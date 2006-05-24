# et:ts=4
# portmirror.tcl
#
# $Id: portmirror.tcl,v 1.1 2006/05/24 00:42:56 pguyot Exp $
#
# Copyright (c) 2006 Paul Guyot <pguyot@kallisys.net>,
# All rights reserved.
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
# 3. Neither the name of Apple Computer, Inc. nor the names of its
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
#

package provide portmirror 1.0
package require portutil 1.0
package require portfetch 1.0
package require portchecksum 1.0

set com.apple.mirror [target_new com.apple.mirror mirror_main]
target_runtype ${com.apple.mirror} always
target_state ${com.apple.mirror} no
target_provides ${com.apple.mirror} mirror
target_requires ${com.apple.mirror} main
#target_parallel ${com.apple.mirror} yes

# Mirror is a target that fetches & checksums files and delete them
# if the checksum isn't correct.

proc mirror_main {args} {
	global fetch.type portname
	
	# Check the distfiles if it's a regular fetch phase.
	if {"${fetch.type}" == "standard"} {
		# fetch the files.
		fetch_init $args
		#fetch_start $args
		fetch_main $args

		# checksum the files.
		#checksum_start $args
		if {[catch {checksum_main $args}]} {
			# delete the files.
			fetch_deletefiles $args
		}
	}
}
