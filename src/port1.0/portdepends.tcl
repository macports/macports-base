# ex:ts=4
#
# Insert some license text here at some point soon.
#

# the 'main' target is provided by this package
# main is a magic target and should not be replaced

package provide portdepends 1.0
package require portutil 1.0

register com.apple.depends.fetch target depends_main depends_init always
register com.apple.depends.fetch provides depends_fetch

register com.apple.depends.build target depends_main depends_init always
register com.apple.depends.build provides depends_build

register com.apple.depends.run target depends_main depends_init always
register com.apple.depends.run provides depends_run

register com.apple.depends.extract target depends_main depends_init always
register com.apple.depends.extract provides depends_extract

register com.apple.depends.lib target depends_main depends_init always
register com.apple.depends.lib provides depends_lib

# define options
options depends_fetch depends_build depends_run depends_extract depends_lib

proc depends_init {args} {
    return 0
}

# depends_resolve
# XXX - Architecture specific
# XXX - Rely on information from internal defines in cctools/dyld:
# define DEFAULT_FALLBACK_FRAMEWORK_PATH
# /Library/Frameworks:/Library/Frameworks:/Network/Library/Frameworks:/System/Library/Frameworks
# define DEFAULT_FALLBACK_LIBRARY_PATH /lib:/usr/local/lib:/lib:/usr/lib
# Environment variables DYLD_FRAMEWORK_PATH, DYLD_LIBRARY_PATH,
# DYLD_FALLBACK_FRAMEWORK_PATH, and DYLD_FALLBACK_LIBRARY_PATH take precedence

proc depends_main {id} {
    if {[regexp .*\..*\.depends\.(.*) $id match name] != 1} {
	return 0
    }
    set name depends_$name
    global $name env sysportpath
    if {![info exists $name]} {
	return 0
    }
    upvar #0 $name upname
    foreach depspec $upname {
	if {[regexp {([A-Za-z\./0-9]+):([A-Za-z0-9\.$^\?\+\(\)\|\\]+):([A-Za-z\./0-9]+)} "$depspec" match deppath depregex portname] == 1} {
	    switch -exact -- $deppath {
		lib {
		    if {[info exists env(DYLD_FRAMEWORK_PATH)]} {
			lappend search_path $env(DYLD_FRAMEWORK_PATH)
		    } else {
			lappend search_path /Library/Frameworks /Library/Frameworks /Network/Library/Frameworks /System/Library/Frameworks
		    }
		    if {[info exists env(DYLD_FALLBACK_FRAMEWORK_PATH)]} {
			lappend search_path $env(DYLD_FALLBACK_FRAMEWORK_PATH)
		    }
		    if {[info exists env(DYLD_LIBRARY_PATH)]} {
			lappend search_path $env(DYLD_LIBRARY_PATH)
		    } else {
			lappend search_path /lib /usr/local/lib /lib /usr/lib
		    }
		    if {[info exists env(DYLD_FALLBACK_LIBRARY_PATH)]} {
			lappend search_path $env(DYLD_LIBRARY_PATH)
		    }
		    regsub {\.} $depregex {\.} depregex
		    set depregex \^$depregex.*\\.dylib\$
		}
		bin {
		    set search_path [split $env(PATH) :]
		    set depregex \^$depregex\$
		}
		default {
		    set search_path [split $deppath :]
		}
	    }
	}
    }
    foreach path $search_path {
	if {![file isdirectory $path]} {
		continue
	}
	foreach filename [readdir $path] {
		if {[regexp $depregex $filename] == 1} {
			ui_debug "Found Dependency: path: $path filename: $filename regex: $depregex"
			return 0
		}
	}
    }
    ui_debug "Building $portname"
    dportbuild [dportopen $sysportpath/$portname] install
    return 0
}
