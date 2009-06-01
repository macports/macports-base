# portimagefile.tcl
# $Id$
#
# Copyright (c) 2009 The MacPorts Project
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
# 3. Neither the name of The MacPorts Project nor the names of its contributors
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

package provide portimagefile 1.0
package require portutil 1.0

set org.macports.imagefile [target_new org.macports.imagefile portimagefile::imagefile_main]
target_provides ${org.macports.imagefile} imagefile
target_requires ${org.macports.imagefile} main fetch checksum extract patch configure build destroot
target_prerun ${org.macports.imagefile} portimagefile::imagefile_start

namespace eval portimagefile {
}

set_ui_prefix

proc portimagefile::imagefile_start {args} {
    global UI_PREFIX name version revision portvariants
    ui_msg "$UI_PREFIX [format [msgcat::mc "Imaging %s @%s_%s%s"] $name $version $revision $portvariants]"

    return 0
}


proc portimagefile::imagefile_main {args} {
    global name version revision portvariants epoch destpath
    global workpath portpath
    set startpwd [pwd]
    if {[catch {_cd $destpath} err]} {
        ui_error $err
        return
    }
    if {[catch {set tarcmd [findBinary tar ${portutil::autoconf::tar_path}]} err]} {
        ui_error $err
        return
    }
    if {[catch {set bzipcmd [findBinary bzip2 ${portutil::autoconf::bzip2_path}]} err]} {
        ui_error $err
        return
    }
    set imageworkpath [file join $workpath image]
    file mkdir $imageworkpath
    ui_debug "Creating files.tar.bz2"
    if {[catch {system "$tarcmd -cvf - * | $bzipcmd -c > [file join $imageworkpath files.tar.bz2]"} err]} {
        ui_error $err
        return
    }
    # Copy Portfile into imageworkpath to be included in image file
    file copy [file join $portpath Portfile] [file join $imageworkpath "+PORTFILE"]
    create_image_receipt $imageworkpath
    _cd $imageworkpath
    set macport_filename [getportimagename_from_port_info $name $epoch $version $revision $portvariants]
    set macport_file [file join $workpath $macport_filename]
    ui_debug "Creating $macport_filename"
    if {[catch {system "$tarcmd -cvf $macport_file *"} err]} {
        ui_error $err
        return
    }

    install_register_imagefile $macport_file

    _cd $startpwd

    return 0
}


# Create a +IMAGERECEIPT file which contains all information necessary
# to register the port in the MacPorts registry
proc portimagefile::create_image_receipt {imageworkpath} {
    global name version revision portvariants epoch categories
    global homepage maintainers depends_run depends_lib prefix package-install
    global description long_description license destpath
    set fd [open [file join $imageworkpath "+IMAGERECEIPT"] w]
    set variablelist {name version revision portvariants epoch categories homepage maintainers depends_run depends_lib prefix package-install description long_description license}
    foreach onevar $variablelist {
        if {[info exists $onevar]} {
            puts $fd "$onevar [string map {\n \\n} [set $onevar]]"
        }
    }
    puts $fd "contents [filelist_for_path $destpath]"
    close $fd

    return 0
}


# Build up a list of information which describes each file within the
# destroot, which matches that information which is found in receipts.
proc portimagefile::filelist_for_path {startpath} {
    if {[string index $startpath end] == "/"} {
        set startpath [string range $startpath 0 end-1]
    }
    set filelist {}
    fs-traverse element $startpath {
        if {![file isdirectory $element]} {
            # registry_fileinfo_for_file only works on files which exist
            # so we must run it against the stuff in the destroot, then strip
            # out that path to get to what will be the final install path
            set fileinfo [registry_fileinfo_for_file $element]
            lappend filelist [regsub -all "$startpath" $fileinfo ""]
        }
    }

    return $filelist
}


# Install (copy to portimagefilepath) an imagefile and register
# it as installed in the MacPorts registry.  This makes no assumptions
# about how the imagefile was created/acquired
proc portimagefile::install_register_imagefile {imagefile} {
    global env portimagefilepath prefix
    if {[info exists env(TMPDIR)]} {
        set mytempdir [mkdtemp [file join $env(TMPDIR) mpimageXXXXXXXX]]
    } else {
        set mytempdir [mkdtemp [file join /tmp mpimageXXXXXXXX]]
    }
    set startpwd [pwd]
    try {
        if {[catch {_cd $mytempdir} err]} {
            throw MACPORTS $err
        }
        if {[catch {set tarcmd [findBinary tar ${portutil::autoconf::tar_path}]} err]} {
            throw MACPORTS $err
        }
        if {[catch {system "$tarcmd -xvf $imagefile +IMAGERECEIPT"} err]} {
            throw MACPORTS $err
        }
        if {[catch {set fd [open "+IMAGERECEIPT" r]} err]} {
            throw MACPORTS "Can't open image receipt: $err"
        }
        array set imagevars [list]
        while {[gets $fd line] >= 0} {
            set imagevars([lindex $line 0]) [lrange $line 1 end]
        }
        close $fd
        set requiredvars {name version revision portvariants epoch categories contents prefix}
        foreach required $requiredvars {
            if {![info exists imagevars($required)]} {
                throw MACPORTS "Image receipt missing required variable $required"
            }
        }

        if {$imagevars(prefix) != $prefix} {
            throw MACPORTS "Image prefix ($imagevars(prefix)) does not match ours ($prefix)"
        }
        set portimagepath [file join ${portimagefilepath} $imagevars(name)]
        if {![file isdirectory $portimagepath]} {
            file mkdir $portimagepath
        }
        ui_debug "Installing and registering [file tail $imagefile]"
        file copy -force $imagefile $portimagepath

        set regref [registry_new $imagevars(name) $imagevars(version) $imagevars(revision) $imagevars(portvariants) $imagevars(epoch)]
        registry_prop_store $regref categories $imagevars(categories)
        registry_prop_store $regref contents $imagevars(contents)
        foreach propname [array names imagevars] {
            if {[lsearch -exact $requiredvars $propname] >= 0} {
                continue
            }
            registry_prop_store $regref $propname $imagevars($propname)
            if {[lsearch -exact {depends_run depends_lib} $propname] != -1} {
               registry_register_deps $imagevars($propname) $imagevars(name)
            }
        }
        registry_write $regref
    } catch {* errorCode errorMessage } {
        ui_error $errorMessage
    } finally {
        _cd $startpwd
        file delete -force $mytempdir
    }

    return 0
}

