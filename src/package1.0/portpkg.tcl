# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# portpkg.tcl
#
# Copyright (c) 2005, 2007-2014, 2016-2018 The MacPorts Project
# Copyright (c) 2002-2003 Apple Inc.
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

package provide portpkg 1.0
package require portutil 1.0

set org.macports.pkg [target_new org.macports.pkg portpkg::pkg_main]
target_runtype ${org.macports.pkg} always
target_provides ${org.macports.pkg} pkg
target_requires ${org.macports.pkg} archivefetch unarchive destroot
target_prerun ${org.macports.pkg} portpkg::pkg_start

namespace eval portpkg {
}

# define options
options package.type package.destpath package.flat package.resources package.scripts
options pkg.asroot

# Set defaults
default package.destpath {${workpath}}
default package.resources {${workpath}/pkg_resources}
default package.scripts  {${workpath}/pkg_scripts}
# Need productbuild to make flat packages really work
default package.flat     {[expr {[vercmp $macosx_deployment_target 10.6] >= 0}]}
default pkg.asroot no

set_ui_prefix

proc portpkg::pkg_start {args} {
    global packagemaker_path portpkg::packagemaker portpkg::pkgbuild \
           portpkg::language xcodeversion portpath porturl \
           package.resources package.scripts package.flat \
           subport version revision description long_description \
           homepage workpath os.major

    if {[catch {findBinary pkgbuild /usr/bin/pkgbuild} pkgbuild]} {
        set pkgbuild ""
    }
    if {$pkgbuild eq "" || !${package.flat}} {
        # can't use pkgbuild, so fall back to PackageMaker
        if {![info exists packagemaker_path]} {
            if {[vercmp $xcodeversion 4.3] >= 0} {
                set packagemaker_path /Applications/PackageMaker.app
                if {![file exists $packagemaker_path]} {
                    ui_warn "PackageMaker.app not found; you may need to install it or set packagemaker_path in macports.conf"
                }
            } else {
                set packagemaker_path "[option developer_dir]/Applications/Utilities/PackageMaker.app"
            }
        }
        set packagemaker "${packagemaker_path}/Contents/MacOS/PackageMaker"
    }

    set language "English"
    file mkdir "${package.resources}/${language}.lproj"
    file attributes "${package.resources}/${language}.lproj" -permissions 0755
    file mkdir ${package.scripts}
    file attributes ${package.scripts} -permissions 0755

    # long_description, description, or homepage may not exist
    foreach variable {long_description description homepage} {
        if {![info exists $variable]} {
            set pkg_$variable ""
        } else {
            set pkg_$variable [set $variable]
        }
    }
    write_welcome_html ${package.resources}/${language}.lproj/Welcome.html $subport $version $revision $pkg_long_description $pkg_description $pkg_homepage
    file copy -force -- [getportresourcepath $porturl "port1.0/package/background.tiff"] ${package.resources}/${language}.lproj/background.tiff

    if {${package.flat} && ${os.major} >= 9} {
        write_distribution "${workpath}/Distribution" $subport $version $revision
    }
}

proc portpkg::pkg_main {args} {
    global subport epoch version revision UI_PREFIX

    if {[getuid] == 0 && [geteuid] != 0} {
        elevateToRoot "pkg"
    }

    return [package_pkg $subport $epoch $version $revision]
}

proc portpkg::package_pkg {portname portepoch portversion portrevision} {
    global UI_PREFIX portdbpath destpath workpath prefix description \
    package.flat package.destpath portpath os.version os.major \
    package.resources package.scripts portpkg::packagemaker \
    pkg_post_unarchive_deletions portpkg::language portpkg::pkgbuild

    set pkgpath "${package.destpath}/[image_name $portname $portversion $portrevision].pkg"

    ui_msg "$UI_PREFIX [format [msgcat::mc "Creating pkg for %s version %s_%s_%s at %s"] ${portname} ${portepoch} ${portversion} ${portrevision} ${pkgpath}]"

    if {[file readable $pkgpath] && ([file mtime ${pkgpath}] >= [file mtime ${portpath}/Portfile])} {
        ui_msg "$UI_PREFIX [format [msgcat::mc "Package for %s version %s_%s_%s at %s is up-to-date"] ${portname} ${portepoch} ${portversion} ${portrevision} ${pkgpath}]"
        return 0
    }

    foreach dir {etc var tmp} {
        if {[file exists "${destpath}/$dir"]} {
            # certain toplevel directories really are symlinks. leaving them as directories make pax lose the symlinks. that's bad.
            file mkdir "${destpath}/private/${dir}"
            file rename {*}[glob ${destpath}/${dir}/*] "${destpath}/private/${dir}"
            delete "${destpath}/${dir}"
        }
    }

    if {[info exists pkg_post_unarchive_deletions]} {
        foreach rmfile ${pkg_post_unarchive_deletions} {
            set full_rmfile "${destpath}${prefix}/${rmfile}"
            if {[file exists "${full_rmfile}"]} {
                delete "${full_rmfile}"
            }
        }
    }

    set using_pkgbuild [expr {$pkgbuild ne "" && ${package.flat}}]
    if {$using_pkgbuild || [file exists "$packagemaker"]} {
        if {${os.major} >= 9} {
            if {${package.flat}} {
                set pkgtarget "10.5"
                set pkgresources " --scripts [shellescape ${package.scripts}]"
                set infofile "${workpath}/PackageInfo"
                write_package_info $infofile
            } else {
                set pkgtarget "10.3"
                set pkgresources " --resources [shellescape ${package.resources}] --title \"$portname-$portversion\""
                set infofile "${workpath}/Info.plist"
                write_info_plist $infofile $portname $portversion $portrevision
            }
            if {$using_pkgbuild} {
                set cmdline "$pkgbuild --root [shellescape ${destpath}] ${pkgresources} --info [shellescape $infofile] --install-location / --identifier org.macports.$portname"
            } else {
                set cmdline "PMResourceLocale=${language} $packagemaker --root [shellescape ${destpath}] --out [shellescape ${pkgpath}] ${pkgresources} --info [shellescape $infofile] --target $pkgtarget --domain system --id org.macports.$portname"
            }
            if {${os.major} >= 10} {
                set v [mp_version_to_apple_version $portepoch $portversion $portrevision]
                append cmdline " --version $v"
                if {!$using_pkgbuild} {
                    append cmdline " --no-relocate"
                } else {
                    append cmdline " ${pkgpath}"
                }
            } else {
                # 10.5 Leopard does not use current language, manually specify
                append cmdline " -AppleLanguages \"(${language})\""
            }
            ui_debug "Running command line: $cmdline"
            system $cmdline

            if {${package.flat} && ${os.major} >= 10} {
                # the package we just built is just a component
                set componentpath "[file rootname ${pkgpath}]-component.pkg"
                file rename -force ${pkgpath} ${componentpath}
                # Generate a distribution
                set productbuild [findBinary productbuild]
                set cmdline "$productbuild --resources [shellescape ${package.resources}] --identifier org.macports.${portname} --distribution [shellescape ${workpath}/Distribution] --package-path [shellescape ${package.destpath}] [shellescape ${pkgpath}]"
                ui_debug "Running command line: $cmdline"
                system $cmdline
            }
        } else {
            write_info_plist ${workpath}/Info.plist $portname $portversion $portrevision
            write_description_plist ${workpath}/Description.plist $portname $portversion $description
            system "$packagemaker -build -f [shellescape ${destpath}] -p [shellescape ${pkgpath}] -r [shellescape ${package.resources}] -i [shellescape ${workpath}/Info.plist] -d [shellescape ${workpath}/Description.plist]"
        }

        file delete ${workpath}/Info.plist \
                    ${workpath}/PackageInfo \
                    ${workpath}/Distribution \
                    ${workpath}/Description.plist
        file delete -force ${package.resources} \
                           ${package.scripts}

    } else {

        file mkdir ${pkgpath}/Contents/Resources
        foreach f [glob -directory ${package.resources} *] {
            file copy -force -- $f ${pkgpath}/Contents/Resources
        }

        write_PkgInfo ${pkgpath}/Contents/PkgInfo
        write_info_plist ${pkgpath}/Contents/Info.plist $portname $portversion $portrevision

        system "[findBinary mkbom $portutil::autoconf::mkbom_path] [shellescape ${destpath}] [shellescape ${pkgpath}/Contents/Archive.bom]"
        system -W ${destpath} "[findBinary pax $portutil::autoconf::pax_path] -x cpio -w -z . > [shellescape ${pkgpath}/Contents/Archive.pax.gz]"

        write_description_plist ${pkgpath}/Contents/Resources/Description.plist $portname $portversion $description
        write_sizes_file ${pkgpath}/Contents/Resources/Archive.sizes ${pkgpath} ${destpath}

    }

    foreach dir {etc var tmp} {
        if {[file exists "${destpath}/private/$dir"]} {
            # restore any directories that were moved, to avoid confusing the rest of the ports system.
            file rename ${destpath}/private/$dir ${destpath}/$dir
        }
    }
    catch {file delete ${destpath}/private}

    return 0
}

proc portpkg::image_name {portname portversion portrevision} {
    set ret "${portname}-${portversion}"
    if {${portrevision} != 0} {
        append ret "_${portrevision}"
    }
    return $ret
}

proc portpkg::write_PkgInfo {infofile} {
    set infofd [open ${infofile} w+]
    puts $infofd "pmkrpkg1"
    close $infofd
}

proc portpkg::xml_escape {s} {
    regsub -all {&} $s {\&amp;} s
    regsub -all {<} $s {\&lt;} s
    regsub -all {>} $s {\&gt;} s
    return $s
}

proc portpkg::write_info_plist {infofile portname portversion portrevision} {
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
    <string>org.macports.${portname}</string>
    <key>CFBundleName</key>
    <string>${portname}</string>
    <key>CFBundleShortVersionString</key>
    <string>${portversion}</string>
    <key>IFMajorVersion</key>
    <integer>${portrevision}</integer>
    <key>IFMinorVersion</key>
    <integer>0</integer>
    <key>IFPkgFlagAllowBackRev</key>
    <true/>
    <key>IFPkgFlagAuthorizationAction</key>
    <string>RootAuthorization</string>
    <key>IFPkgFlagDefaultLocation</key>
    <string>/</string>
    <key>IFPkgFlagInstallFat</key>
    <false/>
    <key>IFPkgFlagIsRequired</key>
    <false/>
    <key>IFPkgFlagRelocatable</key>
    <false/>
    <key>IFPkgFlagRestartAction</key>
    <string>NoRestart</string>
    <key>IFPkgFlagRootVolumeOnly</key>
    <true/>
    <key>IFPkgFlagUpdateInstalledLanguages</key>
    <false/>
    <key>IFPkgFormatVersion</key>
    <real>0.10000000149011612</real>
</dict>
</plist>"
    close $infofd
}

proc portpkg::write_description_plist {infofile portname portversion description} {
    set portname [xml_escape $portname]
    set portversion [xml_escape $portversion]
    set description [xml_escape $description]

    set infofd [open ${infofile} w+]
    puts $infofd {<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    }
    puts $infofd "<dict>
    <key>IFPkgDescriptionDeleteWarning</key>
    <string></string>
    <key>IFPkgDescriptionDescription</key>
    <string>${description}</string>
    <key>IFPkgDescriptionTitle</key>
    <string>${portname}</string>
    <key>IFPkgDescriptionVersion</key>
    <string>${portversion}</string>
</dict>
</plist>"
    close $infofd
}

proc portpkg::write_welcome_html {filename portname portversion portrevision long_description description homepage} {
    set fd [open ${filename} w+]
    if {$long_description eq ""} {
        set long_description $description
    }

    set portname [xml_escape $portname]
    set portversion [xml_escape $portversion]
    if {$portrevision != 0} {
        set portrevision [xml_escape $portrevision]
        set portrevision_str "_${portrevision}"
    } else {
        set portrevision ""
        set portrevision_str ""
    }
    set long_description [xml_escape $long_description]
    set description [xml_escape $description]
    set homepage [xml_escape $homepage]

    puts $fd "
<html lang=\"en\">
<head>
    <meta http-equiv=\"content-type\" content=\"text/html; charset=iso-8859-1\">
    <title>Install ${portname}</title>
</head>
<body>
<font face=\"Helvetica\"><b>Welcome to the ${portname} for macOS Installer</b></font>
<p>
<font face=\"Helvetica\">${long_description}</font>
<p>"

    if {$homepage ne ""} {
        puts $fd "<font face=\"Helvetica\"><a href=\"${homepage}\">${homepage}</a></font><p>"
    }

    puts $fd "<font face=\"Helvetica\">This installer guides you through the steps necessary to install ${portname} ${portversion}${portrevision_str} for macOS. To get started, click Continue.</font>
</body>
</html>"

    close $fd
}

proc portpkg::write_sizes_file {sizesfile pkgpath destpath} {

    if {[catch {set numFiles [llength [split [exec [findBinary lsbom $portutil::autoconf::lsbom_path] -s ${pkgpath}/Contents/Archive.bom] "\n"]]} result]} {
        return -code error [format [msgcat::mc "Reading package bom failed: %s"] $result]
    }
    if {[catch {set compressedSize [expr {[dirSize ${pkgpath}] / 1024}]} result]} {
        return -code error [format [msgcat::mc "Error determining compressed size: %s"] $result]
    }
    if {[catch {set installedSize [expr {[dirSize ${destpath}] / 1024}]} result]} {
        return -code error [format [msgcat::mc "Error determining installed size: %s"] $result]
    }
    if {[catch {set infoSize [file size ${pkgpath}/Contents/Info.plist]} result]} {
       return -code error [format [msgcat::mc "Error determining plist file size: %s"] $result]
    }
    if {[catch {set bomSize [file size ${pkgpath}/Contents/Archive.bom]} result]} {
        return -code error [format [msgcat::mc "Error determining bom file size: %s"] $result]
    }
    incr installedSize $infoSize
    incr installedSize $bomSize

    set fd [open ${sizesfile} w+]
    puts $fd "NumFiles $numFiles
InstalledSize $installedSize
CompressedSize $compressedSize"
    close $fd
}

proc portpkg::write_package_info {infofile} {
    set infofd [open ${infofile} w+]
    puts $infofd "
<pkg-info install-location=\"/\" relocatable=\"false\" auth=\"root\">
</pkg-info>"
    close $infofd
}

proc portpkg::write_distribution {dfile portname portversion portrevision} {
    global macosx_deployment_target
    set portname_e [xml_escape $portname]
    set dfd [open $dfile w+]
    puts $dfd "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<installer-gui-script minSpecVersion=\"1\">
    <title>${portname_e}</title>
    <options customize=\"never\"/>
    <allowed-os-versions><os-version min=\"${macosx_deployment_target}\"/></allowed-os-versions>
    <background file=\"background.tiff\" mime-type=\"image/tiff\" alignment=\"bottomleft\" scaling=\"none\"/>
    <welcome mime-type=\"text/html\" file=\"Welcome.html\"/>
    <choices-outline>
        <line choice=\"default\">
            <line choice=\"org.macports.${portname_e}\"/>
        </line>
    </choices-outline>
    <choice id=\"default\"/>
    <choice id=\"org.macports.${portname_e}\" visible=\"false\">
        <pkg-ref id=\"org.macports.${portname_e}\"/>
    </choice>
    <pkg-ref id=\"org.macports.${portname_e}\">[xml_escape [image_name ${portname} ${portversion} ${portrevision}]]-component.pkg</pkg-ref>
</installer-gui-script>
"
    close $dfd
}

# To create Apple packages, Apple version numbers consist of three
# period separated integers [1][2].  Munki supports any number of
# integers [3], so incorporate the port epoch, version and revision
# numbers in the Apple package version number so that Munki can do
# upgrades.  The Apple package number consists of the port epoch
# number followed by the port version number followed by the port
# revision number.
#
# Munki also requires that version numbers only consist of integers
# and periods.  So replace all non-periods and non-digits in the
# version number with periods so that any digits following the
# non-digits can properly version the package.
#
# There is an edge case when upstream releases a new version which
# adds an additional integer to its version number and the Portfile's
# revision number is reset to 0.  For example, aspell epoch 0,
# upstream 0.60.6, revision 4 was updated to epoch 0, upstream
# 0.60.6.1, revision 0, which maps to 0.60.6.4 and 0.60.6.1.0
# respectively, but the new Apple package version number is less than
# the old one.  To handle this, all upstream version numbers are
# mapped to seven period separated integers, appending 0 as necessary.
# Six was the largest number of integers in all upstream version
# numbers as of January 2013 [4], so add one to make space for
# trailing [a-zA-Z] in the upstream version number.  This generates a
# fixed format version number that will correctly upgrade the package,
# e.g. 0.60.6.4.0.0.0.0.4 and 0.60.6.1.0.0.0.1 for aspell.
#
# [1] https://developer.apple.com/library/mac/#documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html#//apple_ref/doc/uid/TP40009249-SW1
# [2] https://developer.apple.com/library/mac/#documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html#//apple_ref/doc/uid/TP40009249-SW1
# [3] https://groups.google.com/d/msg/munki-dev/-DCERUz6rrM/zMbY6iimIGwJ
# [4] https://lists.macports.org/pipermail/macports-dev/2013-January/021477.html
proc portpkg::mp_version_to_apple_version {portepoch portversion portrevision} {
    # Assume that portepoch and portrevision are non-negative integers
    # so they do not need to be specially handled like the upstream
    # version number.
    set v $portversion

    # Replace all non-period and non-digit characters with a period.
    regsub -all -- {[^.0-9]+} $v . v

    # Replace two or more consecutive periods with a single period.
    regsub -all -- {[.]+} $v . v

    # Trim trailing periods.
    regsub -- {[.]+$} $v {} v

    # Split the string into a list of integers.
    set vs [split $v {.}]

    # If the upstream version number ends in [a-zA-Z]+, e.g. openssl's
    # 1.0.1c, then treat the trailing characters as a base 26 number,
    # mapping 'A' and 'a' to 1, 'B' and 'b' to 2, etc.
    if {[regexp -- {\d([a-zA-Z]+)} $portversion ignored chars]} {
        # Get the integer ordinals of 'A' and 'a'.
        scan "A" %c ord_A
        scan "a" %c ord_a

        set i 0
        foreach char [split $chars ""] {
            scan $char %c ord

            # Treat uppercase and lowercase characters as the same
            # value.  Ordinal values less then 'a' should have 'A'
            # subtracted, otherwise subtract 'a'.  Add 1 to the value
            # so that 'a' and 'A' are mapped to 1, not 0.
            if {$ord < $ord_a} {
                set j [expr {$ord - $ord_A + 1}]
            } else {
                set j [expr {$ord - $ord_a + 1}]
            }
            set i [expr {26*$i + $j}]
        }
        lappend vs $i
    }

    # Add integers so that the total number of integers in the version
    # number is seven.
    while {[llength $vs] < 7} {
        lappend vs 0
    }

    # Prepend the epoch and append the revision number.
    set vs [linsert $vs 0 $portepoch]
    lappend vs $portrevision

    set v [join $vs {.}]

    return $v
}
