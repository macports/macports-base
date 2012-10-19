# et:ts=4
# portsubmit.tcl
# $Id$
#
# Copyright (c) 2007 - 2011 The MacPorts Project
# Copyright (c) 2002 - 2004 Apple Inc.
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
# 3. Neither the name of Apple Inc. nor the names of its contributors
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
package require portportpkg 1.0

set org.macports.submit [target_new org.macports.submit portsubmit::submit_main]
target_runtype ${org.macports.submit} always
target_provides ${org.macports.submit} submit
target_requires ${org.macports.submit} portpkg

namespace eval portsubmit {
}

set_ui_prefix


# escape quotes, and things that make the shell cry
proc portsubmit::shell_escape {str} {
    regsub -all -- {\\} $str {\\\\} str
    regsub -all -- {"} $str {\"} str
    regsub -all -- {'} $str {\'} str
    return $str
}


proc portsubmit::submit_main {args} {
    global mp_remote_submit_url name version portverbose prefix UI_PREFIX workpath portpath

    set submiturl $mp_remote_submit_url

    # Preconditions for submit
    if {$submitter_email == ""} {
        return -code error [format [msgcat::mc "Submitter email is required to submit a port"]]
    }

    # Make sure we have a work directory
    file mkdir ${workpath}

    # Create portpkg.xar in the work directory
    set pkgpath "${workpath}/${name}.portpkg"

    # TODO: If a private key was provided, create a signed digest of the submission

    # Submit to the submit url
    set args "curl"
    lappend args "--silent"
    lappend args "--url ${submiturl}"
    lappend args "--output ${workpath}/.portsubmit.out"
    lappend args "-F machine=true"
    lappend args "-F portpkg=@${pkgpath}"
    #lappend args "-F signeddigest=${digest}"
    set cmd [join $args]

    if {[tbool portverbose]} {
        ui_notice "Submitting portpkg $pkgpath for $name to $submiturl"
    }

    # Invoke curl to do the submit
    ui_debug $cmd
    if {[system $cmd] != ""} {
        return -code error [format [msgcat::mc "Failure during submit of port %s"] $name]
    }

    # Parse the result
    set fd [open ${workpath}/.portsubmit.out r]
    array set result [list]
    while {[gets $fd line] != -1} {
        if {0 != [regexp -- {^([^:]+):\s*(.*)$} $line unused key value]} {
            set result($key) $value
        }
    }
    close $fd

    # Interpret and act on the result
    if {[info exists result(MESSAGE)] && [tbool portverbose]} {
        ui_notice $result(MESSAGE)
    }
    if {[info exists result(STATUS)]} {
        if { $result(STATUS) == 0 } {
            ui_notice "Submitted portpkg for $name"
            if {[info exists result(DOWNLOAD_URL)]} {
                ui_notice "    download URL => $result(DOWNLOAD_URL)"
            }
            if {[info exists result(HUMAN_URL)]} {
                ui_notice "    human readable URL => $result(HUMAN_URL)"
            }
        } else {
            return -code error [format [msgcat::mc "Status %d reported during submit of port %s"] $result(STATUS) $name]
        }
    } else {
        return -code error [format [msgcat::mc "Status not received during submit of port %s"] $name]
    }

    return

    # REMNANTS OF KEVIN'S CODE

    # start with the Portfile, and add the files directory if it exists.
    # don't pick up any CVS directories, or .DS_Store turds
    set cmd "tar czvf ${workpath}/Portfile.tar.gz "
    append cmd "--exclude CVS --exclude .DS_Store "
    append cmd "Portfile "
    if {[file isdirectory "files"]} {
        append cmd "files "
    }

    if {[system $cmd] != ""} {
    return -code error [format [msgcat::mc "Failed to archive port %s"] $name]
    }

    set portsource ""
    set base_rev ""
    if {![catch {set fd [open ".mports_source" r]}]} {
        while {[gets $fd line] != -1} {
            regexp -- {^(.*): (.*)$} $line unused key value
            switch -- $key {
                source { set portsource $value }
                revision { set base_rev $value }
            }
        }
        close $fd
    }
    if {$portsource == ""} {
        ui_notice "$UI_PREFIX Submitting $name-$version"
        puts -nonewline "URL: "
        flush stdout
        gets stdin portsource
    }

    ui_notice "$UI_PREFIX Submitting $name-$version to $portsource"

    puts -nonewline "Username: "
    flush stdout
    gets stdin username
    puts -nonewline "Password: "
    flush stdout
    exec stty -echo
    gets stdin password
    puts ""
    exec stty echo

    set vars {name version maintainers categories description \
        long_description master_sites}
    eval "global $vars"
    foreach var $vars {
        if {![info exists $var]} { set $var {} }
    }

    set cmd "curl "
    append cmd "--silent "
    append cmd "--url [regsub -- {^mports} $portsource {http}]/cgi-bin/portsubmit.cgi "
    append cmd "--output ${workpath}/.portsubmit.out "
    append cmd "-F name=${name} "
    append cmd "-F version=${version} "
    append cmd "-F base_rev=${base_rev} "
    append cmd "-F md5=[md5 file ${workpath}/Portfile.tar.gz] "
    append cmd "-F attachment=@${workpath}/Portfile.tar.gz "
    append cmd "-F \"submitted_by=[shell_escape $username]\" "
    append cmd "-F \"password=[shell_escape $password]\" "
    append cmd "-F \"maintainers=[shell_escape $maintainers]\" "
    append cmd "-F \"categories=[shell_escape $categories]\" "
    append cmd "-F \"description=[shell_escape $description]\" "
    append cmd "-F \"long_description=[shell_escape $long_description]\" "
    append cmd "-F \"master_sites=[shell_escape $master_sites]\" "

    ui_debug $cmd
    if {[system $cmd] != ""} {
    return -code error [format [msgcat::mc "Failed to submit port %s"] $name]
    }

    #
    # Parse the result from the remote index
    # if ERROR: print the error message
    # if OK: store the revision info
    # if CONFLICT: attempt to merge the conflict
    #

    set fd [open ${workpath}/.portsubmit.out r]
    array set result [list]
    while {[gets $fd line] != -1} {
        regexp -- {^(.*): (.*)$} $line unused key value
        set result($key) $value
    }
    close $fd

    if {[info exists result(OK)]} {
        set fd [open ".mports_source" w]
        puts $fd "source: $portsource"
        puts $fd "port: $name"
        puts $fd "version: $version"
        puts $fd "revision: $result(revision)"
        close $fd

        ui_notice "$name-$version submitted successfully."
        ui_notice "New revision: $result(revision)"
    } elseif {[info exists result(ERROR)]} {
        return -code error $result(ERROR)
    } elseif {[info exists result(CONFLICT)]} {
        # Fetch the newer revision from the index.
        # XXX: many gross hacks here regarding paths, urls, etc.
        set tmpdir [mktemp "/tmp/mports.XXXXXXXX"]
        file mkdir $tmpdir/new
        file mkdir $tmpdir/old
        set worker [mport_open $portsource/files/$name/$version/$result(revision)/Portfile.tar.gz [list portdir $tmpdir/new subport $name]]
        if {$base_rev != ""} {
            set worker2 [mport_open $portsource/files/$name/$version/$base_rev/Portfile.tar.gz [list portdir $tmpdir/old subport $name]]
            catch {system "diff3 -m -E -- $portpath/Portfile $tmpdir/old/$name-$version/Portfile $tmpdir/new/$name-$version/Portfile > $tmpdir/Portfile"}
            file rename -force "${tmpdir}/Portfile" "${portpath}/Portfile"
            mport_close $worker2
        } else {
            catch {system "diff3 -m -E -- $portpath/Portfile $portpath/Portfile $tmpdir/new/$name-$version/Portfile > $tmpdir/Portfile"}
            file rename -force "${tmpdir}/Portfile" "${portpath}/Portfile"
        }
        mport_close $worker
        catch {delete "${tmpdir}"}

        set fd [open [file join "$portpath" ".mports_source"] w]
        puts $fd "source: $portsource"
        puts $fd "port: $name"
        puts $fd "version: $version"
        puts $fd "revision: $result(revision)"
        close $fd

        ui_error "A newer revision of this port has already been submitted."
        ui_error "Portfile: $name-$version"
        ui_error "Base revision: $base_rev"
        ui_error "Current revision: $result(revision)"
        ui_error "Please edit the Portfile to resolve any conflicts and resubmit."
    }

    return 0
}
