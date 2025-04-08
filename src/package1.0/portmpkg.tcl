# et:ts=4
# portmpkg.tcl
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
    global package.flat os.major package.destpath subport epoch version revision
    if {!${package.flat} || ${os.major} < 10} {
        # Make sure the destination path exists.
        file mkdir ${package.destpath}
    }

    return [package_mpkg $subport $epoch $version $revision]
}

proc portmpkg::archcheck {mport dependent_mport} {
    set portinfo [mport_info $mport]
    if {[dict exists $portinfo installs_libs] && ![dict get $portinfo installs_libs]} {
        return 1
    }
    set skip_archcheck [_mportkey $dependent_mport depends_skip_archcheck]
    if {[lsearch -exact -nocase $skip_archcheck [dict get $portinfo name]] >= 0} {
        return 1
    }
    set required_archs [_mport_archs $dependent_mport]
    if {[_mport_supports_archs $mport $required_archs]} {
        return 1
    }
    # Since only depends_lib and depends_run are considered in mpkg,
    # there's no need to check if the dep type needs matching archs.
    return 0
}

proc portmpkg::get_dependencies {mport dep_map base_options variations} {
    set portinfo [mport_info $mport]
    set portname [dict get $portinfo name]
    if {![dict exists $dep_map $portname]} {
        # guard against infinite recursion with circular dependencies
        dict set dep_map $portname {}
    }

    # get the union of depends_run and depends_lib
    set depends [list]
    if {[dict exists $portinfo depends_run]} { lappend depends {*}[dict get $portinfo depends_run] }
    if {[dict exists $portinfo depends_lib]} { lappend depends {*}[dict get $portinfo depends_lib] }

    foreach depspec $depends {
        set dep [_get_dep_port $depspec]
        if {$dep ne ""} {
            # Get the dep's mport handle, opening it if needed
            if {[catch {set res [mport_lookup $dep]} error]} {
                ui_debug $::errorInfo
                return -code error "port lookup failed: $error"
            }
            # depname will have canonical case and so can safely be
            # used as the dict key
            lassign $res depname dep_portinfo
            set add_deps 0
            if {[dict exists $dep_map $depname]} {
                set dep_mport [dict get $dep_map $depname]
                # The dep has already been processed, so there's
                # nothing to do in this case if the archs match.
            } else {
                set options $base_options
                dict set options subport $depname
                exec_with_available_privileges {
                    set dep_mport [mport_open [dict get $dep_portinfo porturl] $options $variations]
                }
                set add_deps 1
            }
            # Reopen with +universal if possible if the archs aren't compatible
            if {![archcheck $dep_mport $mport] && ![dict exists $variations universal]} {
                set check_portinfo [mport_info $dep_mport]
                set dep_archs [_mport_archs $dep_mport]
                if {[dict exists $check_portinfo variants] && "universal" in [dict get $check_portinfo variants]
                        && [llength $dep_archs] < 2} {
                    mport_close $dep_mport
                    set uvariations $variations
                    dict set uvariations universal +
                    set options $base_options
                    dict set options subport $depname
                    exec_with_available_privileges {
                        set dep_mport [mport_open [dict get $dep_portinfo porturl] $options $uvariations]
                    }
                    set add_deps 1
                    # dep_map entry for this dep will be updated in the recursive call
                }
            }
            if {$add_deps} {
                # Add this dependency and its dependencies to the dep_map
                set dep_map [get_dependencies $dep_mport $dep_map $base_options $variations]
            }
        }
    }

    # ensure this port comes after its deps in the dict
    dict unset dep_map $portname
    dict set dep_map $portname [list $mport [dict get $portinfo version] [dict get $portinfo revision]]
    return $dep_map
}

proc portmpkg::make_dependency_list {portname destination} {
    global prefix package.flat requested_variations

    if {[catch {set res [mport_lookup $portname]} error]} {
        ui_debug $::errorInfo
        return -code error "port lookup failed: $error"
    }
    lassign $res portname portinfo
    set base_options [dict create prefix $prefix package.destpath ${destination} package.flat ${package.flat}]
    set options $base_options
    dict set options subport $portname
    set variations [array get requested_variations]

    exec_with_available_privileges {
        set mport [mport_open [dict get $portinfo porturl] $options $variations]
    }

    set result [get_dependencies $mport [dict create] $base_options $variations]
    mport_close $mport
    # don't re-package ourself
    dict unset result $portname

    return $result
}

proc portmpkg::make_one_package {portname mport} {
    ui_debug "building dependency package: $portname"
    exec_with_available_privileges {
        set result [mport_exec $mport pkg]
    }
    mport_close $mport
    if {$result} {
        error "Processing of port $portname failed"
    }
}

proc portmpkg::mpkg_path {portname portversion portrevision} {
    global package.destpath
    return ${package.destpath}/[portpkg::image_name ${portname} ${portversion} ${portrevision}].mpkg
}

proc portmpkg::package_mpkg {portname portepoch portversion portrevision} {
    global os.major workpath porturl description long_description homepage \
           package.flat package.destpath

    set mpkgpath [portmpkg::mpkg_path $portname $portversion $portrevision]

    if {${package.flat} && ${os.major} >= 10} {
        set pkgpath ${package.destpath}/[portpkg::image_name ${portname} ${portversion} ${portrevision}]-component.pkg
        set packages_path ${workpath}/mpkg_packages
        set resources_path ${workpath}/mpkg_resources
    } else {
        set pkgpath ${package.destpath}/[portpkg::image_name ${portname} ${portversion} ${portrevision}].pkg
        set packages_path ${mpkgpath}/Contents/Packages
        set resources_path ${mpkgpath}/Contents/Resources
    }
    xinstall -d -m 0755 ${packages_path} ${resources_path}

    set dependencies [list]
    # get deplist
    set deps [make_dependency_list $portname $packages_path]
    dict for {name depinfo} $deps {
        lassign $depinfo mport vers rev
        make_one_package $name $mport
        if {${package.flat} && ${os.major} >= 10} {
            lappend dependencies org.macports.${name} [portpkg::image_name ${name} ${vers} ${rev}]-component.pkg
        } else {
            lappend dependencies [portpkg::image_name ${name} ${vers} ${rev}].pkg
        }
    }
    if {${package.flat} && ${os.major} >= 10} {
        lappend dependencies org.macports.${portname} [portpkg::image_name ${portname} ${portversion} ${portrevision}]-component.pkg
    } else {
        lappend dependencies [portpkg::image_name ${portname} ${portversion} ${portrevision}].pkg
    }

    # copy our own pkg into the mpkg
    system "cp -PR [shellescape ${pkgpath}] [shellescape ${packages_path}]"

    if {!${package.flat} || ${os.major} < 10} {
        global prefix
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
    portpkg::write_welcome_html ${resources_path}/Welcome.html $portname $portversion $portrevision $pkg_long_description $pkg_description $pkg_homepage
    file copy -force -- [getportresourcepath $porturl "port1.0/package/background.tiff"] ${resources_path}/background.tiff

    if {${package.flat} && ${os.major} >= 10} {
        write_distribution ${workpath}/Distribution $portname $dependencies
        set productbuild [findBinary productbuild]
        set v [portpkg::mp_version_to_apple_version $portepoch $portversion $portrevision]
        set cmdline "$productbuild --resources [shellescape ${resources_path}] --identifier org.macports.mpkg.${portname} --distribution [shellescape ${workpath}/Distribution] --package-path [shellescape ${packages_path}] --version ${v} [shellescape ${mpkgpath}]"
        ui_debug "Running command line: $cmdline"
        system $cmdline
    }

    return 0
}

proc portmpkg::write_distribution {dfile portname dependencies} {
    # TODO: Set hostArchitectures. This requires calculating the intersection
    # of the archs of all the component pkgs.
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

    if {[string index $destination end] ne "/"} {
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
