# et:ts=4
# portmpkg.tcl
# $Id$
#
# Copyright (c) 2005, 2007 - 2013 The MacPorts Project
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

package provide portmpkg 1.0
package require portutil 1.0

set org.macports.mpkg [target_new org.macports.mpkg portmpkg::mpkg_main]
target_runtype ${org.macports.mpkg} always
target_provides ${org.macports.mpkg} mpkg
target_requires ${org.macports.mpkg} pkg

namespace eval portmpkg {
}

# define options
options package.destpath package.flat

set_ui_prefix

proc portmpkg::mpkg_main {args} {
    global subport epoch version revision os.major package.destpath package.flat UI_PREFIX

    if {!${package.flat} || ${os.major} < 10} {
        # Make sure the destination path exists.
        file mkdir ${package.destpath}
    }

    return [package_mpkg $subport $epoch $version $revision]
}

proc portmpkg::make_dependency_list {portname destination} {
    global requested_variations prefix package.destpath package.flat
    set result {}
    if {[catch {set res [mport_lookup $portname]} error]} {
        global errorInfo
        ui_debug "$errorInfo"
        return -code error "port lookup failed: $error"
    }
    array set portinfo [lindex $res 1]

    if {[getuid] == 0 && [geteuid] != 0} {
        seteuid 0; setegid 0
        set deprivileged 1
    }

    set mport [mport_open $portinfo(porturl) [list prefix $prefix package.destpath ${destination} package.flat ${package.flat} subport $portinfo(name)] [array get requested_variations]]

    if {[info exists deprivileged]} {
        global macportsuser
        setegid [uname_to_gid "$macportsuser"]
        seteuid [name_to_uid "$macportsuser"]
    }

    unset portinfo
    array set portinfo [mport_info $mport]

    # get the union of depends_run and depends_lib
    set depends {}
    if {[info exists portinfo(depends_run)]} { eval "lappend depends $portinfo(depends_run)" }
    if {[info exists portinfo(depends_lib)]} { eval "lappend depends $portinfo(depends_lib)" }

    foreach depspec $depends {
        set dep [_get_dep_port $depspec]
        if {$dep != ""} {
            eval "lappend result [make_dependency_list $dep $destination]"
        }
    }

    lappend result [list $portinfo(name) $portinfo(epoch) $portinfo(version) $portinfo(revision) $mport]
    return $result
}

proc portmpkg::make_one_package {portname mport} {
    if {[getuid] == 0 && [geteuid] != 0} {
        seteuid 0; setegid 0
        set deprivileged 1
    }

    ui_debug "building dependency package: $portname"
    set result [mport_exec $mport pkg]
    mport_close $mport
    if {$result} {
        error "Processing of port $portname failed"
    }

    if {[info exists deprivileged]} {
        global macportsuser
        setegid [uname_to_gid "$macportsuser"]
        seteuid [name_to_uid "$macportsuser"]
    }
}

proc portmpkg::epoch_namestr {portepoch} {
    set portepoch_namestr ""
    if {${portepoch} != "0"} {
        set portepoch_namestr "${portepoch}_"
    }
    return ${portepoch_namestr}
}

proc portmpkg::revision_namestr {portrevision} {
    set portrevision_namestr ""
    if {${portrevision} != "0"} {
        set portrevision_namestr "_${portrevision}"
    }
    return ${portrevision_namestr}
}

proc portmpkg::mpkg_path {portname portepoch portversion portrevision} {
    global package.destpath
    set portepoch_namestr [portmpkg::epoch_namestr ${portepoch}]
    set portrevision_namestr [portmpkg::revision_namestr ${portrevision}]
    set mpkgpath ${package.destpath}/${portname}-${portepoch_namestr}${portversion}${portrevision_namestr}.mpkg
    return $mpkgpath
}

proc portmpkg::package_mpkg {portname portepoch portversion portrevision} {
    global portdbpath os.major destpath workpath prefix porturl description package.destpath package.flat long_description homepage depends_run depends_lib

    set mpkgpath [portmpkg::mpkg_path $portname $portepoch $portversion $portrevision]

    set portepoch_namestr [portmpkg::epoch_namestr ${portepoch}]
    set portrevision_namestr [portmpkg::revision_namestr ${portrevision}]
    if {${package.flat} && ${os.major} >= 10} {
        set pkgpath ${package.destpath}/${portname}-${portepoch_namestr}${portversion}${portrevision_namestr}-component.pkg
        set packages_path ${workpath}/mpkg_packages
        set resources_path ${workpath}/mpkg_resources
    } else {
        set pkgpath ${package.destpath}/${portname}-${portepoch_namestr}${portversion}${portrevision_namestr}.pkg
        set packages_path ${mpkgpath}/Contents/Packages
        set resources_path ${mpkgpath}/Contents/Resources
    }
    system "mkdir -p -m 0755 ${packages_path}"
    system "mkdir -p -m 0755 ${resources_path}"

    set dependencies {}
    # get deplist
    set deps [make_dependency_list $portname $packages_path]
    set deps [lsort -unique $deps]
    foreach dep $deps {
        set name [lindex $dep 0]
        set epoch [lindex $dep 1]
        set epoch_namestr ""
        if {$epoch != "0"} {
            set epoch_namestr "${epoch}_"
        }
        set vers [lindex $dep 2]
        set rev [lindex $dep 3]
        set rev_namestr ""
        if {$rev != "0"} {
            set rev_namestr "_${rev}"
        }
        set mport [lindex $dep 4]
        # don't re-package ourself
        if {$name != $portname} {
            make_one_package $name $mport
            if {${package.flat} && ${os.major} >= 10} {
                lappend dependencies org.macports.${name} ${name}-${epoch_namestr}${vers}${rev_namestr}-component.pkg
            } else {
                lappend dependencies ${name}-${epoch_namestr}${vers}${rev_namestr}.pkg
            }
        }
    }
    if {${package.flat} && ${os.major} >= 10} {
        lappend dependencies org.macports.${portname} ${portname}-${portepoch_namestr}${portversion}${portrevision_namestr}-component.pkg
    } else {
        lappend dependencies ${portname}-${portepoch_namestr}${portversion}${portrevision_namestr}.pkg
    }

    # copy our own pkg into the mpkg
    system "cp -PR ${pkgpath} ${packages_path}"

    if {!${package.flat} || ${os.major} < 10} {
        portpkg::write_PkgInfo ${mpkgpath}/Contents/PkgInfo
        mpkg_write_info_plist ${mpkgpath}/Contents/Info.plist $portname $portversion $portrevision $prefix $dependencies
        portpkg::write_description_plist ${mpkgpath}/Contents/Resources/Description.plist $portname $portversion $description
        set resources_path ${mpkgpath}/Contents/Resources
    }
    # long_description, description, or homepage may not exist
    foreach variable {long_description description homepage} {
        if {![info exists $variable]} {
            set pkg_$variable ""
        } else {
            set pkg_$variable [set $variable]
        }
    }
    portpkg::write_welcome_html ${resources_path}/Welcome.html $portname $portepoch $portversion $portrevision $pkg_long_description $pkg_description $pkg_homepage
    file copy -force -- [getportresourcepath $porturl "port1.0/package/background.tiff"] ${resources_path}/background.tiff

    if {${package.flat} && ${os.major} >= 10} {
        write_distribution ${workpath}/Distribution $portname $dependencies
        set productbuild [findBinary productbuild]
        set v [portpkg::mp_version_to_apple_version $portepoch $portversion $portrevision]
        set cmdline "$productbuild --resources ${resources_path} --identifier org.macports.mpkg.${portname} --distribution ${workpath}/Distribution --package-path ${packages_path} --version ${v} ${mpkgpath}"
        ui_debug "Running command line: $cmdline"
        system $cmdline
    }

    return 0
}

proc portmpkg::write_distribution {dfile portname dependencies} {
    global macosx_deployment_target
    set portname [xml_escape $portname]
    set dfd [open $dfile w+]
    puts $dfd "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<installer-gui-script minSpecVersion=\"1\">
    <title>${portname}</title>
    <options customize=\"never\"/>
    <allowed-os-versions><os-version min=\"${macosx_deployment_target}\"/></allowed-os-versions>
    <background file=\"background.tiff\" mime-type=\"image/tiff\" alignment=\"bottomleft\" scaling=\"none\"/>
    <welcome mime-type=\"text/html\" file=\"Welcome.html\"/>
    <choices-outline>
    <line choice=\"default\">
        <line choice=\"org.macports.mpkg.${portname}\"/>
    </line>
    </choices-outline>
    <choice id=\"default\"/>
    <choice id=\"org.macports.mpkg.${portname}\" visible=\"false\">
"
    foreach {identifier package} $dependencies {
        set id [xml_escape $identifier]
        set pkg [xml_escape $package]
        puts $dfd "        <pkg-ref id=\"${id}\"/>"
        lappend pkgrefs "<pkg-ref id=\"${id}\">${pkg}</pkg-ref>"
    }
    puts $dfd "    </choice>"
    foreach pkgref $pkgrefs {
        puts $dfd "    $pkgref"
    }
    puts $dfd "</installer-gui-script>"
    close $dfd
}

proc portmpkg::xml_escape {s} {
    regsub -all {&} $s {\&amp;} s
    regsub -all {<} $s {\&lt;} s
    regsub -all {>} $s {\&gt;} s
    return $s
}

proc portmpkg::mpkg_write_info_plist {infofile portname portversion portrevision destination dependencies} {
    set vers [split $portversion "."]

    if {[string index $destination end] != "/"} {
        append destination /
    }

    set depxml ""
    foreach dep $dependencies {
        set dep [xml_escape $dep]
        append depxml "<dict>
            <key>IFPkgFlagPackageLocation</key>
            <string>${dep}</string>
            <key>IFPkgFlagPackageSelection</key>
            <string>selected</string>
        </dict>
        "
    }

    set portname [xml_escape $portname]
    set portversion [xml_escape $portversion]
    set portrevision [xml_escape $portrevision]

    set infofd [open ${infofile} w+]
    puts $infofd {<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
}
    puts $infofd "<dict>
    <key>CFBundleGetInfoString</key>
    <string>${portname} ${portversion}</string>
    <key>CFBundleIdentifier</key>
    <string>org.macports.mpkg.${portname}</string>
    <key>CFBundleName</key>
    <string>${portname}</string>
    <key>CFBundleShortVersionString</key>
    <string>${portversion}</string>
    <key>IFMajorVersion</key>
    <integer>${portrevision}</integer>
    <key>IFMinorVersion</key>
    <integer>0</integer>
    <key>IFPkgFlagComponentDirectory</key>
    <string>./Contents/Packages</string>
    <key>IFPkgFlagPackageList</key>
    <array>
        ${depxml}</array>
    <key>IFPkgFormatVersion</key>
    <real>0.10000000149011612</real>
</dict>
</plist>"
    close $infofd
}
