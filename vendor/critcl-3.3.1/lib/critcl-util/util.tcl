## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
# Pragmas for MetaData Scanner.
# n/a

# CriTcl Utility Commands.

package provide critcl::util 1.2.1

# # ## ### ##### ######## ############# #####################
## Requirements.

package require Tcl    8.6 9 ; # Min supported version.
package require critcl 3.2

namespace eval ::critcl::util {}

# # ## ### ##### ######## ############# #####################
## Implementation -- API: Embed C Code

proc ::critcl::util::locate {label paths {cmd {}}} {
    # Locate a file across set of paths.
    # Relative paths are to "::critcl::Here".
    # Paths are run through subst for dynamic construction.
    # A command prefix can be specified, to further check/process each found path.
    # Result is the found path, as coming from the paths argument.
    # Should go into cheader or similar command.
    # Failure to find is reported via critcl::error

    foreach path $paths {
	if {[file pathtype $path] eq "relative"} {
	    set fullpath [file normalize [file join [critcl::Here] $path]]
	} else {
	    set fullpath $path
	}
	if {![file exists $fullpath]} continue
	if {[llength $cmd] && ![uplevel 1 [linsert $cmd end $fullpath]]} continue
	critcl::msg "${label}: $path"
	return $path
    }
    critcl::error "${label}: not found, searched [linsert [join $paths {, }] end-1 and]"
    return
}

proc ::critcl::util::checkfun {name {label {}}} {
    variable cftemplate
    if {$label eq {}} { set label "Checking for function '$name'" }
    return [critcl::checklink $label [string map [list @@@ $name] $cftemplate]]
}

proc ::critcl::util::def {configfile define {value 1}} {
    set result [file join [critcl::cache] [file tail $configfile]]

    Put $result "[Get $result]\n\#define $define $value\n"
    return
}

proc ::critcl::util::undef {configfile define} {
    set result [file join [critcl::cache] [file tail $configfile]]

    Put $result "[Get $result]\n\#undef $define\n"
    return
}

# # ## ### ##### ######## ############# #####################

proc ::critcl::util::Get {path} {
    if {[catch {
	set c [open $path r]
	set d [read $c]
	close $c
    }]} {
	set d {}
    }
    return $d
}

proc ::critcl::util::Put {path data} {
    # Write changes back, via temp file. Commit via atomic rename.
    set c [open $path.[pid] w]
    puts -nonewline $c $data
    close $c
    file rename -force $path.[pid] $path
    return
}

# # ## ### ##### ######## ############# #####################
## State

namespace eval ::critcl::util {
    variable cftemplate {
	/* The header <limits.h> may declare @@@. To avoid a clash
	 * redefine it to something aside. As an example, gettimeofday()
	 * is declared in the <limits.h> provided by HP-UX 11i. Regardless,
	 * we pull in a system header defining the __stub macros, and a
	 * few prototypes only possibly in conflict with @@@, we hope.
	 * As <limits.h> exists even on free-standing compilers its use
	 * is preferred when __STDC__ is active.
	 */

	#define @@@ innocuous_@@@
	#ifdef __STDC__
	# include <limits.h>
	#else
	# include <assert.h>
	#endif
	#undef @@@

	/* Next up a declaration to override whatever internal prototype
	 * was declared by GCC, to prevent an error. As the return type
	 * 'int' might match such a GCC builtin, and thus causing the application
	 * of the argument prototype despite this we use 'char' instead.
	 */

	#ifdef __cplusplus
	extern "C"
	#endif
	char @@@ ();

	/* Lastly the GNU libc defines a few special names for its functions,
	 * these will always fail with ENONSYS. Further, some functions
	 * actually start with __, with the normal name (we are looking for)
	 * an alias of it. Regardless, for these we bail.
	*/

	#if defined __stub_@@@ || defined __stub___@@@
	choke me
	#endif

	int main ()
	{
	    return @@@ ();
	    ;
	    return 0;
	}
    }
}

# # ## ### ##### ######## ############# #####################
## Export API

namespace eval ::critcl::util {
    namespace export checkfun def undef locate
    catch { namespace ensemble create }
}

# # ## ### ##### ######## ############# #####################
## Ready
return
