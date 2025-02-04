#
#   Critcl - build C extensions on-the-fly
#
#   Copyright (c) 2001-2007 Jean-Claude Wippler
#   Copyright (c) 2002-2007 Steve Landers
#
#   See http://wiki.tcl.tk/critcl
#
#   This is the Critcl runtime that loads the appropriate
#   shared library when a package is requested
#

namespace eval ::critcl::runtime {}

proc ::critcl::runtime::loadlib {dir package version libname initfun tsrc mapping args} {
    # XXX At least parts of this can be done by the package generator,
    # XXX like listing the Tcl files to source. The glob here allows
    # XXX code-injection after-the-fact, by simply adding a .tcl in
    # XXX the proper place.
    set path [file join $dir [MapPlatform $mapping]]
    set ext [info sharedlibextension]
    set lib [file join $path $libname$ext]
    set provide [list]

    # Now the runtime equivalent of a series of 'preFetch' commands.
    if {[llength $args]} {
	set preload [file join $path preload$ext]
	foreach p $args {
	    set prelib [file join $path $p$ext]
	    if {[file readable $preload] && [file readable $prelib]} {
		lappend provide [list load $preload];# XXX Move this out of the loop, do only once.
		lappend provide [list ::critcl::runtime::preload $prelib]
	    }
	}
    }

    lappend provide [list load $lib $initfun]
    foreach t $tsrc {
	lappend loadcmd "::critcl::runtime::Fetch \$dir [list $t]"
    }
    lappend provide "package provide $package $version"
    package ifneeded $package $version [join $provide "\n"]
    return
}

proc ::critcl::runtime::preFetch {path ext dll} {
    set preload [file join $path preload$ext]
    if {![file readable $preload]} return

    set prelib [file join $path $dll$ext]
    if {![file readable $prelib]} return

    load $preload ; # Defines next command.
    ::critcl::runtime::preload $prelib
    return
}

proc ::critcl::runtime::Fetch {dir t} {
    # The 'Ignore' disables compile & run functionality.

    # Background: If the regular critcl package is already loaded, and
    # this prebuilt package uses its defining .tcl file also as a
    # 'tsources' then critcl might try to collect data and build it
    # because of the calls to its API, despite the necessary binaries
    # already being present, just not in the critcl cache. That is
    # redundant in the best case, and fails in the worst case (no
    # compiler), preventing the use o a perfectly fine package. The
    # 'ignore' call now tells critcl that it should ignore any calls
    # made to it by the sourced files, and thus avoids that trouble.

    # The other case, the regular critcl package getting loaded after
    # this prebuilt package is irrelevant. At that point the tsources
    # were already run, and used the dummy procedures defined in the
    # critcl-rt.tcl, which ignore the calls by definition.

    set t [file join $dir tcl $t]
    ::critcl::Ignore $t
    uplevel #0 [list source $t]
    return
}

proc ::critcl::runtime::precopy {dll} {
    # This command is only used on Windows when preloading out of a
    # VFS that doesn't support direct loading (usually, a Starkit)
    #   - we preserve the dll name so that dependencies are satisfied
    #	- The critcl::runtime::preload command is defined in the supporting
    #     "preload" package, implemented in "critcl/lib/critcl/critcl_c/preload.c"

    global env
    if {[info exists env(TEMP)]} {
	set dir $env(TEMP)
    } elseif {[info exists env(TMP)]} {
	set dir $env(TMP)
    } elseif {[file exists $env(HOME)]} {
	set dir $env(HOME)
    } else {
	set dir .
    }
    set dir [file join $dir TCL[pid]]
    set i 0
    while {[file exists $dir]} {
	append dir [incr i]
    }
    set new [file join $dir [file tail $dll]]
    file mkdir $dir
    file copy $dll $new
    return $new
}

proc ::critcl::runtime::MapPlatform {{mapping {}}} {
    # A sibling of critcl::platform that applies the platform mapping

    set platform [::platform::generic]
    set version $::tcl_platform(osVersion)
    if {[string match "macosx-*" $platform]} {
	# "normalize" the osVersion to match OSX release numbers
	set v [split $version .]
	set v1 [lindex $v 0]
	set v2 [lindex $v 1]
	set v3 [lindex $v 2]
	# Darwin 19 and earlier are macOS 10.x. Darwin 20 and later are macOS
    # 11, macOS 12, etc.
    if {$v1 >= 20} {
        incr v1 -9
        set version $v1.$v2.$v3
    } else {
        incr v1 -4
        set version 10.$v1.$v2
	}
    } else {
	# Strip trailing non-version info
	regsub -- {-.*$} $version {} version
    }
    foreach {config map} $mapping {
	if {![string match $config $platform]} continue
	set minver [lindex $map 1]
	if {[package vcompare $version $minver] < 0} continue
	set platform [lindex $map 0]
	break
    }
    return $platform
}
