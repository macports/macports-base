# et:ts=4
# portsubmit.tcl
#
# Copyright (c) 2002 - 2004 Apple Computer, Inc.
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

package provide portsubmit 1.0
package require portutil 1.0

set com.apple.submit [target_new com.apple.submit submit_main]
target_provides ${com.apple.submit} submit 
target_requires ${com.apple.submit} main

set_ui_prefix

# escape quotes, and things that make the shell cry
proc shell_escape {str} {
	regsub -all -- {\\} $str {\\\\} str
	regsub -all -- {"} $str {\"} str
	regsub -all -- {'} $str {\'} str
	return $str
}

proc submit_main {args} {
    global portname prefix UI_PREFIX workpath

    # start with the Portfile, and add the files directory if it exists.
    # don't pick up any CVS directories, or .DS_Store turds
    set cmd "tar czvf ${workpath}/Portfile.tar.gz "
    append cmd "--exclude CVS --exclude .DS_Store "
    append cmd "Portfile "
    if {[file isdirectory "files"]} {
        append cmd "files "
    }

    if {[system $cmd] != ""} {
	return -code error [format [msgcat::mc "Failed to archive port : %s"] $portname]
    }

    puts -nonewline "Username: "
    flush stdout
    gets stdin username
    puts -nonewline "Password: "
    flush stdout
    exec stty -echo
    gets stdin password
    puts ""
    exec stty echo
    
    global portname portversion maintainers categories description \
	long_description
    set cmd "curl "
    append cmd "--silent "
    append cmd "--url http://localhost/cgi-bin/portsubmit.cgi "
    append cmd "--output ${workpath}/.portsubmit.out "
    append cmd "-F name=${portname} "
    append cmd "-F version=${portversion} "
    append cmd "-F md5=[md5 file ${workpath}/Portfile.tar.gz] "
    append cmd "-F attachment=@${workpath}/Portfile.tar.gz "
    append cmd "-F \"submitted_by=[shell_escape $username]\" "
    append cmd "-F \"password=[shell_escape $password]\" "
    append cmd "-F \"maintainers=[shell_escape $maintainers]\" "
    append cmd "-F \"categories=[shell_escape $categories]\" "
    append cmd "-F \"description=[shell_escape $description]\" "
    append cmd "-F \"long_description=[shell_escape $long_description]\" "

    puts $cmd
    if {[system $cmd] != ""} {
	return -code error [format [msgcat::mc "Failed to submit port : %s"] $portname]
    }

    return 0
}
