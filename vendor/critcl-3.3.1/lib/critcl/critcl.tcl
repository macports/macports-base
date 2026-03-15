## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
# Pragmas for MetaData Scanner.
# @mdgen OWNER: Config
# @mdgen OWNER: critcl_c
#
# Copyright (c) 2001-20?? Jean-Claude Wippler
# Copyright (c) 2002-20?? Steve Landers
# Copyright (c) 20??-2024 Andreas Kupries <andreas_kupries@users.sourceforge.net>

# # ## ### ##### ######## ############# #####################
# CriTcl Core.

package provide critcl 3.3.1

namespace eval ::critcl {}

# # ## ### ##### ######## ############# #####################
## Requirements.

package require Tcl 8.6 9 ; # Minimal supported Tcl runtime.
if {[catch {
    package require platform 1.0.2 ; # Determine current platform.
}]} {
    # Fall back to our internal copy (currently equivalent to platform
    # 1.0.14(+)) if the environment does not have the official
    # package.
    package require critcl::platform
} elseif {
    [string match freebsd* [platform::generic]] &&
    ([platform::generic] eq [platform::identify])
} {
    # Again fall back to the internal package if we are on FreeBSD and
    # the official package does not properly identify the OS ABI
    # version.
    package require critcl::platform
}

# # ## ### ##### ######## ############# #####################
## https://github.com/andreas-kupries/critcl/issues/112
#
## Removed the code ensuring that we have maximal 'info frame' data,
## if supported. This code was moved into the app-critcl package
## instead.
#
## The issue with having it here is that this changes a global setting
## of the core, i.e. this will not only affect critcl itself when
## building binaries, but also the larger environment, i.e. the
## application using critcl.  Given that this feature being active
## slows the Tcl core down by about 10%, sometimes more this is not a
## good decision to make on behalf of the user.
#
## In the critcl application itself I am willing to pay the price for
## the more precise location information in case of compilation
## failures, and the isolation to that application. For the
## dynamically `compile & run` in arbitrary environments OTOH not.

# # ## ### ##### ######## ############# #####################
# This is the md5 package bundled with critcl.
# No need to look for fallbacks.

proc ::critcl::md5_hex {s} {
    if {$v::uuidcounter} {
	return [format %032d [incr v::uuidcounter]]
    }
    package require critcl_md5c
    # As `s` is an arbitrary string of unknown origin we cannot assume
    # that it contains byte data. And we definitely cannot assume that
    # it only contains ASCII characters. For MD5 to operate correctly
    # we have to convert the string into a proper series of bytes.
    binary scan [md5c [encoding convertto utf-8 $s]] H* md; return $md
}

# # ## ### ##### ######## ############# #####################

proc ::critcl::lappendlist {lvar list} {
    if {![llength $list]} return
    upvar $lvar dest
    lappend dest {*}$list
    return
}

# # ## ### ##### ######## ############# #####################
##

proc ::critcl::buildrequirement {script} {
    # In regular code this does nothing. It is a marker for
    # the static scanner to change under what key to record
    # the 'package require' found in the script.
    uplevel 1 $script
}

proc ::critcl::TeapotPlatform {} {
    # Platform identifier HACK. Most of the data in critcl is based on
    # 'platform::generic'. The TEApot MD however uses
    # 'platform::identify' with its detail information (solaris kernel
    # version, linux glibc version). But, if a cross-compile is
    # running we are SOL, because we have no place to pull the
    # necessary detail from, 'identify' is a purely local operation :(

    set platform [actualtarget]
    if {[platform::generic] eq $platform} {
	set platform [platform::identify]
    }

    return $platform
}

proc ::critcl::TeapotRequire {dspec} {
    # Syntax of dspec: (a) pname
    #             ...: (b) pname req-version...
    #             ...: (c) pname -exact req-version
    #
    # We can assume that the syntax is generally ok, because otherwise
    # the 'package require' itself will fail in a moment, blocking the
    # further execution of the .critcl file. So we only have to
    # distinguish the cases.

    if {([llength $dspec] == 3) &&
	([lindex $dspec 1] eq "-exact")} {
	# (c)
	lassign $dspec pn _ pv
	set spec [list $pn ${pv}-$pv]
    } else {
	# (a, b)
	set spec $dspec
    }

    return $spec
}

# # ## ### ##### ######## ############# #####################
## Implementation -- API: Embed C Code

proc ::critcl::HeaderLines {text} {
    if {![regexp {^[\t\n ]+} $text header]} {
	return [list 0 $text]
    }
    set lines [regexp -all {\n} $header]
    # => The C code begins $lines lines after location of the c**
    #    command. This goes as offset into the generated #line pragma,
    #    because now (see next line) we throw away this leading
    #    whitespace.
    set text [string trim $text]
    return [list $lines $text]
}

proc ::critcl::Lines {text} {
    set n [regexp -all {\n} $text]
    return $n
}

proc ::critcl::ccode {text} {
    set file [SkipIgnored [This]]
    HandleDeclAfterBuild
    CCodeCore $file $text
    return
}

proc ::critcl::CCodeCore {file text} {
    set digest [UUID.extend $file .ccode $text]

    set block {}
    lassign [HeaderLines $text] leadoffset text
    Transition9Check [at::Loc $leadoffset -3 $file] $text
    if {$v::options(lines)} {
	append block [at::CPragma $leadoffset -3 $file]
    }

    append block $text \n
    dict update v::code($file) config c {
	dict lappend c fragments $digest
	dict set     c block     $digest $block
	dict lappend c defs      $digest
    }
    return
}

proc ::critcl::ccommand {name anames args} {
    SkipIgnored [set file [This]]
    HandleDeclAfterBuild

    # Basic key for the clientdata and delproc arrays.
    set cname $name[UUID.serial $file]

    if {[llength $args]} {
	set body [lindex $args 0]
	set args [lrange $args 1 end]
    } else {
	set body {}
    }

    set clientdata NULL ;# Default: ClientData expression
    set delproc    NULL ;# Default: Function pointer expression
    set acname     0
    set tname      ""
    while {[string match "-*" $args]} {
        switch -- [set opt [lindex $args 0]] {
	    -clientdata { set clientdata [lindex $args 1] }
	    -delproc    { set delproc    [lindex $args 1] }
	    -cname      { set acname     [lindex $args 1] }
	    -tracename  { set tname      [lindex $args 1] }
	    default {
		error "Unknown option $opt, expected one of -clientdata, -cname, -delproc"
	    }
        }
        set args [lrange $args 2 end]
    }

    # Put body back into args for integration into the MD5 uuid
    # generated for mode compile&run. Bug and fix reported by Peter
    # Spjuth.
    lappend args $body

    if {$acname} {
	BeginCommand static $name $anames $args
	set ns    {}
	set cns   {}
	set key   $cname
	set wname $name
	if {$tname ne {}} {
	    set traceref \"$tname\"
	} else {
	    set traceref \"$name\"
	}
    } else {
	lassign [BeginCommand public $name $anames $args] ns cns name cname
	set key   [string map {:: _} $ns$cname]
	set wname tcl_$cns$cname
	set traceref   ns_$cns$cname
    }

    # XXX clientdata/delproc, either note clashes, or keep information per-file.

    set v::clientdata($key) $clientdata
    set v::delproc($key) $delproc

    #set body [join $args]
    if {$body != ""} {
	lappend anames ""
	foreach {cd ip oc ov} $anames break
	if {$cd eq ""} { set cd clientdata }
	if {$ip eq ""} { set ip interp }
	if {$oc eq ""} { set oc objc }
	if {$ov eq ""} { set ov objv }

	set ca "(ClientData $cd, Tcl_Interp *$ip, Tcl_Size $oc, Tcl_Obj *CONST $ov\[])"

	if {$v::options(trace)} {
	    # For ccommand tracing we will emit a shim after the implementation.
	    # Give the implementation a different name.
	    Emitln "static int\n${wname}_actual$ca"
	} else {
	    Emitln "static int\n$wname$ca"
	}

	Emit   \{\n
	lassign [HeaderLines $body] leadoffset body
	Transition9Check [at::Loc $leadoffset -2 $file] $body
	if {$v::options(lines)} {
	    Emit [at::CPragma $leadoffset -2 $file]
	}
	Emit   $body
	Emitln \n\}

	# Now emit the call to the ccommand tracing shim. It simply
	# calls the regular implementation and places the tracing
	# around that.
	if {$v::options(trace)} {
	    Emitln "\nstatic int\n$wname$ca"
	    Emitln \{
	    Emitln "  int _rv;"
	    Emitln "  critcl_trace_cmd_args ($traceref, $oc, $ov);"
	    Emitln "  _rv = ${wname}_actual ($cd, $ip, $oc, $ov);"
	    Emitln "  return critcl_trace_cmd_result (_rv, $ip);"
	    Emitln \}
	}
    } else {
	# if no body is specified, then $anames is alias for the real cmd proc
	Emitln "#define $wname $anames"
	Emitln "int $anames\(\);"
    }
    EndCommand
    return
}

proc ::critcl::cdata {name data} {
    SkipIgnored [This]
    HandleDeclAfterBuild
    binary scan $data c* bytes ;# split as bytes, not (unicode) chars

    set inittext ""
    set line ""
    foreach x $bytes {
	if {[string length $line] > 70} {
	    append inittext "    " $line \n
	    set line ""
	}
	append line $x ,
    }
    append inittext "    " $line

    set count [llength $bytes]

    set body [subst [Cat [Template cdata.c]]]
    #               ^=> count, inittext

    # NOTE: The uplevel is needed because otherwise 'ccommand' will
    # not properly determine the caller's namespace.
    uplevel 1 [list critcl::ccommand $name {dummy ip objc objv} [at::caller!]$body]
    return $name
}

proc ::critcl::cdefines {defines {namespace "::"}} {
    set file [SkipIgnored [This]]
    HandleDeclAfterBuild
    set digest [UUID.extend $file .cdefines [list $defines $namespace]]

    dict update v::code($file) config c {
	foreach def $defines {
	    dict set c const $def $namespace
	}
    }
    return
}

proc ::critcl::MakeDerivedType {type ev} {
    upvar 1 $ev errmsg
    foreach synth {
	MakeScalarLimited
	MakeList
    } {
	set ltype [$synth $type errmsg]
	if {$ltype eq {}} continue
	return $ltype
    }
    return
}

# Dynamically create an arg-type for "(length-limited) list (of T)".
proc ::critcl::MakeList {type ev} {
    # Check for basic syntax.
    # Accept the list indicator syntax as either prefix or suffix of the base type.

    if {![regexp {^\[(\d*|\*)\](.*)$} $type -> limit base]} {
	if {![regexp {^(.*)\[(\d*|\*)\]$} $type -> base limit]} {
	    return
	}
    }

    # This looks like a list type, start recording errors

    if {($base ne {}) && ![has-argtype $base]} {
	# XXX TODO: Recurse into the base for possible further synthesis.
	set err "list: Unknown base type '$base'"
	return
    }
    if {($limit ne {}) && ($limit == 0)} {
	set err "list: Bad size 0, i.e. would be empty"
	return
    }

    # (LIST) Note: The '[]' and '[*]', i.e. unlimited lists of any type cannot appear here, because
    # they exist as standard builtins. This means that at least one of base or limit is __not__ empty.

    set ntype list

    if {$base eq {}} {
	append ntype _obj
    } else {
	append ntype _$base
    }

    # Save the type-specific list type, without length restrictions factored in.
    # This is what we need for the data structures and conversion, nothing more.
    # IOW we do not wish to create multiple different types and functions for the
    # same list type, just different length restrictions.
    set nctype $ntype

    if {$limit in {{} *}} {
        set limit {}
	append ntype _any
    } else {
	append ntype _$limit
    }

    # Check if this list type was seen before
    if {[has-argtype $ntype]} { return $ntype }

    # Generate the validator for this kind of list.

    if {$base eq {}} {
	# Without a base type simply start from `list`.

	set ctype [ArgumentCType      list]
	set code  [ArgumentConversion list]
	set new $code
    } else {
	# With a base type the start is not quite `list`. Because the C type is different, and we
	# need a proper place for the list of Tcl_Obj* to get the element from.

	set new {
	    int k;
	    Tcl_Obj** el;
	    if (Tcl_ListObjGetElements (interp, @@, /* OK tcl9 */
			&(@A.c), &el) != TCL_OK) return TCL_ERROR;
	    @A.o = @@;
	}
    }

    if {$limit ne {}} {
	# Check that the list conforms to the expected size
	append new \
	    "\n\t/* Size check, assert (length (list) == $limit) */" \
	    "\n\tif (@A.c != $limit) \{" \
	    "\n\t    Tcl_AppendResult (interp, \"Expected a list of $limit\", NULL);" \
	    "\n\t    return TCL_ERROR;" \
	    "\n\t\}"
    }

    if {$base eq {}} {
	# Without a base type we have a length-limited plain list, and there nothing more to do.

	argtype $ntype $new $ctype $ctype
	argtypesupport $ntype [ArgumentSupport list]

	return $ntype
    }

    # With a base type it is now time to synthesize something more complex to validate the list
    # elements against the base type. `el` is the array of Tcl_Obj* holding the unconverted raw
    # values. See `MakeVariadicTypeFor` too. It uses the same general schema, applied to the list of
    # remaining cproc 'args'.

    lappend one @@  src
    lappend one &@A dst
    lappend one @A  *dst
    lappend one @A. dst->

    lappend map @1conv@  [Deline [string map $one [ArgumentConversion $base]]]
    lappend map @type@   [ArgumentCType $base]
    lappend map @ntype@  $ntype
    lappend map @nctype@ $nctype

    append new [string map $map {
	@A.v = (@type@*) ((!@A.c) ? 0 : ckalloc (@A.c * sizeof (@type@)));
	for (k = 0; k < @A.c; k++) {
	    if (_critcl_@nctype@_item (interp, el[k], &(@A.v[k])) != TCL_OK) {
		ckfree ((char*) @A.v); /* Cleanup partial work */
		return TCL_ERROR;
	    }
	}
    }]

    argtype $ntype $new critcl_$nctype critcl_$nctype

    argtypesupport $ntype [string map $map {
	/* NOTE: Array 'v' is allocated on the heap. The argument
	// release code is used to free it after the worker
	// function returned. Depending on type and what is done
	// by the worker it may have to make copies of the data.
	*/

	typedef struct critcl_@nctype@ {
	    Tcl_Obj* o; /* Original list object, for pass-through cases */
	    Tcl_Size c; /* Element count */
	    @type@*  v; /* Allocated array of the elements */
	} critcl_@nctype@;

	static int
	_critcl_@nctype@_item (Tcl_Interp* interp, Tcl_Obj* src, @type@* dst) {
	    @1conv@
	    return TCL_OK;
	}
    }] $nctype

    argtyperelease $ntype [string map $map {
	if (@A.c) { ckfree ((char*) @A.v); }
    }]

    return $ntype
}

proc ::critcl::MakeScalarLimited {type ev} {
    upvar 1 $ev errmsg
    if {[catch {llength $type}]} return

    if {[lindex $type 0] ni {
	int long wideint double float
    }} return

    # At this point we assume that it can be a restricted scalar type and we record errors.

    set limits [lassign $type base]
    set n [llength $type]
    if {($n < 3) || (($n % 2) == 0)} { set err "$type: Incomplete restriction" ; return }

    foreach {op _} $limits {
	if {$op in {> < >= <=}} continue
	set err "$type: Bad relation '$op'"
	return
    }

    if {$base in {int long wideint}} {
	foreach {_ v} $limits {
	    if {[string is integer -strict $v]} continue
	    set err "$base: Expected integer, have '$v'"
	    return
	}
    } else {
	# double or float
	foreach {_ v} $limits {
	    if {[string is double -strict $v]} continue
	    set err "$base: Expected float, have '$v'"
	    return
	}
    }

    # This looks mostly good. Condense the set of restrictions into a simple min/max range
    lassign {} mingt minge maxlt maxle

    # Phase 1. Fuse identical kind of restrictions into a single of their type
    foreach {op v} $limits {
	switch -exact -- $op {
	    >  { if {($mingt eq {}) || ($v > $mingt)} { set mingt $v } }
	    >= { if {($minge eq {}) || ($v > $minge)} { set minge $v } }
	    <  { if {($maxlt eq {}) || ($v < $maxlt)} { set maxlt $v } }
	    <= { if {($maxle eq {}) || ($v < $maxle)} { set maxle $v } }
	}
    }

    # Phase 2. Fuse similar (lt/le, gt/ge) into a single

    if {($mingt ne {}) && ($minge ne {})} {
	# We have both x >  a &&
	#              x >= b
	# ... Determine the stricter form.

	# a  > b => ">  a"
	# a  < b => ">= b"
	# a == b => ">  a"

	if {$mingt >= $minge} {
	    set min   $mingt
	    set minop >
	} else {
	    set min   $minge
	    set minop >=
	}
    } elseif {$mingt ne {}} {
	# x > a only
	set min   $mingt
	set minop >
    } elseif {$minge ne {}} {
	# x >= a only
	set min   $minge
	set minop >=
    } else {
	# No limit
	lassign {} min minop
    }

    if {($maxlt ne {}) && ($maxle ne {})} {
	# We have both x <  a &&
	#              x <= b
	# ... Determine the stricter form.

	# a  > b => "<= b"
	# a  < b => "<  a"
	# a == b => "<  a"

	if {$maxlt <= $maxle} {
	    set max   $maxlt
	    set maxop <
	} else {
	    set max   $maxle
	    set maxop <=
	}
    } elseif {$maxlt ne {}} {
	# x > a only
	set max   $maxlt
	set maxop <
    } elseif {$maxle ne {}} {
	# x >= a only
	set max   $maxle
	set maxop <=
    } else {
	# No limit
	lassign {} max maxop
    }

    if {($min ne {}) && ($max ne {})} {
	# With both limits they may specify an empty range, or a range allowing only single value.
	# That is not sensible.

	# a <  x <  b -- a >= b is empty
	# a <= x <  b -- a >= b is empty
	# a <  x <= b -- a >= b is empty
	# a <= x <= b -- a >  b is empty, a == b is singular,

	# Reduced checks:
	# - a >  b is empty
	# - a == b is singular if both <=, else empty

	if {($min > $max)} {
	    set err "$base: Limits do not allow any value as valid"
	    return
	}
	if {$min == $max} {
	    if {$minop$maxop eq ">=<=")} {
		set err "$base: Limits only allow a single value as valid: $min"
	    } else {
		set err "$base: Limits do not allow any value as valid"
	    }
	    return
	}
    }

    # Compute canonical type from the fused ranges.

    set ntype $base
    if {$min ne {}} { lappend ntype $minop $min }
    if {$max ne {}} { lappend ntype $maxop $max }

    # Check if we saw this canonical type before.

    if {[has-argtype $ntype]} { return $ntype }

    # Generate the new type

    set ctype [ArgumentCType      $base]
    set code  [ArgumentConversion $base]

    set head  "expected $ntype, but got \\\""
    set tail  "\\\""
    set msg   "\"$head\", Tcl_GetString (@@), \"$tail\""
    set new $code

    if {$min ne {}} {
	append new \
	    "\n\t/* Range check, assert (x $minop $min) */" \
	    "\n\tif (!(@A $minop $min)) \{" \
	    "\n\t    Tcl_AppendResult (interp, $msg, NULL);" \
	    "\n\t    return TCL_ERROR;" \
	    "\n\t\}"
    }
    if {$max ne {}} {
	append new \
	    "\n\t/* Range check, assert (x $maxop $max) */" \
	    "\n\tif (!(@A $maxop $max)) \{" \
	    "\n\t    Tcl_AppendResult (interp, $msg, NULL);" \
	    "\n\t    return TCL_ERROR;" \
	    "\n\t\}"
    }

    argtype $ntype $new $ctype $ctype

    return $ntype
}

proc ::critcl::MakeVariadicTypeFor {type} {
    # Note: The type "Tcl_Obj*" required special treatment and is
    # directly defined as a builtin, see 'Initialize'. The has-argtype
    # check below will prevent us from trying to create something
    # generic, and wrong.

    set ltype variadic_$type
    if {![has-argtype $ltype]} {
	# Generate a type representing a list/array of <type>
	# elements, plus conversion code. Similar to the 'list' type,
	# except for custom C types, and conversion assumes variadic,
	# not single argument.

	lappend one @@  src
	lappend one &@A dst
	lappend one @A  *dst
	lappend one @A. dst->
	lappend map @1conv@ [Deline [string map $one [ArgumentConversion $type]]]

	lappend map @type@  [ArgumentCType $type]
	lappend map @ltype@ $ltype

	argtype $ltype [string map $map {
	    int src, dst, leftovers = @C;
	    @A.c = leftovers;
	    @A.v = (@type@*) ((!leftovers) ? 0 : ckalloc (leftovers * sizeof (@type@)));
	    @A.o = (Tcl_Obj**) &ov[@I];
	    for (src = @I, dst = 0; leftovers > 0; dst++, src++, leftovers--) {
	       if (_critcl_variadic_@type@_item (interp, ov[src], &(@A.v[dst])) != TCL_OK) {
		   ckfree ((char*) @A.v); /* Cleanup partial work */
		   return TCL_ERROR;
	       }
	    }
	}] critcl_$ltype critcl_$ltype

	argtypesupport $ltype [string map $map {
	    /* NOTE: Array 'v' is allocated on the heap. The argument
	    // release code is used to free it after the worker
	    // function returned. Depending on type and what is done
	    // by the worker it may have to make copies of the data.
	    */

	    typedef struct critcl_@ltype@ {
		Tcl_Obj** o; /* Original object array */
		int       c; /* Element count */
		@type@*   v; /* Allocated array of the elements */
	    } critcl_@ltype@;

	    static int
	    _critcl_variadic_@type@_item (Tcl_Interp* interp, Tcl_Obj* src, @type@* dst) {
		@1conv@
		return TCL_OK;
	    }
	}]

	argtyperelease $ltype [string map $map {
	    if (@A.c) { ckfree ((char*) @A.v); }
	}]
    }
    return $ltype
}

proc ::critcl::ArgsInprocess {adefs skip} {
    # Convert the regular arg spec from the API into a dictionary
    # containing all the derived data we need in the various places of
    # the cproc implementation.

    set db {}

    set names    {} ; # list of raw argument names
    set cnames   {} ; # list of C var names for the arguments.
    set optional {} ; # list of flags signaling optional args.
    set variadic {} ; # list of flags signaling variadic args.
    set islast   {} ; # list of flags signaling the last arg.
    set varargs  no ; # flag signaling 'args' collector.
    set defaults {} ; # list of default values.
    set csig     {} ; # C signature of worker function.
    set tsig     {} ; # Tcl signature for frontend/shim command.
    set vardecls {} ; # C variables for arg conversion in the shim.
    set support  {} ; # Conversion support code for arguments.
    set has      {} ; # Types for which we have emitted the support
                      # code already. (dict: type -> '.' (presence))
    set hasopt   no ; # Overall flag - Have optionals ...
    set min      0  ; # Count required args - minimal needed.
    set max      0  ; # Count all args      - maximal allowed.
    set aconv    {} ; # list of the basic argument conversions.
    set achdr    {} ; # list of arg conversion annotations.
    set arel     {} ; # List of arg release code fragments, for those which have them.

    # Normalization, and typo fixing:
    # - Remove singular commas from the list.
    # - Strip argument names of trailing commas.
    # - Strip type names of leading commas.
    # Reason: Handle mistakenly entered C syntax for a function/command.
    #
    # Newly accepted syntax:
    # = int x , int y ...
    # = int x, int y ...
    # = int x ,int y ...

    # TODO: lmap.
    set adefnew {}
    set mode type
    foreach word $adefs {
	if {$word eq ","} continue
	switch -exact -- $mode {
	    type { lappend adefnew [string trimleft  $word ,] ; set mode args }
	    args { lappend adefnew [string trimright $word ,] ; set mode type }
	}
    }
    set adefs $adefnew ; unset adefnew mode

    # A 1st argument matching "Tcl_Interp*" does not count as a user
    # visible command argument. But appears in both signature and
    # actual list of arguments.
    if {[lindex $adefs 0] eq "Tcl_Interp*"} {
	lappend csig   [lrange $adefs 0 1]
	lappend cnames interp;#Fixed name for cproc[lindex $adefs 1]
	set adefs [lrange $adefs 2 end]
    }

    set last [expr {[llength $adefs]/2-1}]
    set current 0

    foreach {t a} $adefs {
	# t = type
	# a = name | {name default}

	# Check for a special case of list syntax, where the list indicator is written as suffix of
	# the argument name, instead of attached to the base type. When found normalize to the
	# expected form. I.e. transform a spec of the form `type a[...]` into `[...]type a`.
	#
	# Note that the argument name may be packaged with a default value. Ensure that we deail
	# with only the name itself.

	set hasdefault [expr {[llength $a] == 2}]
	lassign $a name defaultvalue

	if {[regexp {^(.+)(\[(\d*|\*)\])$} $name -> abase limit _]} {
	    set name $abase
	    set t $limit$t
	}

	# Check type validity

	if {![has-argtype $t]} {
	    # XXXA Attempt to compute a derived type on the fly.
	    set err "Argument type '$t' is not known"
	    set ltype [MakeDerivedType $t err]
	    if {$ltype eq {}} {
		return -code error $err
	    }

	    set t $ltype
	}

	# Base type support
	if {![dict exists $has $t]} {
	    dict set has $t .
	    lappend support "[ArgumentSupport $t]"
	}

	lappend islast [expr {$current == $last}]

	# Cases to consider:
	# 1. 'args' as the last argument, without a default.
	# 2. Any argument with a default value.
	# 3. Any argument.

	if {($current == $last) && ($name eq "args") && !$hasdefault} {
	    set hdr  "  /* ($t $name, ...) - - -- --- ----- -------- */"
	    lappend optional 0
	    lappend variadic 1
	    lappend defaults n/a
	    lappend tsig ?${name}...?
	    set varargs yes
	    set max     Inf ; # No limit on the number of args.

	    # Dynamically create an arg-type for "variadic list of T".
	    set t [MakeVariadicTypeFor $t]
	    # List support.
	    if {![dict exists $has $t]} {
		dict set has $t .
		lappend support "[ArgumentSupport $t]"
	    }

	} elseif {$hasdefault} {
	    incr max
	    set hasopt yes
	    set hdr  "  /* ($t $name, optional, default $defaultvalue) - - -- --- ----- -------- */"
	    lappend tsig ?${name}?
	    lappend optional 1
	    lappend variadic 0
	    lappend defaults $defaultvalue
	    lappend cnames   _has_$name
	    # Argument to signal if the optional argument was set
	    # (true) or is the default (false).
	    lappend csig     "int has_$name"
	    lappend vardecls "int _has_$name = 0;"

	} else {
	    set hdr  "  /* ($t $name) - - -- --- ----- -------- */"
	    lappend tsig $name
	    incr max
	    incr min
	    lappend optional 0
	    lappend variadic 0
	    lappend defaults n/a
	}

        lappend achdr    $hdr
	lappend csig     "[ArgumentCTypeB $t] $name"
	lappend vardecls "[ArgumentCType  $t] _$name;"

	lappend names  $name
	lappend cnames _$name
	lappend aconv  [TraceReturns "\"$t\" argument" [ArgumentConversion $t]]

        set rel [ArgumentRelease $t]
        if {$rel ne {}} {
	    set rel [string map [list @A _$name] $rel]
	    set hdr [string map {( {(Release: }} $hdr]
	    lappend arel "$hdr$rel"
	}

	incr current
    }

    set thresholds {}
    if {$hasopt} {
	# Compute thresholds for optional arguments. The threshold T
	# of an optional argument A is the number of required
	# arguments _after_ A. If during arg processing more than T
	# arguments are left then A can take the current word,
	# otherwise A is left to its default. We compute them from the
	# end.
	set t 0
	foreach o [lreverse $optional] {
	    if {$o} {
		lappend thresholds $t
	    } else {
		lappend thresholds -
		incr t
	    }
	}
	set thresholds [lreverse $thresholds]
    }

    set tsig [join $tsig { }]
    if {$tsig eq {}} {
	set tsig NULL
    } else {
	set tsig \"$tsig\"
    }

    # Generate code for wrong#args checking, based on the collected
    # min/max information. Cases to consider:
    #
    # a. max == Inf && min == 0   <=> All argc allowed.
    # b. max == Inf && min  > 0   <=> Fail argc < min.
    # c. max  < Inf && min == max <=> Fail argc != min.
    # d. max  < Inf && min  < max <=> Fail argc < min || max < argc

    if {$max == Inf} {
	# a, b
	if {!$min} {
	    # a: nothing to check.
	    set wacondition {}
	} else {
	    # b: argc < min
	    set wacondition {oc < MIN_ARGS}
	}
    } else {
	# c, d
	if {$min == $max} {
	    # c: argc != min
	    set wacondition {oc != MIN_ARGS}
	} else {
	    # d: argc < min || max < argc
	    set wacondition {(oc < MIN_ARGS) || (MAX_ARGS < oc)}
	}
    }

    # Generate conversion code for arguments. Use the threshold
    # information to handle optional arguments at all positions.
    # The code is executed after the wrong#args check.
    # That means we have at least 'min' arguments, enough to fill
    # all the required parameters.

    set map {}
    set conv   {}
    set opt    no
    set idx    $skip
    set    prefix   "  idx_  = $idx;" ; # Start at skip offset!
    append prefix "\n  argc_ = oc - $idx;"
    foreach \
	name $names \
	t $thresholds \
	o $optional \
	v $variadic \
	l $islast   \
	h $achdr \
	c $aconv \
	d $defaults {

	# Things to consider:
	# 1. Required variables at the beginning.
	#    We can access these using fixed indices.
	# 2. Any other variable require access using a dynamic index
	#    (idx_). During (1) we maintain the code initializing
	#    this.

	set useindex [expr {!$l}] ;# last arg => no need for idx/argc updates

	if {$v} {
	    # Variadic argument. Can only be last.
	    # opt  => dynamic access at idx_..., collect argc_
	    # !opt => static access at $idx ..., collect oc-$idx

	    unset   map
	    lappend map @A _$name
	    if {$opt} {
		lappend map @I idx_ @C argc_
	    } else {
		lappend map @I $idx @C (oc-$idx)
	    }

	    set c   [string map $map $c]

	    lappend conv $h
	    lappend conv $c
	    lappend conv {}
	    lappend conv {}
	    break
	}

	if {$o} {
	    # Optional argument. Anywhere. Check threshold.

	    unset   map
	    lappend map @@ "ov\[idx_\]"
	    lappend map @A _$name

	    set c   [string map $map $c]

	    if {$prefix ne {}} { lappend conv $prefix\n }
	    lappend conv $h
	    lappend conv "  if (argc_ > $t) \{"
	    lappend conv $c
	    if {$useindex} {
		lappend conv "    idx_++;"
		lappend conv "    argc_--;"
	    }
	    lappend conv "    _has_$name = 1;"
	    lappend conv "  \} else \{"
	    lappend conv "    _$name = $d;"
	    lappend conv "  \}"
	    lappend conv {}
	    lappend conv {}

	    set prefix {}
	    set opt    yes
	    continue
	}

	if {$opt} {
	    # Required argument, after one or more optional arguments
	    # were processed. Access to current word is dynamic.

	    unset   map
	    lappend map @@ "ov\[idx_\]"
	    lappend map @A _$name

	    set c   [string map $map $c]

	    lappend conv $h
	    lappend conv $c
	    lappend conv {}
	    if {$useindex} {
		lappend conv "  idx_++;"
		lappend conv "  argc_--;"
	    }
	    lappend conv {}
	    lappend conv {}
	    continue
	}

	# Required argument. No optionals processed yet. Access to
	# current word is via static index.

        unset   map
	lappend map @@ "ov\[$idx\]"
        lappend map @A _$name

	set c   [string map $map $c]

	lappend conv $h
	lappend conv $c
	lappend conv {}
	lappend conv {}

	incr idx
	set    prefix   "  idx_  = $idx;"
	append prefix "\n  argc_ = oc - $idx;"
    }
    set conv [Deline [join $conv \n]]

    # Save results ...

    dict set db skip        $skip
    dict set db aconv       $conv
    dict set db arelease    $arel
    dict set db thresholds  $thresholds
    dict set db wacondition $wacondition
    dict set db min         $min
    dict set db max         $max
    dict set db tsignature  $tsig
    dict set db names       $names
    dict set db cnames      $cnames
    dict set db optional    $optional
    dict set db variadic    $variadic
    dict set db islast      $islast
    dict set db defaults    $defaults
    dict set db varargs     $varargs
    dict set db csignature  $csig
    dict set db vardecls    $vardecls
    dict set db support     $support
    dict set db hasoptional $hasopt

    #puts ___________________________________________________________|$adefs
    #array set __ $db ; parray __
    #puts _______________________________________________________________\n
    return $db
}

proc ::critcl::argoptional {adefs} {
    set optional {}

    # A 1st argument matching "Tcl_Interp*" does not count as a user
    # visible command argument.
    if {[lindex $adefs 0] eq "Tcl_Interp*"} {
	set adefs [lrange $adefs 2 end]
    }

    foreach {t a} $adefs {
	if {[llength $a] == 2} {
	    lappend optional 1
	} else {
	    lappend optional 0
	}
    }

    return $optional
}

proc ::critcl::argdefaults {adefs} {
    set defaults {}

    # A 1st argument matching "Tcl_Interp*" does not count as a user
    # visible command argument.
    if {[lindex $adefs 0] eq "Tcl_Interp*"} {
	set adefs [lrange $adefs 2 end]
    }

    foreach {t a} $adefs {
	if {[llength $a] == 2} {
	    lappend defaults [lindex $a 1]
	}
    }

    return $defaults
}

proc ::critcl::argnames {adefs} {
    set names {}

    # A 1st argument matching "Tcl_Interp*" does not count as a user
    # visible command argument.
    if {[lindex $adefs 0] eq "Tcl_Interp*"} {
	set adefs [lrange $adefs 2 end]
    }

    foreach {t a} $adefs {
	if {[llength $a] == 2} {
	    set a [lindex $a 0]
	}
	lappend names $a
    }

    return $names
}

proc ::critcl::argcnames {adefs {interp ip}} {
    set cnames {}

    if {[lindex $adefs 0] eq "Tcl_Interp*"} {
	lappend cnames interp
	set     adefs  [lrange $adefs 2 end]
    }

    foreach {t a} $adefs {
	if {[llength $a] == 2} {
	    set a [lindex $a 0]
	    lappend cnames _has_$a
	}
	lappend cnames _$a
    }

    return $cnames
}

proc ::critcl::argcsignature {adefs} {
    # Construct the signature of the low-level C function.

    set cargs {}

    # If the 1st argument is "Tcl_Interp*", we pass it without
    # counting it as a command argument.

    if {[lindex $adefs 0] eq "Tcl_Interp*"} {
	lappend cargs  [lrange $adefs 0 1]
	set     adefs  [lrange $adefs 2 end]
    }

    foreach {t a} $adefs {
	if {[llength $a] == 2} {
	    set a [lindex $a 0]
	    # Argument to signal if the optional argument was set
	    # (true) or is the default (false).
	    lappend cargs "int has_$a"
	}
	lappend cargs  "[ArgumentCTypeB $t] $a"
    }

    return $cargs
}

proc ::critcl::argvardecls {adefs} {
    # Argument variables, destinations for the Tcl -> C conversion.

    # A 1st argument matching "Tcl_Interp*" does not count as a user
    # visible command argument.
    if {[lindex $adefs 0] eq "Tcl_Interp*"} {
	set adefs [lrange $adefs 2 end]
    }

    set result {}
    foreach {t a} $adefs {
	if {[llength $a] == 2} {
	    set a [lindex $a 0]
	    lappend result "[ArgumentCType $t] _$a;\n  int _has_$a = 0;"
	} else {
	    lappend result "[ArgumentCType $t] _$a;"
	}
    }

    return $result
}

proc ::critcl::argsupport {adefs} {
    # Argument global support, outside/before function.

    # A 1st argument matching "Tcl_Interp*" does not count as a user
    # visible command argument.
    if {[lindex $adefs 0] eq "Tcl_Interp*"} {
	set adefs [lrange $adefs 2 end]
    }

    set has {}

    set result {}
    foreach {t a} $adefs {
	if {[lsearch -exact $has $t] >= 0} continue
	lappend has $t
	lappend result "[ArgumentSupport $t]"
    }

    return $result
}

proc ::critcl::argconversion {adefs {n 1}} {
    # A 1st argument matching "Tcl_Interp*" does not count as a user
    # visible command argument.
    if {[lindex $adefs 0] eq "Tcl_Interp*"} {
	set adefs [lrange $adefs 2 end]
    }

    set min $n ; # count all non-optional arguments. min required.
    foreach {t a} $adefs {
	if {[llength $a] == 2} continue
	incr min
    }

    set result {}
    set opt 0
    set prefix "    idx_ = $n;\n"

    foreach {t a} $adefs {
	if {[llength $a] == 2} {
	    # Optional argument. Can be first, or later.
	    # For the first the prefix gives us the code to initialize idx_.

	    lassign $a a default

	    set map [list @@ "ov\[idx_\]" @A _$a]
	    set code [string map $map [ArgumentConversion $t]]

	    set code "${prefix}  if (oc > $min) \{\n$code\n    idx_++;\n    _has_$a = 1;\n  \} else \{\n    _$a = $default;\n  \}"
	    incr min

	    lappend result "  /* ($t $a, optional, default $default) - - -- --- ----- -------- */"
	    lappend result $code
	    lappend result {}
	    set opt 1
	    set prefix ""
	} elseif {$opt} {
	    # Fixed argument, after the optionals.
	    # Main issue: Use idx_ to access the array.
	    # We know that no optionals can follow, only the same.

	    set map [list @@ "ov\[idx_\]" @A _$a]
	    lappend result "  /* ($t $a) - - -- --- ----- -------- */"
	    lappend result [string map $map [ArgumentConversion $t]]
	    lappend result "  idx_++;"
	    lappend result {}

	} else {
	    # Fixed argument, before any optionals.
	    set map [list @@ "ov\[$n\]" @A _$a]
	    lappend result "  /* ($t $a) - - -- --- ----- -------- */"
	    lappend result [string map $map [ArgumentConversion $t]]
	    lappend result {}
	    incr n
	    set prefix "    idx_ = $n;\n"
	}
    }

    return [Deline $result]
}

proc ::critcl::has-argtype {name} {
    variable v::aconv
    return [info exists aconv($name)]
}

proc ::critcl::argtype-def {name} {
    lappend def [ArgumentCType      $name]
    lappend def [ArgumentCTypeB     $name]
    lappend def [ArgumentConversion $name]
    lappend def [ArgumentRelease    $name]
    lappend def [ArgumentSupport    $name]
    return $def
}

proc ::critcl::argtype {name conversion {ctype {}} {ctypeb {}}} {
    variable v::actype
    variable v::actypeb
    variable v::aconv
    variable v::acrel
    variable v::acsup

    # ctype  Type of variable holding the argument.
    # ctypeb Type of formal C function argument.

    # Handle aliases by copying the original definition.
    if {$conversion eq "="} {
	# XXXA auto-create derived type from known base types.

	if {![info exists aconv($ctype)]} {
	    return -code error "Unable to alias unknown type '$ctype'."
	}

	# Do not forget to copy support and release code, if present.
	if {[info exists acsup($ctype)]} {
	    #puts COPY/S:$ctype
	    set acsup($name) $acsup($ctype)
	}
	if {[info exists acrel($ctype)]} {
	    #puts COPY/R:$ctype
	    set acrel($name) $acrel($ctype)
	}

	set conversion $aconv($ctype)
	set ctypeb     $actypeb($ctype)
	set ctype      $actype($ctype)
    } else {
	lassign [HeaderLines $conversion] leadoffset conversion
	Transition9Check [at::Loc $leadoffset 0 [This]] $conversion
	set conversion "\t\{\n[at::caller! $leadoffset]\t[string trim $conversion] \}"
    }
    if {$ctype eq {}} {
	set ctype $name
    }
    if {$ctypeb eq {}} {
	set ctypeb $name
    }

    if {[info exists aconv($name)] &&
	(($aconv($name)   ne $conversion) ||
	 ($actype($name)  ne $ctype) ||
	 ($actypeb($name) ne $ctypeb))
    } {
	return -code error "Illegal duplicate definition of '$name'."
    }

    set aconv($name)   $conversion
    set actype($name)  $ctype
    set actypeb($name) $ctypeb
    return
}

proc ::critcl::argtypesupport {name code {guard {}}} {
    variable v::aconv
    variable v::acsup
    if {![info exists aconv($name)]} {
	return -code error "No definition for '$name'."
    }
    if {$guard eq {}} {
	set guard $name ; # Handle non-identifier chars!
    }
    lappend lines "#ifndef CRITCL_$guard"
    lappend lines "#define CRITCL_$guard"
    lappend lines $code
    lappend lines "#endif /* CRITCL_$guard _________ */"
    set support [join $lines \n]\n

    if {[info exists acsup($name)] &&
	($acsup($name) ne $support)
    } {
	return -code error "Illegal duplicate support of '$name'."
    }

    set acsup($name) $support
    return
}

proc ::critcl::argtyperelease {name code} {
    variable v::aconv
    variable v::acrel
    if {![info exists aconv($name)]} {
	return -code error "No definition for '$name'."
    }
    if {[info exists acrel($name)] &&
	($acrel($name) ne $code)
    } {
	return -code error "Illegal duplicate release of '$name'."
    }

    set acrel($name) $code
    return
}

proc ::critcl::has-resulttype {name} {
    variable v::rconv
    return [info exists rconv($name)]
}

proc ::critcl::resulttype {name conversion {ctype {}}} {
    variable v::rctype
    variable v::rconv

    # Handle aliases by copying the original definition.
    if {$conversion eq "="} {
	if {![info exists rconv($ctype)]} {
	    return -code error "Unable to alias unknown type '$ctype'."
	}
	set conversion $rconv($ctype)
	set ctype      $rctype($ctype)
    } else {
	lassign [HeaderLines $conversion] leadoffset conversion
	Transition9Check [at::Loc $leadoffset 0 [This]] $conversion
	set conversion [at::caller! $leadoffset]\t[string trimright $conversion]
    }
    if {$ctype eq {}} {
	set ctype $name
    }

    if {[info exists rconv($name)] &&
	(($rconv($name)  ne $conversion) ||
	 ($rctype($name) ne $ctype))
    } {
	return -code error "Illegal duplicate definition of '$name'."
    }

    set rconv($name)  $conversion
    set rctype($name) $ctype
    return
}

proc ::critcl::cconst {name rtype rvalue} {
    # The semantics are equivalent to
    #
    #   cproc $name {} $rtype { return $rvalue ; }
    #
    # The main feature of this new command is the knowledge of a
    # constant return value, which allows the optimization of the
    # generated code. Only the shim is emitted, with the return value
    # in place. No need for a lower-level C function containing a
    # function body.

    SkipIgnored [set file [This]]
    HandleDeclAfterBuild

    # A void result does not make sense for constants.
    if {$rtype eq "void"} {
	error "Constants cannot be of type \"void\""
    }

    lassign [BeginCommand public $name $rtype $rvalue] ns cns name cname
    set traceref ns_$cns$cname
    set wname    tcl_$cns$cname
    set cname    c_$cns$cname

    # Construct the shim handling the conversion between Tcl and C
    # realms.

    set adb [ArgsInprocess {} 1]

    EmitShimHeader         $wname
    EmitShimVariables      $adb $rtype
    EmitArgTracing         $traceref
    EmitWrongArgsCheck     $adb
    EmitConst              $rtype $rvalue
    EmitShimFooter         $adb $rtype
    EndCommand
    return
}

proc ::critcl::CheckForTracing {} {
    if {!$v::options(trace)} return
    if {[info exists ::critcl::v::__trace__]} return

    package require critcl::cutil
    ::critcl::cutil::tracer on
    set ::critcl::v::__trace__ marker ;# See above
    return
}

proc ::critcl::cproc {name adefs rtype {body "#"} args} {
    SkipIgnored [set file [This]]
    HandleDeclAfterBuild
    CheckForTracing

    set acname 0
    set passcd 0
    set aoffset 0
    set tname ""
    while {[string match "-*" $args]} {
        switch -- [set opt [lindex $args 0]] {
	    -cname      { set acname  [lindex $args 1] }
	    -pass-cdata { set passcd  [lindex $args 1] }
	    -arg-offset { set aoffset [lindex $args 1] }
	    -tracename  { set tname   [lindex $args 1] }
	    default {
		error "Unknown option $opt, expected one of -cname, or -pass-cdata"
	    }
        }
        set args [lrange $args 2 end]
    }

    incr aoffset ; # always include the command name.
    set adb [ArgsInprocess $adefs $aoffset]

    if {$acname} {
	BeginCommand static $name $adefs $rtype $body
	set ns  {}
	set cns {}
	set wname $name
	set cname c_$name
	if {$tname ne {}} {
	    set traceref \"$tname\"
	} else {
	    set traceref \"$name\"
	}
    } else {
	lassign [BeginCommand public $name $adefs $rtype $body] ns cns name cname
	set traceref ns_$cns$cname
	set wname    tcl_$cns$cname
	set cname    c_$cns$cname
    }

    set names  [dict get $adb names]
    set cargs  [dict get $adb csignature]
    set cnames [dict get $adb cnames]

    if {$passcd} {
	set cargs  [linsert $cargs 0 {ClientData clientdata}]
	set cnames [linsert $cnames 0 cd]
    }

    # Support code for argument conversions (i.e. structures, helper
    # functions, etc. ...)
    EmitSupport $adb

    # Emit either the low-level function, or, if it wasn't defined
    # here, a reference to the shim we can use.

    if {$body ne "#"} {
	Emit   "static [ResultCType $rtype] "
	Emitln "${cname}([join $cargs {, }])"
	Emit   \{\n

	at::caller
	at::incrt $name
	at::incrt $adefs
	at::incrt $rtype
	Transition9Check [at::raw] $body

	lassign [HeaderLines $body] leadoffset body
	if {$v::options(lines)} {
	    Emit [at::CPragma $leadoffset -2 $file]
	}
	Emit   $body
	Emitln \n\}
    } else {
	Emitln "#define $cname $name"
    }

    # Construct the shim handling the conversion between Tcl and C
    # realms.

    EmitShimHeader         $wname
    EmitShimVariables      $adb $rtype
    EmitArgTracing         $traceref
    EmitWrongArgsCheck     $adb
    Emit    [dict get $adb aconv]
    EmitCall               $cname $cnames $rtype
    EmitShimFooter         $adb $rtype
    EndCommand
    return
}

proc ::critcl::cinit {text edecls} {
    set file [SkipIgnored [set file [This]]]
    HandleDeclAfterBuild
    CInitCore $file $text $edecls
    return
}

proc ::critcl::CInitCore {file text edecls} {
    set digesta [UUID.extend $file .cinit.f $text]
    set digestb [UUID.extend $file .cinit.e $edecls]

    set initc {}
    set skip [Lines $text]
    lassign [HeaderLines $text] leadoffset text
    Transition9Check [at::Loc $leadoffset -2 $file] $text
    if {$v::options(lines)} {
	append initc [at::CPragma $leadoffset -2 $file]
    }
    append initc $text \n

    set edec {}
    lassign [HeaderLines $edecls] leadoffset edecls
    Transition9Check [at::Loc $leadoffset -2 $file] $edecls
    if {$v::options(lines)} {
	incr leadoffset $skip
	append edec [at::CPragma $leadoffset -2 $file]
    }
    append edec $edecls \n

    dict update v::code($file) config c {
	dict append  c initc  $initc \n
	dict append  c edecls $edec  \n
    }
    return
}

# # ## ### ##### ######## ############# #####################
## Public API to code origin handling.

namespace eval ::critcl::at {
    namespace export caller caller! here here! get get* raw raw* incr incrt =
    catch { namespace ensemble create }
}

# caller  - stash caller location, possibly modified (level change, line offset)
# caller! - format & return caller location, clears stash
# here    - stash current location
# here!   - return format & return  current location, clears stash
# incr*   - modify stashed location (only line number, not file).
# get     - format, return, and clear stash
# get*    - format & return stash

proc ::critcl::at::caller {{off 0} {level 0}} {
    ::incr level -3
    Where $off $level [::critcl::This]
    return
}

proc ::critcl::at::caller! {{off 0} {level 0}} {
    ::incr level -3
    Where $off $level [::critcl::This]
    return [get]
}

proc ::critcl::at::here {} {
    Where 0 -2 [::critcl::This]
    return
}

proc ::critcl::at::here! {} {
    Where 0 -2 [::critcl::This]
    return [get]
}

proc ::critcl::at::get {} {
    variable where
    if {!$::critcl::v::options(lines)} {
	return {}
    }
    if {![info exists where]} {
	return -code error "No location defined"
    }
    set result [Format $where]
    unset where
    return $result
}

proc ::critcl::at::raw {} {
    variable where
    if {![info exists where]} {
	return -code error "No location defined"
    }
    set result $where
    set where {}
    return $result
}

proc ::critcl::at::get* {} {
    variable where
    if {!$::critcl::v::options(lines)} {
	return {}
    }
    if {![info exists where]} {
	return -code error "No location defined"
    }
    return [Format $where]
}

proc ::critcl::at::raw* {} {
    variable where
    if {![info exists where]} {
	return -code error "No location defined"
    }
    return $where
}

proc ::critcl::at::= {file line} {
    variable where
    set where [list $file $line]
    return
}

proc ::critcl::at::incr {args} {
    variable where
    lassign $where file line
    foreach offset $args {
	::incr line $offset
    }
    set where [list $file $line]
    return
}

proc ::critcl::at::incrt {args} {
    variable where
    if {$where eq {}} {
	# Ignore problem when we have no precise locations.
	if {![interp debug {} -frame]} return
	return -code error "No location to change"
    }
    lassign $where file line
    foreach text $args {
	::incr line [::critcl::Lines $text]
    }
    set where [list $file $line]
    return
}

# # ## ### ##### ######## ############# #####################
## Implementation -- API: Input and Output control

proc ::critcl::collect {script {slot {}}} {
    collect_begin $slot
    uplevel 1 $script
    return [collect_end]
}

proc ::critcl::collect_begin {{slot {}}} {
    # Divert the collection of code fragments to slot
    # (output control). Stack on any previous diversion.
    variable v::this
    # See critcl::This for where this information is injected into the
    # code generation system.

    if {$slot eq {}} {
	set slot MEMORY[expr { [info exists this]
			       ? [llength $this]
			       : 0 }]
    }
    # Prefix prevents collision of slot names and file paths.
    lappend this critcl://$slot
    return
}

proc ::critcl::collect_end {} {
    # Stop last diversion, and return the collected information as
    # single string of C code.
    variable v::this
    # See critcl::This for where this information is injected into the
    # code generation system.

    # Ensure that a diversion is actually open.
    if {![info exists this] || ![llength $this]} {
	return -code error "collect_end mismatch, no diversions active"
    }

    set slot [Dpop]
    set block {}

    foreach digest [dict get $v::code($slot) config fragments] {
	append block "[Separator]\n\n"
	append block [dict get $v::code($slot) config block $digest]\n
    }

    # Drop all the collected data. Note how anything other than the C
    # code fragments is lost, and how cbuild results are removed
    # also. These do not belong anyway.
    unset v::code($slot)

    return $block
}


proc ::critcl::Dpop {} {
    variable v::this

    # Get current slot, and pop from the diversion stack.
    # Remove stack when it becomes empty.
    set slot [lindex $this end]
    set v::this [lrange $this 0 end-1]
    if {![llength $this]} {
	unset this
    }
    return $slot
}

proc ::critcl::include {path args} {
    # Include headers or other C files into the current code.
    set args [linsert $args 0 $path]
    msg "  (include <[join $args ">)\n  (include <"]>)"
    ccode "#include <[join $args ">\n#include <"]>"
}

proc ::critcl::make {path contents} {
    # Generate a header or other C file for pickup by other parts of
    # the current package. Stored in the cache dir, making it local.
    file mkdir [cache]
    set cname [file join [cache] $path]

    set c [open $cname.[pid] w]
    puts -nonewline $c $contents\n\n
    close $c
    file rename -force $cname.[pid] $cname

    return $path
}

proc ::critcl::source {path} {
    # Source a critcl file in the context of the current file,
    # i.e. [This]. Enables the factorization of a large critcl
    # file into smaller, easier to read pieces.
    SkipIgnored [set file [This]]
    HandleDeclAfterBuild

    msg "  (importing $path)"

    set undivert 0
    variable v::this
    if {![info exists this] || ![llength $this]} {
	# critcl::source is recording the critcl commands in the
	# context of the toplevel file which started the chain the
	# critcl::source. So why are we twiddling with the diversion
	# state?
	#
	# The condition above tells us that we are in the first
	# non-diverted critcl::source called by the context. [This]
	# returns that context. Due to our use of regular 'source' (*)
	# during its execution [This] would return the sourced file as
	# context. Wrong. Our fix for this is to perform, essentially,
	# an anti-diversion. Saving [This] as diversion, forces it to
	# return the proper value during the whole sourcing.
	#
	# And if the critcl::source is run in an already diverted
	# context then the changes to [info script] by 'source' do not
	# matter, making an anti-diversion unnecessary.
	#
	# Diversions inside of 'source' will work as usual, given
	# their nesting nature.
	#
	# (Ad *) And we use 'source' as only this ensures proper
	# collection of [info frame] location information.

	lappend this [This]
	set undivert 1
    }

    foreach f [Expand $file $path] {
	set v::source $f
	# The source file information is used by critcl::at::Where
	#uplevel 1 [Cat $f]
	uplevel #0 [list ::source $f]
	unset -nocomplain v::source
    }

    if {$undivert} Dpop
    return
}

# # ## ### ##### ######## ############# #####################
## Implementation -- API: Control & Interface

proc ::critcl::owns {args} {}

proc ::critcl::cheaders {args} {
    SkipIgnored [This]
    HandleDeclAfterBuild
    return [SetParam cheaders [ResolveRelative -I $args]]
}

proc ::critcl::csources {args} {
    SkipIgnored [This]
    HandleDeclAfterBuild
    return [SetParam csources $args 1 1 1]
}

proc ::critcl::clibraries {args} {
    SkipIgnored [This]
    HandleDeclAfterBuild
    return [SetParam clibraries [ResolveRelative {
	-L --library-directory
    } $args]]
}

proc ::critcl::cobjects {args} {
    SkipIgnored [This]
    HandleDeclAfterBuild
    return [SetParam cobjects $args]
}

proc ::critcl::tsources {args} {
    set file [SkipIgnored [This]]
    HandleDeclAfterBuild
    # Here, 'license', 'meta?' and 'meta' are the only places where we
    # are not extending the UUID. Because the companion Tcl sources
    # (count, order, and content) have no bearing on the binary at
    # all.
    InitializeFile $file

    set dfiles {}
    dict update v::code($file) config c {
	foreach f $args {
	    foreach e [Expand $file $f] {
		dict lappend c tsources $e
		lappend dfiles $e
	    }
	}
    }
    # Attention: The actual scanning is done outside of the `dict
    # update`, because it makes changes to the dictionary which would
    # be revert on exiting the update.
    foreach e $dfiles {
	ScanDependencies $file $e
    }
    return
}

proc ::critcl::cflags {args} {
    set file [SkipIgnored [This]]
    HandleDeclAfterBuild
    if {![llength $args]} return
    CFlagsCore $file $args
    return
}

proc ::critcl::CFlagsCore {file flags} {
    UUID.extend $file .cflags $flags
    dict update v::code($file) config c {
	foreach flag $flags {
	    dict lappend c cflags $flag
	}
    }
    return
}

proc ::critcl::ldflags {args} {
    set file [SkipIgnored [This]]
    HandleDeclAfterBuild
    if {![llength $args]} return

    UUID.extend $file .ldflags $args
    dict update v::code($file) config c {
	foreach flag $args {
	    # Drop any -Wl prefix which will be added back a moment
	    # later, otherwise it would be doubled, breaking the command.
	    regsub -all {^-Wl,} $flag {} flag
	    dict lappend c ldflags -Wl,$flag
	}
    }
    return
}

proc ::critcl::framework {args} {
    SkipIgnored [This]
    HandleDeclAfterBuild

    # Check if we are building for OSX and ignore the command if we
    # are not. Our usage of "actualtarget" means that we allow for a
    # cross-compilation environment to OS X as well.
    if {![string match "macosx*" [actualtarget]]} return

    foreach arg $args {
	# if an arg contains a slash it must be a framework path
	if {[string first / $arg] == -1} {
	    ldflags -framework $arg
	} else {
	    cflags  -F$arg
	    ldflags -F$arg
	}
    }
    return
}

proc ::critcl::tcl {version} {
    set file [SkipIgnored [This]]
    HandleDeclAfterBuild

    msg "  (tcl $version)"

    # When a minimum Tcl version is requested it can be assumed that the C code will work for that
    # version. Doing compatibility checks of any kind is not needed.
    config tcl9 0

    UUID.extend $file .mintcl $version
    dict set v::code($file) config mintcl $version

    # This is also a dependency to record in the meta data. A 'package
    # require' is not needed. This can be inside of the generated and
    # loaded C code.

    ImetaAdd $file require [list [list Tcl $version]]
    return
}

proc ::critcl::tk {} {
    set file [SkipIgnored [This]]
    HandleDeclAfterBuild

    msg "  (+tk)"

    UUID.extend $file .tk 1
    dict set v::code($file) config tk 1

    # This is also a dependency to record in the meta data. A 'package
    # require' is not needed. This can be inside of the generated and
    # loaded C code.

    ImetaAdd $file require Tk
    return
}

# Register a shared library for pre-loading - this will eventually be
# redundant when TIP #239 is widely available
proc ::critcl::preload {args} {
    set file [SkipIgnored [This]]
    HandleDeclAfterBuild
    if {![llength $args]} return

    UUID.extend $file .preload $args
    dict update v::code($file) config c {
	foreach lib $args {
	    dict lappend c preload $lib
	}
    }
    return
}

proc ::critcl::license {who args} {
    set file [SkipIgnored [This]]
    HandleDeclAfterBuild

    set who [string trim $who]
    if {$who ne ""} {
	set license "This software is copyrighted by $who.\n"
    } else {
	set license ""
    }

    set elicense [LicenseText $args]

    append license $elicense

    # This, 'tsources', 'meta?', and 'meta' are the only places where
    # we are not extending the UUID. Because the license text has no
    # bearing on the binary at all.
    InitializeFile $file

    ImetaSet $file license [Text2Words   $elicense]
    ImetaSet $file author  [Text2Authors $who]
    return
}

proc ::critcl::LicenseText {words} {
    if {[llength $words]} {
	# Use the supplied license details as our suffix.
	return [join $words]
    } else {
	# No details were supplied, fall back to the critcl license as
	# template for the generated package. This is found in a
	# sibling of this file.

	# We strip the first 2 lines from the file, this gets rid of
	# the author information for critcl itself, allowing us to
	# replace it by the user-supplied author.

	variable mydir
	set f [file join $mydir license.terms]
	return [join [lrange [split [Cat $f] \n] 2 end] \n]
    }
}

# # ## ### ##### ######## ############# #####################
## Implementation -- API: meta data (teapot)

proc ::critcl::description {text} {
    set file [SkipIgnored [This]]
    HandleDeclAfterBuild
    InitializeFile $file

    ImetaSet $file description [Text2Words $text]
    return
}

proc ::critcl::summary {text} {
    set file [SkipIgnored [This]]
    HandleDeclAfterBuild
    InitializeFile $file

    ImetaSet $file summary [Text2Words $text]
    return
}

proc ::critcl::subject {args} {
    set file [SkipIgnored [This]]
    HandleDeclAfterBuild
    InitializeFile $file

    ImetaAdd $file subject $args
    return
}

proc ::critcl::meta {key args} {
    set file [SkipIgnored [This]]
    HandleDeclAfterBuild

    # This, 'meta?', 'license', and 'tsources' are the only places
    # where we are not extending the UUID. Because the meta data has
    # no bearing on the binary at all.
    InitializeFile $file

    dict update v::code($file) config c {
	dict update c meta m {
	    foreach v $args { dict lappend m $key $v }
	}
    }
    return
}

proc ::critcl::meta? {key} {
    set file [SkipIgnored [This]]
    HandleDeclAfterBuild

    # This, 'meta', 'license', and 'tsources' are the only places
    # where we are not extending the UUID. Because the meta data has
    # no bearing on the binary at all.
    InitializeFile $file

    if {[dict exists $v::code($file) config package $key]} {
	return [dict get $v::code($file) config package $key]
    }
    if {[dict exists $v::code($file) config meta $key]} {
	return [dict get $v::code($file) config meta $key]
    }
    return -code error "Unknown meta data key \"$key\""
}

proc ::critcl::ImetaSet {file key words} {
    dict set v::code($file) config package $key $words
    #puts |||$key|%|[dict get $v::code($file) config package $key]|
    return
}

proc ::critcl::ImetaAdd {file key words} {
    dict update v::code($file) config c {
	dict update c package p {
	    foreach word $words {
		dict lappend p $key $word
	    }
	}
    }
    #puts XXX|$file||$key|+|[dict get $v::code($file) config package $key]|
    return
}

proc ::critcl::Text2Words {text} {
    regsub -all {[ \t\n]+} $text { } text
    return [split [string trim $text]]
}

proc ::critcl::Text2Authors {text} {
    regsub -all {[ \t\n]+} $text { } text
    set authors {}
    foreach a [split [string trim $text] ,] {
	lappend authors [string trim $a]
    }
    return $authors
}

proc ::critcl::GetMeta {file} {
    if {![dict exists $v::code($file) config meta]} {
	set result {}
    } else {
	set result [dict get $v::code($file) config meta]
    }

    # Merge the package information (= system meta data) with the
    # user's meta data. The system information overrides anything the
    # user may have declared for the reserved keys (name, version,
    # platform, as::author, as::build::date, license, description,
    # summary, require). Note that for the internal bracketing code
    # the system information may not exist, hence the catch. Might be
    # better to indicate the bracket somehow and make it properly
    # conditional.

    #puts %$file

    catch {
	set result [dict merge $result [dict get $v::code($file) config package]]
    }

    # A few keys need a cleanup, i.e. removal of duplicates, and the like
    catch {
	dict set result require         [lsort -dict -unique [dict get $result require]]
    }
    catch {
	dict set result build::require  [lsort -dict -unique [dict get $result build::require]]
    }
    catch {
	dict set result platform        [lindex [dict get $result platform] 0]
    }
    catch {
	dict set result generated::by   [lrange [dict get $result generated::by] 0 1]
    }
    catch {
	dict set result generated::date [lindex [dict get $result generated::by] 0]
    }

    #array set ___M $result ; parray ___M ; unset ___M
    return $result
}

# # ## ### ##### ######## ############# #####################
## Implementation -- API: user configuration options.

proc ::critcl::userconfig {cmd args} {
    set file [SkipIgnored [This]]
    HandleDeclAfterBuild
    InitializeFile $file

    if {![llength [info commands ::critcl::UC$cmd]]} {
	return -code error "Unknown method \"$cmd\""
    }

    # Dispatch
    return [eval [linsert $args 0 ::critcl::UC$cmd $file]]
}

proc ::critcl::UCdefine {file oname odesc otype {odefault {}}} {
    # When declared without a default determine one of our own. Bool
    # flag default to true, whereas enum flags, which is the rest,
    # default to their first value.

    # The actual definition ignores the config description. This
    # argument is only used by the static code scanner supporting
    # TEA. See ::critcl::scan::userconfig.

    if {[llength [info level 0]] < 6} {
	set odefault [UcDefault $otype]
    }

    # Validate the default against the type too, before saving
    # everything.
    UcValidate $oname $otype $odefault

    UUID.extend $file .uc-def [list $oname $otype $odefault]

    dict set v::code($file) config userflag $oname type    $otype
    dict set v::code($file) config userflag $oname default $odefault
    return
}

proc ::critcl::UCset {file oname value} {
    # NOTE: We can set any user flag we choose, even if not declared
    # yet. Validation of the value happens on query, at which time the
    # flag must be declared.

    dict set v::code($file) config userflag $oname value $value
    return
}

proc ::critcl::UCquery {file oname} {
    # Prefer cached data. This is known as declared, defaults merged,
    # validated.
    if {[dict exists $v::code($file) config userflag $oname =]} {
	return [dict get $v::code($file) config userflag $oname =]
    }

    # Reject use of undeclared user flags.
    if {![dict exists $v::code($file) config userflag $oname type]} {
	error "Unknown user flag \"$oname\""
    }

    # Check if a value was supplied by the calling app. If not, fall
    # back to the declared default.

    if {[dict exists $v::code($file) config userflag $oname value]} {
	set value [dict get $v::code($file) config userflag $oname value]
    } else {
	set value [dict get $v::code($file) config userflag $oname default]
    }

    # Validate value against the flag's type.
    set otype [dict get $v::code($file) config userflag $oname type]
    UcValidate $oname $otype $value

    # Fill cache
    dict set v::code($file) config userflag $oname = $value
    return $value
}

proc ::critcl::UcValidate {oname otype value} {
    switch -exact -- $otype {
	bool {
	    if {![string is bool -strict $value]} {
		error "Expected boolean for user flag \"$oname\", got \"$value\""
	    }
	}
	default {
	    if {[lsearch -exact $otype $value] < 0} {
		error "Expected one of [linsert [join $otype {, }] end-1 or] for user flag \"$oname\", got \"$value\""
	    }
	}
    }
}

proc ::critcl::UcDefault {otype} {
    switch -exact -- $otype {
	bool {
	    return 1
	}
	default {
	    return [lindex $otype 0]
	}
    }
}

# # ## ### ##### ######## ############# #####################
## Implementation -- API: API (stubs) management

proc ::critcl::api {cmd args} {
    set file [SkipIgnored [This]]
    HandleDeclAfterBuild

    if {![llength [info commands ::critcl::API$cmd]]} {
	return -code error "Unknown method \"$cmd\""
    }

    # Dispatch
    return [eval [linsert $args 0 ::critcl::API$cmd $file]]
}

proc ::critcl::APIscspec {file scspec} {
    UUID.extend $file .api-scspec $scspec
    dict set v::code($file) config api_scspec $scspec
    return
}

proc ::critcl::APIimport {file name version} {

    # First we request the imported package, giving it a chance to
    # generate the headers searched for in a moment (maybe it was
    # critcl based as well, and generates things dynamically).

    # Note that this can fail, for example in a cross-compilation
    # environment. Such a failure however does not imply that the
    # required API headers are not present, so we can continue.

    catch {
	package require $name $version
    }

    ImetaAdd $file require [list [list $name $version]]

    # Now we check that the relevant headers of the imported package
    # can be found in the specified search paths.

    set cname [string map {:: _} $name]

    set at [API_locate $cname searched]
    if {$at eq {}} {
	error "Headers for API $name not found in \n-\t[join $searched \n-\t]"
    } else {
	msg "  (stubs import $name $version @ $at/$cname)"
    }

    set def [list $name $version]
    UUID.extend $file .api-import $def
    dict update v::code($file) config c {
	dict lappend c api_use $def
    }

    # At last look for the optional .decls file. Ignore if there is
    # none. Decode and return contained stubs table otherwise.

    set decls $at/$cname/$cname.decls
    if {[file exists $decls]} {
	package require stubs::reader
	set T [stubs::container::new]
	stubs::reader::file T $decls
	return $T
    }
    return
}

proc ::critcl::APIexport {file name} {
    msg "  (stubs export $name)"

    UUID.extend $file .api-self $name
    return [dict set v::code($file) config api_self $name]
}

proc ::critcl::APIheader {file args} {
    UUID.extend $file .api-headers $args
    return [SetParam api_hdrs $args]
}

proc ::critcl::APIextheader {file args} {
    UUID.extend $file .api-eheaders $args
    return [SetParam api_ehdrs $args 0]
}

proc ::critcl::APIfunction {file rtype name arguments} {
    package require stubs::reader

    # Generate a declaration as it would have come straight out of the
    # stubs reader. To this end we generate a C code fragment as it
    # would be have been written inside of a .decls file.

    # TODO: We should record this as well, and later generate a .decls
    # file as part of the export. Or regenerate it from the internal
    # representation.

    if {[llength $arguments]} {
	foreach {t a} $arguments {
	    lappend ax "$t $a"
	}
    } else {
	set ax void
    }
    set decl [stubs::reader::ParseDecl "$rtype $name ([join $ax ,])"]

    UUID.extend $file .api-fun $decl
    dict update v::code($file) config c {
	dict lappend c api_fun $decl
    }
    return
}

proc ::critcl::API_locate {name sv} {
    upvar 1 $sv searched
    foreach dir [SystemIncludePaths [This]] {
	    lappend searched $dir
	if {[API_at $dir $name]} { return $dir }
    }
    return {}
}

proc ::critcl::API_at {dir name} {
    foreach suffix {
	Decls.h StubLib.h
    } {
	if {![file exists [file join $dir $name $name$suffix]]} { return 0 }
    }
    return 1
}

proc ::critcl::API_setup {file} {
    package require stubs::gen

    lassign [API_setup_import $file] iprefix idefines
    dict set v::code($file) result apidefines $idefines

    append prefix $iprefix
    append prefix [API_setup_export $file]

    # Save prefix to result dictionary for pickup by Compile.
    if {$prefix eq ""} return

    dict set v::code($file) result apiprefix  $prefix\n
    return
}

proc ::critcl::API_setup_import {file} {
    if {![dict exists $v::code($file) config api_use]} {
	return ""
    }

    #msg -nonewline " (stubs import)"

    set prefix ""
    set defines {}

    foreach def [dict get $v::code($file) config api_use] {
	lassign $def iname iversion

	set cname   [string map {:: _} $iname]
	set upname  [string toupper  $cname]
	set capname [stubs::gen::cap $cname]

	set import [critcl::at::here!][subst -nocommands {
	    /* Import API: $iname */
	    #define USE_${upname}_STUBS 1
	    #include <$cname/${cname}Decls.h>
	}]
	append prefix \n$import
	CCodeCore $file $import

	# TODO :: DOCUMENT environment of the cinit code.
	CInitCore $file [subst -nocommands {
	    if (!${capname}_InitStubs (ip, "$iversion", 0)) {
		return TCL_ERROR;
	    }
	}] [subst -nocommands {
	    #include <$cname/${cname}StubLib.h>
	}]

	lappend defines -DUSE_${upname}_STUBS=1
    }

    return [list $prefix $defines]
}

proc ::critcl::API_setup_export {file} {
    if {![dict exists $v::code($file) config api_hdrs] &&
	![dict exists $v::code($file) config api_ehdrs] &&
	![dict exists $v::code($file) config api_fun]} return

    if {[dict exists $v::code($file) config api_self]} {
	# API name was declared explicitly
	set ename [dict get $v::code($file) config api_self]
    } else {
	# API name is implicitly defined, is package name.
	set ename [dict get $v::code($file) config package name]
    }

    set prefix ""

    #msg -nonewline " (stubs export)"

    set cname   [string map {:: _} $ename]
    set upname  [string toupper  $cname]
    set capname [stubs::gen::cap $cname]

    set import [at::here!][subst -nocommands {
	/* Import our own exported API: $ename, mapping disabled */
	#undef USE_${upname}_STUBS
	#include <$cname/${cname}Decls.h>
    }]
    append prefix \n$import
    CCodeCore $file $import

    # Generate the necessary header files.

    append sdecls "\#ifndef ${cname}_DECLS_H\n"
    append sdecls "\#define ${cname}_DECLS_H\n"
    append sdecls "\n"
    append sdecls "\#include <tcl.h>\n"

    if {[dict exists $v::code($file) config api_ehdrs]} {
	append sdecls "\n"
	file mkdir [cache]/$cname
	foreach hdr [dict get $v::code($file) config api_ehdrs] {
	    append sdecls "\#include \"[file tail $hdr]\"\n"
	}
    }

    if {[dict exists $v::code($file) config api_hdrs]} {
	append sdecls "\n"
	file mkdir [cache]/$cname
	foreach hdr [dict get $v::code($file) config api_hdrs] {
	    Copy $hdr [cache]/$cname
	    append sdecls "\#include \"[file tail $hdr]\"\n"
	}
    }

    # Insert code to handle the storage class settings on Windows.

    append sdecls [string map \
		       [list @cname@ $cname @up@ $upname] \
		       $v::storageclass]

    package require stubs::container
    package require stubs::reader
    package require stubs::gen
    package require stubs::gen::header
    package require stubs::gen::init
    package require stubs::gen::lib
    package require stubs::writer

    # Implied .decls file. Not actually written, only implied in the
    # stubs container invocations, as if read from such a file.

    set T [stubs::container::new]
    stubs::container::library   T $ename
    stubs::container::interface T $cname

    if {[dict exists $v::code($file) config api_scspec]} {
	stubs::container::scspec T \
	    [dict get $v::code($file) config api_scspec]
    }

    if {[dict exists $v::code($file) config api_fun]} {
	set index 0
	foreach decl [dict get $v::code($file) config api_fun] {
	    #puts D==|$decl|
	    stubs::container::declare T $cname $index generic $decl
	    incr index
	}
	append sdecls "\n"
	append sdecls [stubs::gen::header::gen $T $cname]
    }

    append sdecls "\#endif /* ${cname}_DECLS_H */\n"

    set comment "/* Stubs API Export: $ename */"

    set    thedecls [stubs::writer::gen $T]
    set    slib     [stubs::gen::lib::gen $T]
    set    sinitstatic "  $comment\n  "
    append sinitstatic [stubs::gen::init::gen $T]

    set pn [dict get $v::code($file) config package name]
    set pv [dict get $v::code($file) config package version]

    set    sinitrun $comment\n
    append sinitrun "Tcl_PkgProvideEx (ip, \"$pn\", \"$pv\", (ClientData) &${cname}Stubs);"

    # Save the header files to the result cache for pickup (importers
    # in mode "compile & run", or by the higher-level code doing a
    # "generate package")

    WriteCache $cname/${cname}Decls.h   $sdecls
    WriteCache $cname/${cname}StubLib.h $slib
    WriteCache $cname/${cname}.decls    $thedecls

    dict update v::code($file) result r {
	dict lappend r apiheader [file join [cache] $cname]
    }

    CInitCore  $file $sinitrun $sinitstatic
    CFlagsCore $file [list -DBUILD_$cname]

    return $prefix
}

# # ## ### ##### ######## ############# #####################
## Implementation -- API: Introspection

proc ::critcl::check {args} {
    set file [SkipIgnored [This] 0]
    HandleDeclAfterBuild

    switch -exact -- [llength $args] {
	1 {
	    set label Checking
	    set code  [lindex $args 0]
	}
	2 {
	    lassign $args label code
	}
	default {
	    return -code error "wrong#args: Expected ?label? code"
	}
    }

    set src [WriteCache check_[pid].c $code]
    set obj [file rootname $src][getconfigvalue object]

    # See also the internal helper 'Compile'. Thre code here is in
    # essence a simplified form of that.

    set         cmdline [getconfigvalue compile]
    lappendlist cmdline [GetParam $file cflags]
    lappendlist cmdline [SystemIncludes $file]
    lappendlist cmdline [CompileResult $obj]
    lappend     cmdline $src

    LogOpen $file
    Log* "${label}... "
    StatusReset
    set ok [ExecWithLogging $cmdline OK FAILED]
    StatusReset

    LogClose
    clean_cache check_[pid].*
    return $ok
}

proc ::critcl::checklink {args} {
    set file [SkipIgnored [This] 0]
    HandleDeclAfterBuild

    switch -exact -- [llength $args] {
	1 {
	    set label Checking
	    set code  [lindex $args 0]
	}
	2 {
	    lassign $args label code
	}
	default {
	    return -code error "wrong#args: Expected ?label? code"
	}
    }

    set src [WriteCache check_[pid].c $code]
    set obj [file rootname $src][getconfigvalue object]

    # See also the internal helper 'Compile'. Thre code here is in
    # essence a simplified form of that.

    set         cmdline [getconfigvalue compile]
    lappendlist cmdline [GetParam $file cflags]
    lappendlist cmdline [SystemIncludes $file]
    lappendlist cmdline [CompileResult $obj]
    lappend     cmdline $src

    LogOpen $file
    Log* "${label} (build)... "
    StatusReset
    set ok [ExecWithLogging $cmdline OK FAILED]
    StatusReset

    if {!$ok} {
	LogClose
	clean_cache check_[pid].*
	return 0
    }

    set out [file join [cache] a_[pid].out]
    set cmdline [getconfigvalue link]

    if {$option::debug_symbols} {
	lappendlist cmdline [getconfigvalue link_debug]
    } else {
	lappendlist cmdline [getconfigvalue strip]
	lappendlist cmdline [getconfigvalue link_release]
    }

    lappendlist cmdline [LinkResult $out]
    lappendlist cmdline $obj
    lappendlist cmdline [SystemLibraries]
    lappendlist cmdline [FixLibraries [GetParam $file clibraries]]
    lappendlist cmdline [GetParam $file ldflags]

    Log* "${label} (link)... "
    StatusReset
    set ok [ExecWithLogging $cmdline OK ERR]

    LogClose
    clean_cache check_[pid].* a_[pid].*
    return $ok
}

proc ::critcl::compiled {} {
    SkipIgnored [This] 1
    HandleDeclAfterBuild
    return 0
}

proc ::critcl::compiling {} {
    SkipIgnored [This] 0
    HandleDeclAfterBuild
    # Check that we can indeed run a compiler
    # Should only need to do this if we have to compile the code?
    if {[auto_execok [lindex [getconfigvalue compile] 0]] eq ""} {
	set v::compiling 0
    } else {
	set v::compiling 1
    }
    return $v::compiling
}

proc ::critcl::done {} {
    set file [SkipIgnored [This] 1]
    return [expr {[info exists  v::code($file)] &&
		  [dict exists $v::code($file) result closed]}]
}

proc ::critcl::failed {} {
    SkipIgnored [This] 0
    if {$v::buildforpackage} { return 0 }
    return [cbuild [This] 0]
}

proc ::critcl::load {} {
    SkipIgnored [This] 1
    if {$v::buildforpackage} { return 1 }
    return [expr {![cbuild [This]]}]
}

# # ## ### ##### ######## ############# #####################
## Default error behaviour

proc ::critcl::error {msg} {
    return -code error $msg
}

# # ## ### ##### ######## ############# #####################
## Default message behaviour

proc ::critcl::msg {args} {
    # ignore message (compile & run)
}

# # ## ### ##### ######## ############# #####################
## Default print behaviour

proc ::critcl::print {args} {
    # API same as for builtin ::puts. Use as is.
    return [eval [linsert $args 0 ::puts]]
}

# # ## ### ##### ######## ############# #####################
## Runtime support to handle the possibility of a prebuilt package using
## the .tcl file with embedded C as its own companon defining regular
## Tcl code for the package as well. If the critcl package is loaded
## already this will cause it to ignore the C definitions, with best
## guesses for failed, done, load, check, compiled, and compiling.

proc ::critcl::Ignore {f} {
    set v::ignore([file normalize $f]) .
    return
}

proc ::critcl::SkipIgnored {f {result {}}} {
    if {[info exists v::ignore($f)]} { return -code return $result }
    return $f
}

# # ## ### ##### ######## ############# #####################
## Implementation -- API: Build Management

proc ::critcl::config {option args} {
    if {![info exists v::options($option)] || [llength $args] > 1} {
	error "option must be one of: [lsort [array names v::options]]"
    }
    if {![llength $args]} {
	return $v::options($option)
    }
    set v::options($option) [lindex $args 0]
}

proc ::critcl::debug {args} {
    # Replace 'all' everywhere, and squash duplicates, whether from
    # this, or user-specified.
    set args [string map {all {memory symbols}} $args]
    set args [lsort -unique $args]

    foreach arg $args {
	switch -- $arg {
	    memory  { foreach x [getconfigvalue debug_memory]  { cflags $x } }
	    symbols { foreach x [getconfigvalue debug_symbols] { cflags $x }
		set option::debug_symbols 1
	    }
	    default {
		error "unknown critcl::debug option - $arg"
	    }
	}
    }
    return
}

# # ## ### ##### ######## ############# #####################
## Implementation -- API: Result Cache

proc ::critcl::cache {{dir ""}} {
    if {[llength [info level 0]] == 2} {
	set v::cache [file normalize $dir]
    }
    return $v::cache
}

proc ::critcl::clean_cache {args} {
    if {![llength $args]} { lappend args * }
    foreach pattern $args {
	foreach file [glob -nocomplain -directory $v::cache $pattern] {
	    file delete -force $file
	}
    }
    return
}

# # ## ### ##### ######## ############# #####################
## Implementation -- API: Build Configuration
# read toolchain information from config file

proc ::critcl::readconfig {config} {
    variable run
    variable configfile $config

    set cfg [open $config]
    set knowntargets [list]
    set cont ""
    set whenplat ""

    interp eval $run set platform $v::buildplatform

    set i 0
    while {[gets $cfg line] >= 0} {
	incr i
	if {[set line [string trim $line]] ne ""} {
	    # config lines can be continued using trailing backslash
	    if {[string index $line end] eq "\\"} {
		append cont " [string range $line 0 end-1]"
		continue
	    }
	    if {$cont ne ""} {
		append cont $line
		set line [string trim $cont]
		set cont ""
	    }

	    # At this point we have a complete line/command in 'line'.
	    # We expect the following forms of input:
	    #
	    # (1.) if {...} {.............} - Tcl command, run in the
	    #                                 backend interpreter.
	    #                                 Note that this can EXIT
	    #                                 the application using
	    #                                 the critcl package.
	    # (2.)  set VAR VALUE.......... - Ditto.
	    # (3.)  # ..................... - Comment. Skipped
	    # (4.) PLATFORM VAR VALUE...... - Platform-specific
	    #                                 configuration variable
	    #                                 and value.

	    # (4a) PLATFORM when .........  - Makes the PLATFORM
	    #                                 conditional on the
	    #                                 expression after the
	    #                                 'when' keyword. This
	    #                                 uses variables set by
	    #                                 (1) and/or (2). The
	    #                                 expression is run in the
	    #                                 backend interpreter. If
	    #                                 and only if PLATFORM is
	    #                                 a prefix of the current
	    #                                 build platform, or the
	    #                                 reverse, then the code
	    #                                 with an TRUE when is
	    #                                 chosen as the
	    #                                 configuration.

	    # (4b) PLATFORM target ?actual? - Marks the platform as a
	    #                                 cross-compile target,
	    #                                 and actual is the
	    #                                 platform identifier of
	    #                                 the result. If not
	    #                                 specified it defaults to
	    #                                 PLATFORM.
            # (4c) PLATFORM copy PARENT...  - Copies the currently defined
            #                                 configuration variables and
            #                                 values to the settings for
            #                                 this platform.
	    # (5.) VAR VALUE............... - Default configuration
	    #                                 variable, and value.

	    set plat [lindex [split $line] 0]

	    # (1), or (2)
	    if {$plat eq "set" || $plat eq "if"} {
		while {![info complete $line] && ![eof $cfg]} {
		    if {[gets $cfg more] == -1} {
			set msg "incomplete command in Critcl Config file "
			append msg "starting at line $i"
			error $msg
		    }
		    append line  "\n$more"

		}
		interp eval $run $line
		continue
	    }

	    # (3)
	    if {$plat eq "#"} continue

	    # (4), or (5).
	    if {[lsearch -exact $v::configvars $plat] != -1} {
		# (5) default config option
		set cmd ""
		if {![regexp {(\S+)\s+(.*)} $line -> type cmd]} {
		    # cmd is empty
		    set type $plat
		    set cmd ""
		}
		set plat ""
	    } else {
		# (4) platform config option
		if {![regexp {(\S+)\s+(\S+)\s+(.*)} $line -> p type cmd]} {
		    # cmd is empty
		    set type [lindex $line 1]
		    set cmd ""
		}

		# (4a) if and only if either build platform or config
		#      code are a prefix of each other can the 'when'
		#      condition be evaluated and override the
		#      standard selection for the configuration.

		if {$type eq "when" &&
		    ( [string match ${v::buildplatform}* $plat] ||
		      [string match ${plat}* $v::buildplatform] )} {
		    set res ""
		    catch {
			set res [interp eval $run expr $cmd]
		    }
		    switch $res {
			"" -
			0 { set whenfalse($plat) 1 }
			1 { set whenplat $plat }
		    }
		}
		lappend knowntargets $plat
	    }

            switch -exact -- $type {
                target {
                    # (4b) cross compile target.
                    # cmd = actual target platform identifier.
                    if {$cmd eq ""} {
                        set cmd $plat
                    }
                    set v::xtargets($plat) $cmd
                }
                copy {
                    # (4c) copy an existing config
                    # XXX - should we error out if no definitions exist
                    # for parent platform config
                    # $cmd contains the parent platform
                    foreach {key val} [array get v::toolchain "$cmd,*"] {
                        set key [lindex [split $key ,] 1]
                        set v::toolchain($plat,$key) $val
                    }
                }
                default {
                    set v::toolchain($plat,$type) $cmd
                }
	    }
	}
    }
    set knowntargets [lsort -unique $knowntargets]
    close $cfg

    # Config file processing has completed.
    # Now select the platform to configure the
    # compiler backend with.

    set v::knowntargets $knowntargets

    # The config file may have selected a configuration based on the
    # TRUE when conditions. Which were matched to v::buildplatform,
    # making the chosen config a variant of it. If that did not happen
    # a platform is chosen from the set of defined targets.
    if {$whenplat ne ""} {
	set match [list $whenplat]
    } else {
	set match [critcl::chooseconfig $v::buildplatform]
    }

    # Configure the backend.

    setconfig ""    ;# defaults
    if {[llength $match]} {
	setconfig [lindex $match 0]
    } else {
	setconfig $v::buildplatform
    }
    return
}

proc ::critcl::chooseconfig {targetconfig {err 0}} {
    # first try to match exactly
    set match [lsearch -exact -all -inline $v::knowntargets $targetconfig]

    # on failure, try to match as glob pattern
    if {![llength $match]} {
        set match [lsearch -glob -all -inline $v::knowntargets $targetconfig]
    }

    # on failure, error out if requested
    if {![llength $match] && $err} {
	error "unknown target $targetconfig - use one of $v::knowntargets"
    }
    return $match
}

proc ::critcl::showconfig {{fd ""}} {
    variable run
    variable configfile

    # XXX replace gen - v::buildplatform
    # XXX Do not use v::targetplatform here. Use v::config.
    # XXX Similarly in setconfig.

    set gen $v::buildplatform
    if {$v::targetplatform eq ""} {
	set plat "default"
    } else {
	set plat $v::targetplatform
    }
    set out [list]
    if {$plat eq $gen} {
	lappend out "Config: $plat"
    } else {
	lappend out "Config: $plat (built on $gen)"
    }
    lappend out "Origin: $configfile"
    lappend out "    [format %-15s cache] [cache]"
    foreach var [lsort $v::configvars] {
	set val [getconfigvalue $var]
	set line "    [format %-15s $var]"
	foreach word [split [string trim $val]] {
	    if {[set word [string trim $word]] eq ""} continue
	    if {[string length "$line $word"] > 70} {
		lappend out "$line \\"
		set line "    [format %-15s { }] $word"
	    } else {
		set line "$line $word"
	    }
	}
	lappend out $line
    }
    # Tcl variables - Combined LengthLongestWord (all), and filtering
    set vars [list]
    set max 0
    foreach idx [array names v::toolchain $v::targetplatform,*] {
	set var [lindex [split $idx ,] 1]
	if {[set len [string length $var]] > $max} {
	    set max $len
	}
	if {$var ne "when" && ![info exists c::$var]} {
	    lappend vars $idx $var
	}
    }
    if {[llength $vars]} {
	lappend out "Tcl variables:"
	foreach {idx var} $vars {
	    set val $v::toolchain($idx)
	    if {[llength $val] == 1} {
		# for when someone inevitably puts quotes around
		# values - e.g. "Windows NT"
		set val [lindex $val 0]
	    }
	    lappend out "    [PadRight $max $var] $val"
	}
    }
    set out [join $out \n]
    if {$fd ne ""} {
	puts $fd $out
    } else {
	return $out
    }
}

proc ::critcl::showallconfig {{ofd ""}} {
    variable configfile
    set txt [Cat $configfile]
    if {$ofd ne ""} {
	puts $ofd $txt
    } else {
	return $txt
    }
}

proc ::critcl::setconfig {targetconfig} {
    global env
    set v::targetconfig   $targetconfig

    # Strip the compiler information from the configuration to get the
    # platform identifier embedded into it. This is a semi-recurrence
    # of the original hardwired block handling win32/gcc/cl. We can
    # partly emulate this with 'platform' directives in the Config
    # file, however this breaks down when trying to handle the default
    # settings. I.e. something like FOO-gcc which has no configuration
    # block in the file uses the defaults, and thus has no proper
    # place for a custom platform directive. So we have to do it here,
    # in code. For symmetry the other compilers (-cc, -cl) are handled
    # as well.

    set v::targetplatform $targetconfig
    foreach p {gcc cc_r xlc xlc_r cc cl clang([[:digit:]])*} {
	if {[regsub -- "-$p\$" $v::targetplatform {} v::targetplatform]} break
    }

    set c::platform     ""
    set c::sharedlibext ""

    foreach var $v::configvars {
	if {[info exists v::toolchain($targetconfig,$var)]} {

	    set c::$var $v::toolchain($targetconfig,$var)

	    if {$var eq "platform"} {
		set px [getconfigvalue platform]
		set v::targetplatform [lindex $px 0]
		set v::version        [lindex $px 1]
	    }
	}
    }
    if {[info exists env(CFLAGS)]} {
	variable c::compile
	append   c::compile      " $env(CFLAGS)"
    }
    if {[info exists env(LDFLAGS)]} {
	variable c::link
	append   c::link         " $env(LDFLAGS)"
	append   c::link_preload " $env(LDFLAGS)"
    }
    if {[string match $v::targetplatform $v::buildplatform]} {
	# expand platform to match host if it contains wildcards
	set v::targetplatform $v::buildplatform
    }
    if {$c::platform eq ""} {
	# default config platform (mainly for the "show" command)
	set c::platform $v::targetplatform
    }
    if {$c::sharedlibext eq ""} {
	set c::sharedlibext [info sharedlibextension]
    }

    # The following definition of the cache directory is only relevant
    # for mode "compile & run". The critcl application handling the
    # package mode places the cache in a process-specific location
    # without care about platforms. For here this means that we can
    # ignore both cross-compilation, and the user choosing a target
    # for us, as neither happens nor works for "compile & run". We can
    # assume that build and target platforms will be the same, be the
    # current platform, and we can make a simple choice for the
    # directory.

    cache [file join $env(HOME) .critcl [platform::identify]]

    # Initialize Tcl variables based on the chosen tooling
    foreach idx [array names v::toolchain $v::targetplatform,*] {
	set var [lindex [split $idx ,] 1]
	if {![info exists c::$var]} {
	    set val $v::toolchain($idx)
	    if {[llength $val] == 1} {
		# for when someone inevitably puts quotes around
		# values - e.g. "Windows NT"
		set val [lindex $val 0]
	    }
	    set $var $val
	}
    }
    return
}

proc ::critcl::getconfigvalue {var} {
    variable run
    if {[catch {set val [interp eval $run [list subst [set c::$var]]]}]} {
	set val [set c::$var]
    }
    return $val
}

# # ## ### ##### ######## ############# #####################
## Implementation -- API: Application

# The regular commands used by the application, defined in other
# sections of the package are:
#
# C critcl::cache
# C critcl::ccode
# C critcl::chooseconfig
# C critcl::cinit
# C critcl::clean_cache
# C critcl::clibraries
# C critcl::cobjects
# C critcl::config I, L, lines, force, keepsrc, combine, trace, tcl9, outdir
# C critcl::debug
# C critcl::error               | App overrides our implementation.
# C critcl::getconfigvalue
# C critcl::lappendlist
# C critcl::ldflags
# C critcl::preload
# C critcl::readconfig
# C critcl::setconfig
# C critcl::showallconfig
# C critcl::showconfig

proc ::critcl::crosscheck {} {
    variable run
    global tcl_platform

    if {$tcl_platform(platform) eq "windows"} {
	set null NUL:
    } else {
	set null /dev/null
    }

    if {![catch {
	set     cmd [linsert $c::version 0 exec]
	lappend cmd 2> $null;#@stdout
	set config [interp eval $run $cmd]
    } msg]} {
	set host ""
	set target ""
	foreach line $config {
	    foreach arg [split $line] {
		if {[string match "--*" $arg]} {
		    lassign [split [string trim $arg -] =] cfg val
		    set $cfg $val
		}
	    }
	}
	if {$host ne $target && [info exists v::xtargets($target)]} {
	    setconfig $target
	    print stderr "Cross compiling using $target"
	}
	# XXX host != target, but not know as config ?
	# XXX Currently ignored.
	# XXX Throwing an error better ?
    }
    return
}

# See (XX) at the end of the file (package state variable setup)
# for explanations of the exact differences between these.

proc ::critcl::knowntargets {} {
    return $v::knowntargets
}

proc ::critcl::targetconfig {} {
    return $v::targetconfig
}

proc ::critcl::targetplatform {} {
    return $v::targetplatform
}

proc ::critcl::buildplatform {} {
    return $v::buildplatform
}

proc ::critcl::actualtarget {} {
    # Check if the chosen target is a cross-compile target.  If yes,
    # we return the actual platform identifier of the target. This is
    # used to select the proper platform director names in the critcl
    # cache, generated packages, when searching for preload libraries,
    # etc. Whereas the chosen target provides the proper compile
    # configuration which will invoke the proper cross-compiler, etc.

    if {[info exists v::xtargets($v::targetplatform)]} {
	return $v::xtargets($v::targetplatform)
    } else {
	return $v::targetplatform
    }
}

proc ::critcl::sharedlibext {} {
    return [getconfigvalue sharedlibext]
}

proc ::critcl::buildforpackage {{buildforpackage 1}} {
    set v::buildforpackage $buildforpackage
    return
}

proc ::critcl::fastuuid {} {
    set v::uuidcounter 1 ;# Activates it.
    return
}

proc ::critcl::cbuild {file {load 1}} {
    if {[info exists v::code($file,failed)] && !$load} {
	set v::buildforpackage 0
	return $v::code($file,failed)
    }

    StatusReset

    # Determine if we should place stubs code into the generated file.
    set placestubs [expr {!$v::buildforpackage}]

    # Determine the requested mode and reset for next call.
    set buildforpackage $v::buildforpackage
    set v::buildforpackage 0

    if {$file eq ""} {
	set file [This]
    }

    # NOTE: The 4 pieces of data just below has to be copied into the
    # result even if the build and link-steps are suppressed. Because
    # the load-step must have this information.

    set shlib    [DetermineShlibName $file]
    set initname [DetermineInitName  $file [expr {$buildforpackage ? "ns" : ""}]]

    dict set v::code($file) result tsources   [GetParam $file tsources]
    dict set v::code($file) result mintcl     [MinTclVersion $file]

    set emsg {}
    set msgs {}

    if {$v::options(force) || ![file exists $shlib]} {
	LogOpen $file
	set base   [BaseOf              $file]
	set object [DetermineObjectName $file]

	API_setup $file

	# Generate the main C file
	CollectEmbeddedSources $file $base.c $object $initname $placestubs

	# Set the marker for critcl::done and its user, HandleDeclAfterBuild.
	dict set v::code($file) result closed mark

	# Compile main file
        lappend objects [Compile $file $file $base.c $object]

	# Compile the companion C sources as well, if there are any.
        foreach src [GetParam $file csources] {
	    lappend objects [Compile $file $src $src \
				 [CompanionObject $src]]
	}

	# NOTE: The data below has to be copied into the result even
	# if the link-step is suppressed. Because the application
	# (mode 'generate package') must have this information to be
	# able to perform the final link.

	lappendlist objects [GetParam $file cobjects]

	dict set v::code($file) result clibraries [set clib [GetParam $file clibraries]]
	dict set v::code($file) result libpaths   [LibPaths $clib]
	dict set v::code($file) result ldflags    [GetParam $file ldflags]
	dict set v::code($file) result objects    $objects
	dict set v::code($file) result tk         [UsingTk  $file]
	dict set v::code($file) result preload    [GetParam $file preload]
	dict set v::code($file) result license    [GetParam $file license <<Undefined>>]
	dict set v::code($file) result log        {}
	dict set v::code($file) result meta       [GetMeta $file]

	# Link and load steps.
        if {$load || !$buildforpackage} {
	    Link $file
	}

	lassign [LogClose] msgs emsg

	dict set v::code($file) result warnings [CheckForWarnings $emsg]
    }

    dict set v::code($file) result log $msgs
    dict set v::code($file) result exl $emsg

    if {$v::failed} {
	if {!$buildforpackage} {
	    print stderr "$msgs\ncritcl build failed ($file)"
	}
    } elseif {$load && !$buildforpackage} {
	Load $file
    }

    # Release the data which was collected for the just-built file, as
    # it is not needed any longer.
    dict unset v::code($file) config

    return [StatusSave $file]
}

proc ::critcl::cresults {{file {}}} {
    if {$file eq ""} { set file [This] }
    return [dict get $v::code($file) result]
}

proc ::critcl::cnothingtodo {f} {
    # No critcl definitions at all ?
    if {![info exists  v::code($f)]} { return 1 }

    # We have results already, so where had been something to do.
    if {[dict exists $v::code($f) result]} { return 0 }

    # No C code collected for compilation ?
    if {![dict exists $v::code($f) config fragments]} { return 1 }

    # Ok, something has to be done.
    return 0
}

proc ::critcl::c++command {tclname class constructors methods} {
    # Build the body of the function to define a new tcl command for
    # the C++ class
    set helpline {}
    set classptr ptr_$tclname
    set comproc "    $class* $classptr;\n"
    append comproc "    switch (objc) \{\n"

    if {![llength $constructors]} {
	set constructors {{}}
    }

    foreach adefs $constructors {
	array set types {}
	set names {}
	set cargs {}
	set cnames {}

	foreach {t n} $adefs {
	    set types($n) $t
	    lappend names $n
	    lappend cnames _$n
	    lappend cargs "$t $n"
	}
	lappend helpline "$tclname pathName [join $names { }]"
	set nargs  [llength $names]
	set ncargs [expr {$nargs + 2}]
	append comproc "        case $ncargs: \{\n"

	if {!$nargs} {
	    append comproc "            $classptr = new $class\();\n"
	} else  {
	    append comproc [ProcessArgs types $names $cnames]
	    append comproc "            $classptr = new $class\([join $cnames {, }]);\n"
	}
	append comproc "            break;\n"
	append comproc "        \}\n"

    }
    append comproc "        default: \{\n"
    append comproc "            Tcl_SetResult(ip, \"wrong # args: should be either [join $helpline { or }]\",TCL_STATIC);\n"
    append comproc "            return TCL_ERROR;\n"
    append comproc "        \}\n"
    append comproc "    \}\n"

    append comproc "    if ( $classptr == NULL ) \{\n"
    append comproc "        Tcl_SetResult(ip, \"Not enough memory to allocate a new $tclname\", TCL_STATIC);\n"
    append comproc "        return TCL_ERROR;\n"
    append comproc "    \}\n"

    append comproc "    Tcl_CreateObjCommand2(ip, Tcl_GetString(objv\[1]), cmdproc_$tclname, (ClientData) $classptr, delproc_$tclname);\n"
    append comproc "    return TCL_OK;\n"
    #
    #  Build the body of the c function called when the object is deleted
    #
    set delproc "void delproc_$tclname\(ClientData cd) \{\n"
    append delproc "    if (cd != NULL)\n"
    append delproc "        delete ($class*) cd;\n"
    append delproc "\}\n"

    #
    # Build the body of the function that processes the tcl commands for the class
    #
    set cmdproc "int cmdproc_$tclname\(ClientData cd, Tcl_Interp* ip, Tcl_Size objc, Tcl_Obj *CONST objv\[]) \{\n"
    append cmdproc "    int index;\n"
    append cmdproc "    $class* $classptr = ($class*) cd;\n"

    set rtypes {}
    set tnames {}
    set mnames {}
    set adefs {}
    foreach {rt n a} $methods {
	lappend rtypes $rt
	lappend tnames [lindex $n 0]
	set tmp [lindex $n 1]
	if {$tmp eq ""}  {
	    lappend mnames [lindex $n 0]
	} else {
	    lappend mnames [lindex $n 1]
	}
	lappend adefs $a
    }
    append cmdproc "    static const char* cmds\[]=\{\"[join $tnames {","}]\",NULL\};\n"
    append cmdproc "    if (objc < 2) \{\n"
    append cmdproc "       Tcl_WrongNumArgs(ip, 1, objv, \"expecting pathName option\");\n"
    append cmdproc "       return TCL_ERROR;\n"
    append cmdproc "    \}\n\n"
    append cmdproc "    if (Tcl_GetIndexFromObj(ip, objv\[1], cmds, \"option\", TCL_EXACT, &index) != TCL_OK)\n"
    append cmdproc "        return TCL_ERROR;\n"
    append cmdproc "    switch (index) \{\n"

    set ndx 0
    foreach rtype $rtypes tname $tnames mname $mnames adef $adefs {
	array set types {}
	set names {}
	set cargs {}
	set cnames {}

	switch -- $rtype {
	    ok      { set rtype2 "int" }
	    string -
	    dstring -
	    vstring { set rtype2 "char*" }
	    default { set rtype2 $rtype }
	}

	foreach {t n} $adef {
	    set types($n) $t
	    lappend names $n
	    lappend cnames _$n
	    lappend cargs "$t $n"
	}
	set helpline "$tname [join $names { }]"
	set nargs  [llength $names]
	set ncargs [expr {$nargs + 2}]

	append cmdproc "        case $ndx: \{\n"
	append cmdproc "            if (objc == $ncargs) \{\n"
	append cmdproc  [ProcessArgs types $names $cnames]
	append cmdproc "                "
	if {$rtype ne "void"} {
	    append cmdproc "$rtype2 rv = "
	}
	append cmdproc "$classptr->$mname\([join $cnames {, }]);\n"
	append cmdproc "                "
	switch -- $rtype {
	    void     { }
	    ok   { append cmdproc "return rv;" }
	    int  { append cmdproc "Tcl_SetIntObj(Tcl_GetObjResult(ip), rv);" }
	    long { append cmdproc " Tcl_SetLongObj(Tcl_GetObjResult(ip), rv);" }
	    float -
	    double { append cmdproc "Tcl_SetDoubleObj(Tcl_GetObjResult(ip), rv);" }
	    char*  { append cmdproc "Tcl_SetResult(ip, rv, TCL_STATIC);" }
	    string -
	    dstring  { append cmdproc "Tcl_SetResult(ip, rv, TCL_DYNAMIC);" }
	    vstring  { append cmdproc "Tcl_SetResult(ip, rv, TCL_VOLATILE);" }
	    default  { append cmdproc "if (rv == NULL) \{ return TCL_ERROR ; \}\n  Tcl_SetObjResult(ip, rv); Tcl_DecrRefCount(rv);" }
	}
	append cmdproc "\n"
	append cmdproc "                "
	if {$rtype ne "ok"} { append cmdproc "return TCL_OK;\n" }

	append cmdproc "            \} else \{\n"
	append cmdproc "               Tcl_WrongNumArgs(ip, 1, objv, \"$helpline\");\n"
	append cmdproc "               return TCL_ERROR;\n"
	append cmdproc "            \}\n"
	append cmdproc "        \}\n"
	incr ndx
    }
    append cmdproc "    \}\n\}\n"

    # TODO: line pragma fix ?!
    ccode $delproc
    ccode $cmdproc

    # Force the new ccommand to be defined in the caller's namespace
    # instead of improperly in ::critcl.
    namespace eval [uplevel 1 namespace current] \
	[list critcl::ccommand $tclname {dummy ip objc objv} $comproc]

    return
}

proc ::critcl::ProcessArgs {typesArray names cnames}  {
    upvar 1 $typesArray types
    set body ""
    foreach x $names c $cnames {
	set t $types($x)
	switch -- $t {
	    int - long - float - double - char* - Tcl_Obj* {
		append body "            $t $c;\n"
	    }
	    default {
		append body "            void* $c;\n"
	    }
	}
    }
    set n 1
    foreach x $names c $cnames {
	set t $types($x)
	incr n
	switch -- $t {
	    int {
		append body "            if (Tcl_GetIntFromObj(ip, objv\[$n], &$c) != TCL_OK)\n"
		append body "                return TCL_ERROR;\n"
	    }
	    long {
		append body "            if (Tcl_GetLongFromObj(ip, objv\[$n], &$c) != TCL_OK)\n"
		append body "                return TCL_ERROR;\n"
	    }
	    float {
		append body "            \{ double tmp;\n"
		append body "                if (Tcl_GetDoubleFromObj(ip, objv\[$n], &tmp) != TCL_OK)\n"
		append body "                   return TCL_ERROR;\n"
		append body "                $c = (float) tmp;\n"
		append body "            \}\n"
	    }
	    double {
		append body "            if (Tcl_GetDoubleFromObj(ip, objv\[$n], &$c) != TCL_OK)\n"
		append body "                return TCL_ERROR;\n"
	    }
	    char* {
		append body "            $c = Tcl_GetString(objv\[$n]);\n"
	    }
	    default {
		append body "            $c = objv\[$n];\n"
	    }
	}
    }
    return $body
}

proc ::critcl::scan {file} {
    set lines [split [Cat $file] \n]

    set scan::rkey    require
    set scan::base    [file dirname [file normalize $file]]
    set scan::capture {
	org         {}
	version     {}
	files       {}
	imported    {}
	config      {}
	meta-user   {}
	meta-system {}
	tsources    {}
    }

    ScanCore $lines {
	critcl::api			sub
	critcl::api/extheader		ok
	critcl::api/function		ok
	critcl::api/header		warn
	critcl::api/import		ok
	critcl::source                  warn
	critcl::cheaders		warn
	critcl::csources		warn
	critcl::license			warn
	critcl::meta			warn
	critcl::owns			warn
	critcl::tcl			ok
	critcl::tk			ok
	critcl::tsources		warn
	critcl::userconfig		sub
	critcl::userconfig/define	ok
	critcl::userconfig/query	ok
	critcl::userconfig/set		ok
	package				warn
    }

    set version [dict get $scan::capture version]
    print "\tVersion:      $version"

    # TODO : Report requirements.
    # TODO : tsources - Scan files for dependencies!

    set n [llength [dict get $scan::capture files]]
    print -nonewline "\tInput:        $file"
    if {$n} {
	print -nonewline " + $n Companion"
	if {$n > 1} { print -nonewline s }
    }
    print ""

    # Merge the system and user meta data, with system overriding the
    # user. See 'GetMeta' for same operation when actually builing the
    # package. Plus scan any Tcl companions for more requirements.

    set     md {}
    lappend md [dict get $scan::capture meta-user]
    lappend md [dict get $scan::capture meta-system]

    foreach ts [dict get $scan::capture tsources] {
	lappend md [dict get [ScanDependencies $file \
				  [file join [file dirname $file] $ts] \
				  capture] meta-system]
    }

    dict unset scan::capture meta-user
    dict unset scan::capture meta-system
    dict unset scan::capture tsources

    dict set scan::capture meta \
	[eval [linsert $md 0 dict merge]]
    # meta = dict merge {*}$md

    if {[dict exists $scan::capture meta require]} {
	foreach r [dict get $scan::capture meta require] {
	    print "\tRequired:     $r"
	}
    }

    return $scan::capture
}

proc ::critcl::ScanDependencies {dfile file {mode plain}} {
    set lines [split [Cat $file] \n]

    catch {
	set saved $scan::capture
    }

    set scan::rkey    require
    set scan::base    [file dirname [file normalize $file]]
    set scan::capture {
	name        {}
	version     {}
	meta-system {}
    }

    ScanCore $lines {
	critcl::buildrequirement	warn
	package				warn
    }

    if {$mode eq "capture"} {
	set result $scan::capture
	set scan::capture $saved
	return $result
    }

    dict with scan::capture {
	if {$mode eq "provide"} {
	    msg "  (provide $name $version)"

	    ImetaSet $dfile name     $name
	    ImetaSet $dfile version  $version
	}

	dict for {k vlist} [dict get $scan::capture meta-system] {
	    if {$k eq "name"}    continue
	    if {$k eq "version"} continue

	    ImetaAdd $dfile $k $vlist

	    if {$k ne "require"} continue
	    # vlist = package list, each element a package name,
	    # and optional version.
	    msg "  ([file tail $file]: require [join [lsort -dict -unique $vlist] {, }])"
	}

	# The above information also goes into the teapot meta data of
	# the file in question. This however is defered until the meta
	# data is actually pulled for delivery to the tool using the
	# package. See 'GetMeta' for where the merging happens.
    }

    return
}

proc ::critcl::ScanCore {lines theconfig} {
    # config = dictionary
    # - <cmdname> => mode (ok, warn, sub)
    # Unlisted commands are ignored.

    variable scan::config $theconfig

    set collect 0
    set buf {}
    set lno -1
    foreach line $lines {
	#puts |$line|

	incr lno
	if {$collect} {
	    if {![info complete $buf]} {
		append buf $line \n
		continue
	    }
	    set collect 0

	    #puts %%$buf%%

	    # Prevent heavily dynamic code from stopping the scan.
	    # WARN the user.
	    regexp {^(\S+)} $buf -> cmd
	    if {[dict exists $config $cmd]} {
		set mode [dict get $config $cmd]

		if {[catch {
		    # Run in the scan namespace, with its special
		    # command implementations.
		    namespace eval ::critcl::scan $buf
		} msg]} {
		    if {$mode eq "sub"} {
			regexp {^(\S+)\s+(\S+)} $buf -> _ method
			append cmd /$method
			set mode [dict get $config $cmd]
		    }
		    if {$mode eq "warn"} {
			msg "Line $lno, $cmd: Failed execution of dynamic command may"
			msg "Line $lno, $cmd: cause incorrect TEA results. Please check."
			msg "Line $lno, $cmd: $msg"
		    }
		}
	    }

	    set buf ""
	    # fall through, to handle the line which just got NOT
	    # added to the buf.
	}

	set line [string trimleft $line " \t:"]
	if {[string trim $line] eq {}} continue

	regexp {^(\S+)} $line -> cmd
	if {[dict exists $config $cmd]} {
	    append buf $line \n
	    set collect 1
	}
    }
}

# Handle the extracted commands
namespace eval ::critcl::scan::critcl {}

proc ::critcl::scan::critcl::buildrequirement {script} {
    # Recursive scan of the script, same configuration, except
    # switched to record 'package require's under the build::reqire
    # key.

    variable ::critcl::scan::config
    variable ::critcl::scan::rkey

    set saved $rkey
    set rkey build::require

    ::critcl::ScanCore [split $script \n] $config

    set rkey $saved
    return
}

# Meta data.
# Capture specific dependencies
proc ::critcl::scan::critcl::tcl {version} {
    variable ::critcl::scan::capture
    dict update capture meta-system m {
	dict lappend m require [list Tcl $version]
    }
    return
}

proc ::critcl::scan::critcl::tk {} {
    variable ::critcl::scan::capture
    dict update capture meta-system m {
	dict lappend m require Tk
    }
    return
}

proc ::critcl::scan::critcl::description {text} {
    variable ::critcl::scan::capture
    dict set capture meta-system description \
	[::critcl::Text2Words $text]
    return
}

proc ::critcl::scan::critcl::summary {text} {
    variable ::critcl::scan::capture
    dict set capture meta-system summary \
	[::critcl::Text2Words $text]
    return
}

proc ::critcl::scan::critcl::subject {args} {
    variable ::critcl::scan::capture
    dict update capture meta-system m {
	foreach word $args {
	    dict lappend m subject $word
	}
    }
    return
}

proc ::critcl::scan::critcl::meta {key args} {
    variable ::critcl::scan::capture
    dict update capture meta-user m {
	foreach word $args {
	    dict lappend m $key $word
	}
    }
    return
}

# Capture files
proc ::critcl::scan::critcl::source   {path} {
    # Recursively scan the imported file.
    # Keep the current context.
    variable ::critcl::scan::config

    foreach f [Files $path] {
	set lines [split [::critcl::Cat $f] \n]
	ScanCore $lines $config
    }
    return
}
proc ::critcl::scan::critcl::owns     {args} { eval [linsert $args 0 Files] }
proc ::critcl::scan::critcl::cheaders {args} { eval [linsert $args 0 Files] }
proc ::critcl::scan::critcl::csources {args} { eval [linsert $args 0 Files] }
proc ::critcl::scan::critcl::tsources {args} {
    variable ::critcl::scan::capture
    foreach ts [eval [linsert $args 0 Files]] {
	dict lappend capture tsources $ts
    }
    return
}

proc ::critcl::scan::critcl::Files {args} {
    variable ::critcl::scan::capture
    set res {}
    foreach v $args {
	if {[string match "-*" $v]} continue
	foreach f [Expand $v] {
	    dict lappend capture files $f
	    lappend res $f
	}
    }
    return $res
}

proc ::critcl::scan::critcl::Expand {pattern} {
    variable ::critcl::scan::base

    # Note: We cannot use -directory here. The PATTERN may already be
    # an absolute path, in which case the join will return the
    # unmodified PATTERN to glob on, whereas with -directory the final
    # pattern will be BASE/PATTERN which won't find anything, even if
    # PATTERN actually exists.

    set prefix [file split $base]

    set files {}
    foreach vfile [glob [file join $base $pattern]] {
	set xfile [file normalize $vfile]
	if {![file exists $xfile]} {
	    error "$vfile: not found"
	}

	# Constrain to be inside of the base directory.
	# Snarfed from fileutil::stripPath

	set npath [file split $xfile]

	if {![string match -nocase "${prefix} *" $npath]} {
	    error "$vfile: Not inside of $base"
	}

	set xfile [eval [linsert [lrange $npath [llength $prefix] end] 0 file join ]]
	lappend files $xfile
    }
    return $files
}

# Capture license (org name)
proc ::critcl::scan::critcl::license {who args} {
    variable ::critcl::scan::capture
    dict set capture org $who

    ::critcl::print "\tOrganization: $who"

    # Meta data.
    set elicense [::critcl::LicenseText $args]

    dict set capture meta-system license \
	[::critcl::Text2Words $elicense]
    dict set capture meta-system author \
	[::critcl::Text2Authors $who]
    return
}

# Capture version of the provided package.
proc ::critcl::scan::package {cmd args} {
    if {$cmd eq "provide"} {
	# Syntax: package provide <name> <version>

	variable capture
	lassign $args name version
	dict set capture name    $name
	dict set capture version $version

	# Save as meta data as well.

	dict set capture meta-system name     $name
	dict set capture meta-system version  $version
	dict set capture meta-system platform source
	dict set capture meta-system generated::by \
	    [list \
		 [list critcl [::package present critcl]] \
		 $::tcl_platform(user)]
	dict set capture meta-system generated::date \
	    [list [clock format [clock seconds] -format {%Y-%m-%d}]]
	return
    } elseif {$cmd eq "require"} {
	# Syntax: package require <name> ?-exact? <version>
	#       : package require <name> <version-range>...

	# Save dependencies as meta data.

	# Ignore the critcl core
	if {[lindex $args 0] eq "critcl"} return

	variable capture
	variable rkey
	dict update capture meta-system m {
	    dict lappend m $rkey [::critcl::TeapotRequire $args]
	}
	return
    }

    # ignore anything else.
    return
}

# Capture the APIs imported by the package
proc ::critcl::scan::critcl::api {cmd args} {
    variable ::critcl::scan::capture
    switch -exact -- $cmd {
	header {
	    eval [linsert $args 0 Files]
	}
	import {
	    # Syntax: critcl::api import <name> <version>
	    lassign $args name _
	    dict lappend capture imported $name
	    print "\tImported:     $name"
	}
	default {}
    }
    return
}

# Capture the user config options declared by the package
proc ::critcl::scan::critcl::userconfig {cmd args} {
    variable ::critcl::scan::capture
    switch -exact -- $cmd {
	define {
	    # Syntax: critcl::userconfig define <name> <description> <type> ?<default>?
	    lassign $args oname odesc otype odefault
	    set odesc [string trim $odesc]
	    if {[llength $args] < 4} {
		set odefault [::critcl::UcDefault $otype]
	    }
	    dict lappend capture config [list $oname $odesc $otype $odefault]
	    print "\tUser Config:  $oname ([join $otype { }] -> $odefault) $odesc"
	}
	set - query -
	default {}
    }
    return
}

# # ## ### ##### ######## ############# #####################
## Implementation -- Internals - cproc conversion helpers.

proc ::critcl::EmitShimHeader {wname} {
    # Function head
    set ca "(ClientData cd, Tcl_Interp *interp, Tcl_Size oc, Tcl_Obj *CONST ov\[])"
    Emitln
    Emitln "static int"
    Emitln "$wname$ca"
    Emitln \{
    return
}

proc ::critcl::EmitShimVariables {adb rtype} {
    foreach d [dict get $adb vardecls] {
	Emitln "  $d"
    }
    if {[dict get $adb hasoptional]} {
	Emitln "  int idx_;"
	Emitln "  int argc_;"
    }

    # Result variable, source for the C -> Tcl conversion.
    if {$rtype ne "void"} { Emit "  [ResultCType $rtype] rv;" }
    return
}

proc ::critcl::EmitArgTracing {fun} {
    if {!$v::options(trace)} return
    Emitln "\n  critcl_trace_cmd_args ($fun, oc, ov);"
    return
}

proc ::critcl::EmitWrongArgsCheck {adb} {
    # Code checking for the correct count of arguments, and generating
    # the proper error if not.

    set wac [dict get $adb wacondition]
    if {$wac eq {}} return

    # Have a check, put the pieces together.

    set offset [dict get $adb skip]
    set tsig   [dict get $adb tsignature]
    set min    [dict get $adb min]
    set max    [dict get $adb max]

    incr min $offset
    if {$max != Inf} {
	incr max $offset
    }

    lappend map MIN_ARGS $min
    lappend map MAX_ARGS $max
    set wac [string map $map $wac]

    Emitln ""
    Emitln "  if ($wac) \{"
    Emitln "    Tcl_WrongNumArgs(interp, $offset, ov, $tsig);"
    Emitln [TraceReturns "wrong-arg-num check" "    return TCL_ERROR;"]
    Emitln "  \}"
    Emitln ""
    return
}

proc ::critcl::EmitSupport {adb} {
    set s [dict get $adb support]
    if {![llength $s]} return
    if {[join $s {}] eq {}} return
    Emit [join $s \n]\n
    return
}

proc ::critcl::EmitCall {cname cnames rtype} {
    # Invoke the low-level function.

    Emitln  "  /* Call - - -- --- ----- -------- */"
    Emit "  "
    if {$rtype ne "void"} { Emit "rv = " }
    Emitln "${cname}([join $cnames {, }]);"
    Emitln
    return
}

proc ::critcl::EmitConst {rtype rvalue} {
    # Assign the constant directly to the shim's result variable.

    Emitln  "  /* Const - - -- --- ----- -------- */"
    Emit "  "
    if {$rtype ne "void"} { Emit "rv = " }
    Emitln "${rvalue};"
    Emitln
    return
}

proc ::critcl::TraceReturns {label code} {
    if {!$v::options(trace)} {
	return $code
    }

    # Inject tracing into the 'return's.
    regsub -all \
	{return[[:space:]]*([^;]*);}           $code \
	{return critcl_trace_cmd_result (\1, interp);} newcode
    if {[string match {*return *} $code] && ($newcode eq $code)} {
	error "Failed to inject tracing code into $label"
    }
    return $newcode
}

proc ::critcl::EmitShimFooter {adb rtype} {
    # Run release code for arguments which allocated temp memory.
    set arelease [dict get $adb arelease]
    if {[llength $arelease]} {
	Emit "[join $arelease "\n  "]\n"
    }

    # Convert the returned low-level result from C to Tcl, if required.
    # Return a standard status, if required.

    set code [Deline [ResultConversion $rtype]]
    if {$code ne {}} {
	set code [TraceReturns "\"$rtype\" result" $code]
	Emitln "  /* ($rtype return) - - -- --- ----- -------- */"
	Emitln $code
    } else {
	if {$v::options(trace)} {
	    Emitln "  critcl_trace_header (1, 0, 0);"
	    Emitln "  critcl_trace_printf (1, \"RETURN (void)\");"
	    Emitln "  critcl_trace_closer (1);"
	    Emitln "  critcl_trace_pop();"
	    Emitln "  return;"
	}
    }
    Emitln \}
    return
}

proc ::critcl::ArgumentSupport {type} {
    if {[info exists v::acsup($type)]} { return $v::acsup($type) }
    return {}
}

proc ::critcl::ArgumentRelease {type} {
    if {[info exists v::acrel($type)]} { return $v::acrel($type) }
    return {}
}

proc ::critcl::ArgumentCType {type} {
    if {[info exists v::actype($type)]} { return $v::actype($type) }
    return -code error "Unknown argument type \"$type\""
}

proc ::critcl::ArgumentCTypeB {type} {
    if {[info exists v::actypeb($type)]} { return $v::actypeb($type) }
    return -code error "Unknown argument type \"$type\""
}

proc ::critcl::ArgumentConversion {type} {
    if {[info exists v::aconv($type)]} { return $v::aconv($type) }
    return -code error "Unknown argument type \"$type\""
}

proc ::critcl::ResultCType {type} {
    if {[info exists v::rctype($type)]} {
	return $v::rctype($type)
    }
    return -code error "Unknown result type \"$type\""
}

proc ::critcl::ResultConversion {type} {
    if {[info exists v::rconv($type)]} {
	return $v::rconv($type)
    }
    return -code error "Unknown result type \"$type\""
}

# # ## ### ##### ######## ############# #####################
## Implementation -- Internals - Manage complex per-file settings.

proc ::critcl::GetParam {file type {default {}}} {
    if {[info exists  v::code($file)] &&
	[dict exists $v::code($file) config $type]} {
	return [dict get $v::code($file) config $type]
    } else {
	return $default
    }
}

proc ::critcl::SetParam {type values {expand 1} {uuid 0} {unique 0}} {
    set file [This]
    if {![llength $values]} return

    UUID.extend $file .$type $values

    if {$type ne "cobjects"} {
	#todo (debug flag): msg "\t$type += $values"
	set dtype [string map {
	    cheaders   {headers:    }
	    csources   {companions: }
	    api_hdrs    api-headers:
	    api_ehdrs  {api-exthdr: }
	    clibraries {libraries:  }
	} $type]
	set prefix "  ($dtype "
	msg "$prefix[join $values ")\n$prefix"])"
    }

    # Process the list of flags, treat non-option arguments as glob
    # patterns and expand them to a set of files, stored as absolute
    # paths.

    set have {}
    if {$unique && [dict exists $v::code($file) config $type]} {
	foreach v [dict get $v::code($file) config $type] {
	    dict set have $v .
	}
    }

    set tmp {}
    foreach v $values {
	if {[string match "-*" $v]} {
	    lappend tmp $v
	} else {
	    if {$expand} {
		foreach f [Expand $file $v] {
		    if {$unique && [dict exists $have $f]} continue
		    lappend tmp $f
		    if {$unique} { dict set have $f . }
		    if {$uuid} { UUID.extend $file .$type.$f [Cat $f] }
		}
	    } else {
		if {$unique && [dict exists $have $v]} continue
		lappend tmp $v
		if {$unique} { dict set have $v . }
	    }
	}
    }

    if {$type eq "csources"} {
	foreach v $tmp {
	    at::= $v 1
	    Transition9Check [at::raw] [Cat $v]
	}
    }

    # And save into the system state.
    dict update v::code($file) config c {
	foreach v $tmp {
	    dict lappend c $type $v
	}
    }

    return
}

proc ::critcl::Expand {file pattern} {
    set base [file dirname $file]

    # Note: We cannot use -directory here. The PATTERN may already be
    # an absolute path, in which case the join will return the
    # unmodified PATTERN to glob on, whereas with -directory the final
    # pattern will be BASE/PATTERN which won't find anything, even if
    # PATTERN actually exists.

    set files {}
    foreach vfile [glob [file join $base $pattern]] {
	set vfile [file normalize $vfile]
	if {![file exists $vfile]} {
	    error "$vfile: not found"
	}
	lappend files $vfile
    }
    return $files
}

proc ::critcl::InitializeFile {file} {
    if {![info exists v::code($file)]} {
	set      v::code($file) {}

	# Initialize the meta data sections (user (meta) and system
	# (package)).

	dict set v::code($file) config meta    {}

	dict set v::code($file) config package platform \
	    [TeapotPlatform]
	dict set v::code($file) config package build::date \
	    [list [clock format [clock seconds] -format {%Y-%m-%d}]]

	# May not exist, bracket code.
	if {![file exists $file]} return

	ScanDependencies $file $file provide
	return
    }

    if {![dict exists $v::code($file) config]} {
	dict set v::code($file) config {}
    }
    return
}

# # ## ### ##### ######## ############# #####################
## Implementation -- Internals - Management of in-memory C source fragment.

proc ::critcl::name2c {name} {
    # Note: A slightly modified copy (different depth in the call-stack) of this
    # is inlined into the internal command "BeginCommand".

    # Locate caller, as the data is saved per .tcl file.
    set file [This]

    if {![string match ::* $name]} {
	# Locate caller's namespace. Two up, skipping the
	# ccommand/cproc frame. This is where the new Tcl command will
	# be defined in.

	set ns [uplevel 1 namespace current]
	if {$ns ne "::"} { append ns :: }

	set name ${ns}$name
    }

    # First ensure that any namespace qualifiers found in the name
    # itself are shifted over to the namespace information.

    set ns   [namespace qualifiers $name]
    set name [namespace tail       $name]

    # Then ensure that everything is fully qualified, and that the C
    # level name doesn't contain bad characters. We have to remove any
    # non-alphabetic characters. A serial number is further required
    # to distinguish identifiers which would, despite having different
    # Tcl names, transform to the same C identifier.

    if {$ns ne "::"} { append ns :: }
    set cns [string map {:: _} $ns]

    regsub -all -- {[^a-zA-Z0-9_]} $name _ cname
    regsub -all -- {_+} $cname _ cname

    regsub -all -- {[^a-zA-Z0-9_]} $cns _ cns
    regsub -all -- {_+} $cns _ cns

    set cname $cname[UUID.serial $file]

    return [list $ns $cns $name $cname]
}

proc ::critcl::BeginCommand {visibility name args} {
    # Locate caller, as the data is saved per .tcl file.
    set file [This]

    # Inlined name2c
    if {![string match ::* $name]} {
	# Locate caller's namespace. Two up, skipping the
	# ccommand/cproc frame. This is where the new Tcl command will
	# be defined in.

	set ns [uplevel 2 namespace current]
	if {$ns ne "::"} { append ns :: }

	set name ${ns}$name
    }

    # First ensure that any namespace qualifiers found in the name
    # itself are shifted over to the namespace information.

    set ns   [namespace qualifiers $name]
    set name [namespace tail       $name]

    # Then ensure that everything is fully qualified, and that the C
    # level identifiers don't contain bad characters. We have to
    # remove any non-alphabetic characters. A serial number is further
    # required to distinguish identifiers which would, despite having
    # different Tcl names, transform to the same C identifier.

    if {$ns ne "::"} { append ns :: }
    set cns [string map {:: _} $ns]

    regsub -all -- {[^a-zA-Z0-9_]} $name _ cname
    regsub -all -- {_+} $cname _ cname

    regsub -all -- {[^a-zA-Z0-9_]} $cns _ cns
    regsub -all -- {_+} $cns _ cns

    set cname $cname[UUID.serial $file]

    # Set the defered build-on-demand used by mode 'comile & run' up.
    # Note: Removing the leading :: because it trips Tcl's unknown
    # command, i.e. the command will not be found when called in a
    # script without leading ::.
    set ::auto_index([string trimleft $ns$name :]) [list [namespace current]::cbuild $file]

    set v::curr [UUID.extend $file .function "$ns $name $args"]

    dict update v::code($file) config c {
	dict lappend c functions $cns$cname
	dict lappend c fragments $v::curr
    }

    if {$visibility eq "public"} {
	Emitln "#define ns_$cns$cname \"$ns$name\""
    }
    return [list $ns $cns $name $cname]
}

proc ::critcl::EndCommand {} {
    set file [This]

    set v::code($v::curr) $v::block

    dict set v::code($file) config block $v::curr $v::block

    unset v::curr
    unset v::block
    return
}

proc ::critcl::Emit {s} {
    append v::block $s
    return
}

proc ::critcl::Emitln {{s ""}} {
    Emit $s\n
    return
}

# # ## ### ##### ######## ############# #####################
## At internal processing

proc ::critcl::at::Where {leadoffset level file} {
    variable where

    set line 1

    # If the interpreter running critcl has TIP 280 support use it to
    # place more exact line number information into the generated C
    # file.

    #puts "XXX-WHERE-($leadoffset $level $file)"
    #set ::errorInfo {}
    if {[catch {
	#::critcl::msg [SHOWFRAMES $level 0]
	array set loc [info frame $level]
	#puts XXX-TYPE-$loc(type)
    }]} {
	#puts XXX-NO-DATA-$::errorInfo
	set where {}
	return
    }

    if {$loc(type) eq "source"} {
	#parray loc
	set  file  $loc(file)
	set  fline $loc(line)

	# Adjust for removed leading whitespace.
	::incr fline $leadoffset

	# Keep the limitations of native compilers in mind and stay
	# inside their bounds.

	if {$fline > $line} {
	    set line $fline
	}

	set where [list [file tail $file] $line]
	return
    }

    if {($loc(type) eq "eval") &&
       [info exists loc(proc)] &&
       ($loc(proc) eq "::critcl::source")
    } {
	# A relative location in critcl::source is absolute in the
	# sourced file.  I.e. we can provide proper line information.

	set  fline $loc(line)
	# Adjust for removed leading whitespace.
	::incr fline $leadoffset

	# Keep the limitations of native compilers in mind and stay
	# inside their bounds.

	if {$fline > $line} {
	    set line $fline
	}

	variable ::critcl::v::source
	set where [list [file tail $source] $line]
	return
    }

    #puts XXX-NO-DATA-$loc(type)
    set where {}
    return
}

proc ::critcl::at::Loc {leadoffset level file} {
    # internal variant of 'caller!'
    ::incr level -1
    Where $leadoffset $level $file
    return [raw]
}

proc ::critcl::at::CPragma {leadoffset level file} {
    # internal variant of 'caller!'
    ::incr level -1
    Where $leadoffset $level $file
    return [get]
}

proc ::critcl::at::Format {loc} {
   if {![llength $loc]} {
	return ""
    }
    lassign $loc file line
    #::critcl::msg "#line $line \"$file\"\n"
    return        "#line $line \"$file\"\n"
}

proc ::critcl::at::SHOWFRAMES {level {all 1}} {
    set lines {}
    set n [info frame]
    set i 0
    set id 1
    while {$n} {
	lappend lines "[expr {$level == $id ? "**" : "  "}] frame [format %3d $id]: [info frame $i]"
	::incr i -1
	::incr id -1
	::incr n -1
	if {($level > $id) && !$all} break
    }
    return [join $lines \n]
}

# # ## ### ##### ######## ############# #####################

proc ::critcl::CollectEmbeddedSources {file destination libfile ininame placestubs} {
    set fd [open $destination w]

    if {[dict exists $v::code($file) result apiprefix]} {
	set api [dict get $v::code($file) result apiprefix]
    } else {
	set api ""
    }

    # Boilerplate header.
    puts $fd [subst [Cat [Template header.c]]]
    #         ^=> file, libfile, api

    # Make Tk available, if requested
    if {[UsingTk $file]} {
	puts $fd "\n#include \"tk.h\""
    }

    # Write the collected C fragments, in order of collection.
    foreach digest [GetParam $file fragments] {
	puts $fd "[Separator]\n"
	puts $fd [dict get $v::code($file) config block $digest]
    }

    # Boilerplate trailer.

    # Stubs setup, Tcl, and, if requested, Tk as well.
    puts $fd [Separator]
    set mintcl [MinTclVersion $file]

    if {$placestubs} {
	# Put full stubs definitions into the code, which can be
	# either the bracket generated for a -pkg, or the package
	# itself, build in mode "compile & run".
	msg "  Stubs:"
	set stubs     [TclDecls     $file]
	set platstubs [TclPlatDecls $file]
	puts -nonewline $fd [Deline [subst [Cat [Template stubs.c]]]]
	#                            ^=> mintcl, stubs, platstubs
    } else {
	# Declarations only, for linking, in the sub-packages.
	puts -nonewline $fd [Deline [subst [Cat [Template stubs_e.c]]]]
	#                            ^=> mintcl
    }

    if {[UsingTk $file]} {
	SetupTkStubs $fd $mintcl
    }

    # Initialization boilerplate. This ends in the middle of the
    # FOO_Init() function, leaving it incomplete.

    set ext [GetParam $file edecls]
    puts $fd [subst [Cat [Template pkginit.c]]]
    #         ^=> ext, ininame

    # From here on we are completing FOO_Init().
    # Tk setup first, if requested. (Tcl is already done).
    if {[UsingTk $file]} {
	puts $fd [Cat [Template pkginittk.c]]
    }

    # User specified initialization code.
    puts $fd "[GetParam $file initc] "

    # Setup of the variables serving up defined constants.
    if {[dict exists $v::code($file) config const]} {
	BuildDefines $fd $file
    }

    # Take the names collected earlier and register them as Tcl
    # commands.
    set names [lsort [GetParam $file functions]]
    set max   [LengthLongestWord $names]
    foreach name $names {
	if {[info exists v::clientdata($name)]} {
	    set cd $v::clientdata($name)
	} else {
	    set cd NULL
	}
	if {[info exists v::delproc($name)]} {
	    set dp $v::delproc($name)
	} else {
	    set dp 0
	}
	puts $fd "  Tcl_CreateObjCommand2(interp, [PadRight [expr {$max+4}] ns_$name,] [PadRight [expr {$max+5}] tcl_$name,] $cd, $dp);"
    }

    # Complete the trailer and be done.
    puts  $fd [Cat [Template pkginitend.c]]
    close $fd
    return
}

proc ::critcl::MinTclVersion {file} {
    # For the default differentiate 8.x and 9.x series. When running under 9+ an
    # 8.x default is not sensible.
    set mintcldefault 8.6
    if {[package vsatisfies [package provide Tcl] 9]} { set mintcldefault 9 }

    set required [GetParam $file mintcl $mintcldefault]
    foreach version $v::hdrsavailable {
	if {[package vsatisfies $version $required]} {
	    return $version
	}
    }
    return $required
}

proc ::critcl::UsingTk {file} {
    return [GetParam $file tk 0]
}

proc ::critcl::TclIncludes {file} {
    # Provide access to the Tcl/Tk headers using a -I flag pointing
    # into the critcl package directory hierarchy. No copying of files
    # required. This also handles the case of the X11 headers on
    # windows, for free.

    set hdrs tcl[MinTclVersion $file]
    set path [file join $v::hdrdir $hdrs]

    if {[file system $path] ne "native"} {
	# The critcl package is wrapped. Copy the relevant headers out
	# to disk and change the include path appropriately.

	Copy $path [cache]
	set path [file join [cache] $hdrs]
    }

    return [list $c::include$path $c::include$v::hdrdir]
}

proc ::critcl::TclHeader {file {header {}}} {
    # Provide access to the Tcl/Tk headers in the critcl package
    # directory hierarchy. No copying of files required.
    set hdrs tcl[MinTclVersion $file]
    return [file join $v::hdrdir $hdrs $header]
}

proc ::critcl::SystemIncludes {file} {
    set includes {}
    foreach dir [SystemIncludePaths $file] {
	lappend includes $c::include$dir
    }
    return $includes
}

proc ::critcl::SystemIncludePaths {file} {
    set paths {}
    set has {}

    # critcl -I options.
    foreach dir $v::options(I) {
	if {[dict exists $has $dir]} continue
	dict set has $dir yes
	lappend paths $dir
    }

    # Result cache.
    lappend paths [cache]

    # critcl::cheaders
    foreach flag [GetParam $file cheaders] {
	if {![string match "-*" $flag]} {
	    # flag = normalized absolute path to a header file.
	    # Transform into a -I directory reference.
	    set dir [file dirname $flag]
	} else {
	    # Chop leading -I
	    set dir [string range $flag 2 end]
	}

	if {[dict exists $has $dir]} continue
	dict set has $dir yes
	lappend paths $dir
    }

    return $paths
}

proc ::critcl::SystemLibraries {} {
    set libincludes {}
    foreach dir [SystemLibraryPaths] {
	lappend libincludes $c::libinclude$dir
    }
    return $libincludes
}

proc ::critcl::SystemLibraryPaths {} {
    set paths {}
    set has {}

    # critcl -L options.
    foreach dir $v::options(L) {
	if {[dict exists $has $dir]} continue
	dict set has $dir yes
	lappend paths $dir
    }

    return $paths
}

proc ::critcl::Compile {tclfile origin cfile obj} {
    StatusAbort?

    # tclfile = The .tcl file under whose auspices the C is compiled.
    # origin  = The origin of the C sources, either tclfile, or cfile.
    # cfile   = The file holding the C sources to compile.
    #
    # 'origin == cfile' for the companion C files of a critcl file,
    # i.e. the csources. For a .tcl critcl file, the 'origin ==
    # tclfile', and the cfile is the .c derived from tclfile.
    #
    # obj = Object file to compile to, to generate.

    set         cmdline [getconfigvalue compile]
    lappendlist cmdline [GetParam $tclfile cflags]
    lappendlist cmdline [getconfigvalue threadflags]
    if {$v::options(combine) ne "standalone"} {
	lappendlist cmdline [getconfigvalue tclstubs]
    }
    if {$v::options(language) ne "" && [file tail $tclfile] ne "critcl.tcl"} {
	# XXX Is this gcc specific ?
	# XXX Should this not be configurable via some c::* setting ?
	# See also -x none below.
	lappend cmdline -x $v::options(language)
    }
    lappendlist cmdline [TclIncludes $tclfile]
    lappendlist cmdline [SystemIncludes $tclfile]

    if {[dict exists $v::code($tclfile) result apidefines]} {
	lappendlist cmdline [dict get $v::code($tclfile) result apidefines]
    }

    lappendlist cmdline [CompileResult $obj]
    lappend     cmdline $cfile

    if {$v::options(language) ne ""} {
	# Allow the compiler to determine the type of file otherwise
	# it will try to compile the libs
	# XXX Is this gcc specific ?
	# XXX Should this not be configurable via some c::* setting ?
	lappend cmdline -x none
    }

    # Add the Tk stubs to the command line, if requested and not suppressed
    if {[UsingTk $tclfile] && ($v::options(combine) ne "standalone")} {
	lappendlist cmdline [getconfigvalue tkstubs]
    }

    if {!$option::debug_symbols} {
	lappendlist cmdline [getconfigvalue optimize]
	lappendlist cmdline [getconfigvalue noassert]
    }

    if {[ExecWithLogging $cmdline \
	     {$obj: [file size $obj] bytes} \
	     {ERROR while compiling code in $origin:}]} {
	if {!$v::options(keepsrc) && $cfile ne $origin} {
	    file delete $cfile
	}
    }

    return $obj
}

proc ::critcl::MakePreloadLibrary {file} {
    StatusAbort?

    # compile and link the preload support, if necessary, i.e. not yet
    # done.

    set shlib [file join [cache] preload[getconfigvalue sharedlibext]]
    if {[file exists $shlib]} return

    # Operate like TclIncludes. Use the template file directly, if
    # possible, or, if we reside in a virtual filesystem, copy it to
    # disk.

    set src [Template preload.c]
    if {[file system $src] ne "native"} {
	file mkdir [cache]
	file copy -force $src [cache]
	set src [file join [cache] preload.c]
    }

    # Build the object for the helper package, 'preload' ...

    set obj [file join [cache] preload.o]
    Compile $file $src $src $obj

    # ... and link it.
    # Custom linker command. XXX Can we bent Link to the task?
    set         cmdline [getconfigvalue link]
    lappend     cmdline $obj
    lappendlist cmdline [getconfigvalue strip]
    lappendlist cmdline [LinkResult $shlib]

    ExecWithLogging $cmdline \
	{$shlib: [file size $shlib] bytes} \
	{ERROR while linking $shlib:}

    # Now the critcl application can pick up this helper shlib and
    # stuff it into the package it is making.
    return
}

proc ::critcl::Link {file} {
    StatusAbort?

    set shlib   [dict get $v::code($file) result shlib]
    set preload [dict get $v::code($file) result preload]

    # Assemble the link command.
    set cmdline [getconfigvalue link]

    if {[llength $preload]} {
	lappendlist cmdline [getconfigvalue link_preload]
    }

    if {$option::debug_symbols} {
	lappendlist cmdline [getconfigvalue link_debug]
    } else {
	lappendlist cmdline [getconfigvalue strip]
	lappendlist cmdline [getconfigvalue link_release]
    }

    lappendlist cmdline [LinkResult $shlib]
    lappendlist cmdline [GetObjects $file]
    lappendlist cmdline [SystemLibraries]
    lappendlist cmdline [GetLibraries $file]
    lappendlist cmdline [dict get $v::code($file) result ldflags]
    # lappend cmdline bufferoverflowU.lib ;# msvc >=1400 && <1500 for amd64

    # Extend library search paths with user-specified locations.
    # (-L, clibraries)
    set libpaths [dict get $v::code($file) result libpaths]
    if {[llength $libpaths]} {
	set opt [getconfigvalue link_rpath]
	if {$opt ne {}} {
	    foreach path $libpaths {
		# todo (debug flag) msg "\trpath += $path"
		lappend cmdline [string map [list @ $path] $opt]
	    }
	}
    }

    # Run the linker
    ExecWithLogging $cmdline \
	{$shlib: [file size $shlib] bytes} \
	{ERROR while linking $shlib:}

    # Now, if there is a manifest file around, and the
    # 'embed_manifest' command defined we use its command to merge the
    # manifest into the shared library. This is pretty much only
    # happening on Windows platforms, and with newer dev environments
    # actually using manifests.

    set em [getconfigvalue embed_manifest]

    critcl::Log "Manifest Command: $em"
    critcl::Log "Manifest File:    [expr {[file exists $shlib.manifest]
	   ? "$shlib.manifest"
	   : "<<not present>>, ignored"}]"

    if {[llength $em] && [file exists $shlib.manifest]} {
	set cmdline [ManifestCommand $em $shlib]

	# Run the manifest tool
	ExecWithLogging $cmdline \
	    {$shlib: [file size $shlib] bytes, with manifest} \
	    {ERROR while embedding the manifest into $shlib:}
    }

    # At last, build the preload support library, if necessary.
    if {[llength $preload]} {
	MakePreloadLibrary $file
    }
    return
}

proc ::critcl::ManifestCommand {em shlib} {
    # Variable used by the subst'able config setting.
    set outfile $shlib
    return [subst $em]
}

proc ::critcl::CompanionObject {src} {
    set tail    [file tail $src]
    set srcbase [file rootname $tail]

    if {[cache] ne [file dirname $src]} {
	set srcbase [file tail [file dirname $src]]_$srcbase
    }

    return [file join [cache] ${srcbase}[getconfigvalue object]]
}

proc ::critcl::CompileResult {object} {
    # Variable used by the subst'able config setting.
    set outfile $object
    return [subst $c::output]
}

proc ::critcl::LinkResult {shlib} {
    # Variable used by the subst'able config setting.
    set outfile $shlib

    set ldout [subst $c::ldoutput]
    if {$ldout eq ""} {
	set ldout [subst $c::output]
    }

    return $ldout
}

proc ::critcl::GetObjects {file} {
    # On windows using the native MSVC compiler put the companion
    # object files into a link file to read, instead of separately on
    # the command line.

    set objects [dict get $v::code($file) result objects]

    if {![string match "win32-*-cl" $v::buildplatform]} {
	return $objects
    }

    set rsp [WriteCache link.fil \"[join $objects \"\n\"]\"]
    return [list @$rsp]
}

proc ::critcl::GetLibraries {file} {
    # On windows using the native MSVC compiler, transform all -lFOO
    # references into FOO.lib.

    return [FixLibraries [dict get $v::code($file) result clibraries]]
}

proc ::critcl::FixLibraries {libraries} {
    if {[string match "win32-*-cl" $v::buildplatform]} {
	# On windows using the native MSVC compiler, transform all
	# -lFOO references into FOO.lib.

	regsub -all -- {-l(\S+)} $libraries {\1.lib} libraries
    } else {
	# On unix we look for '-l:' references and rewrite them to the
	# full path of the library, doing the search on our own.
	#
	# GNU ld understands this since at least 2.22 (don't know if
	# earlier, 2.15 definitely doesn't), and it helps in
	# specifying static libraries (Regular -l prefers .so over .a,
	# and -l: overrides that).

	# Search paths specified via -L, -libdir.
	set lpath [SystemLibraryPaths]

	set tmp {}
	foreach word $libraries {
	    # Extend search path with -L options from clibraries.
	    if {[string match -L* $word]} {
		lappend lpath [string range $word 2 end]
		lappend tmp $word
		continue
	    }
	    if {![string match -l:* $word]} {
		lappend tmp $word
		continue
	    }
	    # Search named library.
	    lappend tmp [ResolveColonSpec $lpath [string range $word 3 end]]
	}
	set libraries $tmp
    }

    return $libraries
}

proc ::critcl::ResolveColonSpec {lpath name} {
    foreach path $lpath {
	set f [file join $lpath $name]
	if {![file exists $f]} continue
	return $f
    }
    return -l:$name
}

proc ::critcl::SetupTkStubs {fd mintcl} {
    if {[package vcompare $mintcl 8.6] < 0} {
	# Before 8.6+. tkStubsPtr and tkIntXlibStubsPtr are not const yet.
	set contents [Cat [Template tkstubs_noconst.c]]
    } else {
	set contents [Cat [Template tkstubs.c]]
    }

    puts -nonewline $fd $contents
    return
}

proc ::critcl::BuildDefines {fd file} {
    # we process the cdefines in three steps
    #   - get the list of defines by preprocessing the source using the
    #     cpp -dM directive which causes any #defines to be output
    #   - extract the list of enums using regular expressions (not perfect,
    #     but will do for now)
    #   - generate Tcl_ObjSetVar2 commands to initialise Tcl variables

    # Pull the collected ccode blocks together into a transient file
    # we then search in.

    set def [WriteCache define_[pid].c {}]
    foreach digest [dict get $v::code($file) config defs] {
	Append $def [dict get $v::code($file) config block $digest]
    }

    # For the command lines to be constructed we need all the include
    # information the regular files will get during their compilation.

    set hdrs [SystemIncludes $file]

    # The result of the next two steps, a list of triples (namespace +
    # label + value) of the defines to export.

    set defines {}

    # First step - get list of matching defines
    set         cmd [getconfigvalue preproc_define]
    lappendlist cmd $hdrs
    lappend     cmd $def

    set pipe [open "| $cmd" r]
    while {[gets $pipe line] >= 0} {
	# Check if the line contains a define.
	set fields [split [string trim $line]]
	if {[lindex $fields 0] ne "#define"} continue

	# Yes. Get name and value. The latter is the joining of all
	# fields after the name, except for any enclosing parentheses,
	# which we strip off.

	set var [lindex $fields 1]
	set val [string trim [join [lrange $fields 2 end]] {()}]

	# We ignore however any and all defines the user is not
	# interested in making public. This is, in essence, a set
	# intersection on the names of the defines.

	if {![TakeDefine $file $var namespace]} continue

	# And for those which are kept we integrate the information
	# from both sources, i.e. namespace, and definition, under a
	# single name.

	lappend defines $namespace $var $val
    }
    close $pipe

    # Second step - get list of enums

    set         cmd [getconfigvalue preproc_enum]
    lappendlist cmd $hdrs
    lappend     cmd $def

    set pipe [open "| $cmd" r]
    set code [read $pipe]
    close $pipe

    set matches [regexp -all -inline {enum [^\{\(\)]*{([^\}]*)}} $code]
    foreach {match submatch} $matches {
	foreach line [split $submatch \n] {
	    foreach sub [split $line ,] {
		set enum [lindex [split [string trim $sub]] 0]

		# We ignore however any and all enum values the user
		# is not interested in making public. This is, in
		# essence, a set intersection on the names of the
		# enum values.

		if {![TakeDefine $file $enum namespace]} continue

		# And for those which are kept we integrate the
		# information from both sources, i.e. namespace, and
		# definition, under a single name.

		lappend defines $namespace $enum $enum
	    }
	}
    }

    # Third step - generate Tcl_ObjSetVar2 commands exporting the
    # defines and their values as Tcl variables.

    foreach {namespace constname constvalue} $defines {
	if {![info exists created($namespace)]} {
	    # we need to force the creation of the namespace
	    # because this code will be run before the user code
	    puts $fd "  Tcl_Eval(ip, \"namespace eval $namespace {}\");"
	    set created($namespace) 1
	}
	set var "Tcl_NewStringObj(\"${namespace}::$constname\", -1)"
	if {$constname eq $constvalue} {
	    # enum - assume integer
	    set constvalue "Tcl_NewIntObj($constvalue)"
	} else {
	    # text or int - force to string
	    set constvalue "Tcl_NewStringObj(\"$constvalue\", -1)"
	}
	puts $fd "  Tcl_ObjSetVar2(ip, $var, NULL, $constvalue, TCL_GLOBAL_ONLY);"
    }

    # Cleanup after ourselves, removing the helper file.

    if {!$v::options(keepsrc)} { file delete $def }
    return
}

proc ::critcl::TakeDefine {file identifier nsvar} {
    upvar 1 $nsvar dst
    if 0 {if {[dict exists $v::code($file) config const $identifier]} {
	set dst [dict get $v::code($file) config const $identifier]
	return 1
    }}
    foreach {pattern def} [dict get $v::code($file) config const] {
	if {[string match $pattern $identifier]} {
	    set dst $def
	    return 1
	}
    }
    return 0
}

proc ::critcl::Load {f} {
    set shlib [dict get $v::code($f) result shlib]
    set init  [dict get $v::code($f) result initname]
    set tsrc  [dict get $v::code($f) result tsources]
    set minv  [dict get $v::code($f) result mintcl]

    # Using the renamed builtin. While this is a dependency it was
    # recorded already. See 'critcl::tcl', and 'critcl::tk'.
    #package require Tcl $minv
    ::load $shlib $init

    # See the critcl application for equivalent code placing the
    # companion tcl sources into the generated package. Here, for
    # 'compile & run' we now source the companion files directly.
    foreach t $tsrc {
	Ignore $t
	::source $t
    }
    return
}

proc ::critcl::ResolveRelative {prefixes flags} {
    set new {}
    set take no
    foreach flag $flags {
	if {$take} {
	    set take no
	    set flag [file normalize [file join [file dirname [This]] $flag]]
	    lappend new $flag
	    continue
	}
	foreach prefix $prefixes {
	    if {$flag eq $prefix} {
		set take yes
		lappend new $flag
		break
	    }
	    set n [string length $prefix]
	    if {[string match ${prefix}* $flag]} {
		set path [string range $flag $n end]
		set flag ${prefix}[file normalize [file join [file dirname [This]] $path]]
		break
	    }
	    if {[string match ${prefix}=* $flag]} {
		incr n
		set path [string range $flag $n end]
		set flag ${prefix}[file normalize [file join [file dirname [This]] $path]]
		break
	    }
	}
	lappend new $flag
    }
    return $new
}

proc ::critcl::LibPaths {clibraries} {
    set lpath {}
    set take no

    set sa [string length -L]
    set sb [string length --library-directory=]

    foreach word $clibraries {
	# Get paths from -L..., --library-directory ...,
	# --library-directory=...  and full library paths.  Ignore
	# anything else.

	if {$take} {
	    # path argument separate from preceding option.
	    set take no
	    lappend lpath $word
	    continue
	}
	if {[string match -L* $word]} {
	    # path at tail of argument
	    lappend lpath [string range $word $sa end]
	    continue
	}
	if {[string match -l* $word]} {
	    # ignore
	    continue
	}
	if {[string match --library-directory=* $word]} {
	    # path at tail of argument
	    lappend lpath [string range $word $sb end]
	    continue
	}
	if {[string equal --library-directory $word]} {
	    # Next argument is the desired path
	    set take yes
	    continue
	}
	if {[file isfile $word]} {
	    # directory of the file
	    lappend lpath [file dirname $word]
	}
	# else ignore
    }
    return $lpath
}

proc ::critcl::HandleDeclAfterBuild {} {
    # Hook default, mode "compile & run". Clear existing build results
    # for the file, make way for new declarations.

    set fx [This]
    if {[info exists v::code($fx)] &&
	[dict exists $v::code($fx) result]} {
	dict unset v::code($fx) result
    }
    return
}

# XXX Refactor to avoid duplication of the memoization code.
proc ::critcl::DetermineShlibName {file} {
    # Return cached information, if present.
    if {[info exists  v::code($file)] &&
	[dict exists $v::code($file) result shlib]} {
	return [dict get $v::code($file) result shlib]
    }

    # The name of the shared library we hope to produce (or use)
    set shlib [BaseOf $file][getconfigvalue sharedlibext]

    dict set v::code($file) result shlib $shlib
    return $shlib
}

proc ::critcl::DetermineObjectName {file} {
    # Return cached information, if present.
    if {[info exists  v::code($file)] &&
	[dict exists $v::code($file) result object]} {
	return [dict get $v::code($file) result object]
    }

    set object [BaseOf $file]

    # The generated object file will be saved for permanent use if the
    # outdir option is set (in which case rebuilds will no longer be
    # automatic).
    if {$v::options(outdir) ne ""} {
	set odir [file join [file dirname $file] $v::options(outdir)]
	set oroot  [file rootname [file tail $file]]
	set object [file normalize [file join $odir $oroot]]
	file mkdir $odir
    }

    # Modify the output file name if debugging symbols are requested.
    if {$option::debug_symbols} {
        append object _g
    }

    # Choose a distinct suffix so switching between them causes a
    # rebuild.
    switch -- $v::options(combine) {
	""         -
	dynamic    { append object _pic[getconfigvalue object] }
	static     { append object _stub[getconfigvalue object] }
	standalone { append object [getconfigvalue object] }
    }

    dict set v::code($file) result object $object
    return $object
}

proc ::critcl::DetermineInitName {file prefix} {
    set ininame [PkgInit $file]

    # Add in the build prefix, if specified. This is done in mode
    # 'generate package', for the pieces, ensuring that the overall
    # initialization function cannot be in conflict with the
    # initialization functions of these same pieces.

    if {$prefix ne ""} {
        set ininame "${prefix}_$ininame"
    }

    dict set v::code($file) result initname $ininame

    catch {
	dict set v::code($file) result pkgname \
	    [dict get $v::code($file) config package name]
    }

    return $ininame
}

proc ::critcl::PkgInit {file} {
    # The init function name takes a capitalized prefix from the name
    # of the input file name (alphanumeric prefix, including
    # underscores). This implicitly drops the file extension, as the
    # '.' is not an allowed character.

    # While related to the package name, it can be different,
    # especially if the package name contains :: separators.

    if {$file eq {}} {
	return Stdin
    } else {
	set ininame [file rootname [file tail $file]]
	regsub -all {[^[:alnum:]_]} $ininame {} ininame
	return [string totitle $ininame]
    }
}

# # ## ### ##### ######## ############# #####################
## Implementation -- Internals - Access to the log file

proc ::critcl::LogFile {} {
    file mkdir [cache]
    return [file join [cache] [pid].log]
}

proc ::critcl::LogFileExec {} {
    file mkdir [cache]
    return [file join [cache] [pid]_exec.log]
}

proc ::critcl::LogOpen {file} {
    set   v::logfile [LogFile]
    set   v::log     [open $v::logfile w]
    puts $v::log "\n[clock format [clock seconds]] - $file"
    # Create secondary file as well, leave empty, may not be used.
    close [open ${v::logfile}_ w]
    return
}

proc ::critcl::LogCmdline {cmdline} {
    set w [join [lassign $cmdline cmd] \n\t]
    Log \n$cmd\n\t$w\n
    return
}

proc ::critcl::Log {msg} {
    puts $v::log $msg
    return
}

proc ::critcl::Log* {msg} {
    puts -nonewline $v::log $msg
    return
}

proc ::critcl::LogClose {} {
    # Transfer the log messages for the current file over into the
    # global critcl log, and cleanup.

    close $v::log
    set msgs [Cat $v::logfile]
    set emsg [Cat ${v::logfile}_]

    AppendCache $v::prefix.log $msgs

    file delete -force $v::logfile ${v::logfile}_
    unset v::log v::logfile

    return [list $msgs $emsg]
}

# # ## ### ##### ######## ############# #####################
## Implementation -- Internals - UUID management, change detection

proc ::critcl::UUID.extend {file key value} {
    set digest [md5_hex /$value]
    InitializeFile $file
    dict update v::code($file) config c {
	dict lappend c uuid $key $digest
    }
    return $digest
}

proc ::critcl::UUID.serial {file} {
    InitializeFile $file
    if {[catch {
	set len [llength [dict get $v::code($file) config uuid]]
    }]} {
	set len 0
    }
    return $len
}

proc ::critcl::UUID {f} {
    return [md5_hex "$f [GetParam $f uuid]"]
}

proc ::critcl::BaseOf {f} {
    # Return cached information, if present.
    if {[info exists  v::code($f)] &&
	[dict exists $v::code($f) result base]} {
	return [dict get $v::code($f) result base]
    }

    set base [file normalize \
		  [file join [cache] ${v::prefix}_[UUID $f]]]

    dict set v::code($f) result base $base
    return $base
}

# # ## ### ##### ######## ############# #####################
## Implementation -- Internals - Miscellanea

proc ::critcl::Deline {text} {
    if {![config lines]} {
	set text [join [GrepV "\#line*" [split $text \n]] \n]
    }
    return $text
}

proc ::critcl::Separator {} {
    return "/* [string repeat - 70] */"
}

proc ::critcl::Template {file} {
    variable v::hdrdir
    return [file join $hdrdir $file]
}

proc ::critcl::Copy {src dst} {
    foreach p [glob -nocomplain $src] {
	if {[file isdirectory $p]} {
	    set stem [file tail $p]
	    file mkdir $dst/$stem
	    Copy $p/* $dst/$stem
	} else {
	    file copy -force $p $dst
	}
    }
}

proc ::critcl::Cat {path} {
    # Easier to write our own copy than requiring fileutil and then using fileutil::cat.

    set fd [open $path r]
    set data [read $fd]
    close $fd
    return $data
}

proc ::critcl::WriteCache {name content} {
    set dst [file join [cache] $name]
    file mkdir [file dirname $dst] ;# just in case
    return [Write [file normalize $dst] $content]
}

proc ::critcl::Write {path content} {
    set    chan [open $path w]
    puts  $chan $content
    close $chan
    return $path
}

proc ::critcl::AppendCache {name content} {
    file mkdir [cache] ;# just in case
    return [Append [file normalize [file join [cache] $name]] $content]
}

proc ::critcl::Append {path content} {
    set    chan [open $path a]
    puts  $chan $content
    close $chan
    return $path
}

# # ## ### ##### ######## ############# #####################
## Implementation -- Internals - Status Operations, and execution
## of external commands.

proc ::critcl::StatusReset {} {
    set v::failed 0
    return
}

proc ::critcl::StatusAbort? {} {
    if {$v::failed} { return -code return }
    return
}

proc ::critcl::StatusSave {file} {
    # XXX FUTURE Use '$(file) result failed' later
    set result $v::failed
    set v::code($file,failed) $v::failed
    set v::failed 0
    return $result
}

proc ::critcl::CheckForWarnings {text} {
    set warnings [dict create]
    foreach line [split $text \n] {
	# Ignore everything not a warning.
        if {![string match -nocase *warning* $line]} continue
	# Ignore duplicates (which is why we store the lines as dict
	# keys for now).
	if {[dict exists $warnings $line]} continue
	dict set warnings $line .
    }
    return [dict keys $warnings]
}

proc ::critcl::Exec {cmdline} {
    variable run

    set v::failed [catch {
	interp eval $run [linsert $cmdline 0 exec]
    } v::err]

    return [expr {!$v::failed}]
}

proc ::critcl::ExecWithLogging {cmdline okmsg errmsg} {
    variable run

    # todo (debug flag) msg "EXEC: $cmdline"
    LogCmdline $cmdline

    # Extend the command, redirect all of its output (stdout and
    # stderr) into a temp log.
    set elogfile [LogFileExec]
    set elog     [open $elogfile w]

    lappend cmdline >&@ $elog
    interp transfer {}  $elog $run

    set ok [Exec $cmdline]

    interp transfer $run $elog {}
    close $elog

    # Put the command output into the main log ...
    set  msgs [Cat $elogfile]
    Log $msgs

    # ... as well as into a separate execution log.
    Append ${v::logfile}_ $msgs

    file delete -force $elogfile

    if {$ok} {
	Log [uplevel 1 [list subst $okmsg]]
    } else {
	Log [uplevel 1 [list subst $errmsg]]
	Log $v::err
    }

    return $ok
}

proc ::critcl::BuildPlatform {} {
    set platform [::platform::generic]

    # Behave like an autoconf generated configure
    # - $CC (user's choice first)
    # - gcc, if available.
    # - cc/cl otherwise (without further check for availability)

    if {[info exists ::env(CC)]} {
	# The compiler may be a gcc, despite being named .../cc.

	set cc $::env(CC)
	if {[IsGCC $cc]} {
	    set cc gcc
	}
    } elseif {[llength [auto_execok gcc]]} {
	set cc gcc
    } else {
	if {[string match "win32-*" $platform]} {
	    set cc cl
	} else {
	    set cc cc
	}
    }

    # The cc may be specified with a full path, through the CC
    # environment variable, which cannot be used as is in the platform
    # code. Use only the last element of the path, without extensions
    # (.exe). And it may be followed by options too, so look for and
    # strip these off as well. This last part assumes that the path of
    # the compiler itself doesn't contain spaces.

    regsub {( .*)$} [file tail $cc] {} cc
    append platform -[file rootname $cc]

    # Memoize
    proc ::critcl::BuildPlatform {} [list return $platform]
    return $platform
}

proc ::critcl::IsGCC {path} {
    if {[catch {
	set lines [exec $path -v |& grep gcc]
    }] || ($lines eq {})} { return 0 }
    return 1
}

proc ::critcl::This {} {
    variable v::this
    # For management of v::this see critcl::{source,collect*}
    # If present, an output redirection is active.
    if {[info exists this] && [llength $this]} {
	return [lindex $this end]
    }
    return [file normalize [info script]]
}

proc ::critcl::Here {} {
    return [file dirname [This]]
}

proc ::critcl::TclDecls {file} {
    return [TclDef $file tclDecls.h     tclStubsPtr    {tclStubsPtr    }]
}

proc ::critcl::TclPlatDecls {file} {
    return [TclDef $file tclPlatDecls.h tclPlatStubsPtr tclPlatStubsPtr]
}

proc ::critcl::TclDef {file hdr var varlabel} {
    #puts F|$file
    set hdr [TclHeader $file $hdr]

    if {![file exists   $hdr]} { error "Header file not found: $hdr" }
    if {![file isfile   $hdr]} { error "Header not a file: $hdr" }
    if {![file readable $hdr]} { error "Header not readable: $hdr (no permission)" }

    #puts H|$hdr
    if {[catch {
	set hdrcontent [split [Cat $hdr] \n]
    } msg]} {
	error "Header not readable: $hdr ($msg)"
    }

    # Note, Danger: The code below is able to use declarations which
    # are commented out in various ways (#if 0, /* ... */, and //
    # ...), because it is performing a simple line-oriented search
    # without context, and not matching against comment syntax either.

    set ext [Grep *extern* $hdrcontent]
    if {![llength $ext]} {
	error "No extern declarations found in $hdr"
    }

    set vardecl [Grep *${var}* $ext]
    if {![llength $vardecl]} {
	error "No declarations for $var found in $hdr"
    }

    set def [string map {extern {}} [lindex $vardecl 0]]
    msg "    [join [lrange [file split $hdr] end-3 end] /]:"
    msg "      ($varlabel => $def)"
    return $def
}

proc ::critcl::Grep {pattern lines} {
    set r {}
    foreach line $lines {
	if {![string match $pattern $line]} continue
	lappend r $line
    }
    return $r
}

proc ::critcl::GrepV {pattern lines} {
    set r {}
    foreach line $lines {
	if {[string match $pattern $line]} continue
	lappend r $line
    }
    return $r
}

proc ::critcl::PadRight {len w} {
    # <=> Left justified
    format %-${len}s $w
}

proc ::critcl::LengthLongestWord {words} {
    set max 0
    foreach w $words {
	set n [string length $w]
	if {$n <= $max} continue
	set max $n
    }
    return $max
}

# # ## ### ##### ######## ############# #####################
## Tcl 8.6 vs 9 checking. The check is simple, there is no C
## parsing. No detection of C comments either.

proc ::critcl::Transition9Check {loc script} {
    if {!$v::options(tcl9)} return

    lassign $loc filename lno
    if {$filename eq {}} { set filename <undef> }
    if {$lno      eq {}} { set lno      1 }

    foreach line [split $script \n] {
	Transition9CheckLine $filename $lno $line
	incr lno
    }
    return
}

proc ::critcl::Transition9CheckLine {file lno codeline} {
    set reported 0

    # TIP 568 Tcl_GetByteArrayFromObj transition to Tcl_GetBytesFromObj
    if {[string match *Tcl_GetByteArrayFromObj* $codeline]} {
	T9Report $file $lno $codeline "(TIP 568): Use `Tcl_GetBytesFromObj` and handle NULL results."
	T9Report $file $lno $codeline "(TIP 568): Read the referenced TIP for the sordid details."
	T9Report $file $lno $codeline "(TIP 568): Document the obligations of the script level."
    }

    foreach fun {
	Tcl_NewStringObj
	Tcl_AppendToObj
	Tcl_AddObjErrorInfo
	Tcl_DStringAppend
	Tcl_NumUtfChars
	Tcl_UtfToUniCharDString
	Tcl_LogCommandInfo
	Tcl_AppendLimitedToObj
    } {
	if { [string match *${fun}*     $codeline] &&
	     [string match *-1*         $codeline] &&
	     ![string match {*OK tcl9*} $codeline]} {
	    T9Report $file $lno $codeline "(TIP 494): Use TCL_AUTO_LENGTH for string length."
	}
    }

    # Tcl_Size I
    foreach {kind fun} [Transition9TclSize] {
	if {![string match *${fun}*    $codeline]} continue
	if { [string match {*OK tcl9*} $codeline]} continue
	T9Report $file $lno $codeline "(Tcl_Size): $fun ($kind)"
    }

    # Tcl_Size II
    foreach {fun replace} {
	Tcl_GetIntFromObj Tcl_GetSizeIntFromObj
	Tcl_NewIntObj	  Tcl_NewSizeIntObj
    } {
	if {![string match *${fun}*    $codeline]} continue
	if { [string match {*OK tcl9*} $codeline]} continue
	T9Report $file $lno $codeline "(Tcl_Size): $fun, check if replacement $replace is needed"
    }

    # Tcl Interp State handling
    foreach {pattern message} {
	Tcl_SavedResult   {Reewrite to use type `Tcl_InterpState` instead}
	Tcl_SaveResult    {Rewrite to `<statevar> = Tcl_SaveInterpState (<interp>, TCL_OK)`}
	Tcl_RestoreResult {Rewrite to `Tcl_RestoreInterpState (<interp>, <statevar>)`}
	Tcl_DiscardResult {Rewrite to `Tcl_DiscardInterpState (<statevar>)`}
    } {
	if {![string match *${pattern}* $codeline]} continue
	T9Report $file $lno $codeline "(Interp State handling): $message"
    }

    # command creation
    if { [string match *Tcl_CreateObjCommand*  $codeline] &&
	![string match *Tcl_CreateObjCommand2* $codeline]} {
	T9Report $file $lno $codeline "(Tcl_Size): Use `Tcl_CreateObjCommand2` for command creation"
    }
    return
}

proc ::critcl::T9Report {fname lno code msg} {
    upvar 1 reported reported

    set prefix "File \"$fname\", line $lno: "
    set common "Tcl 9 compatibility warning "

    set blue \033\[34m
    set off  \033\[0m
    set mag  \033\[35m

    if {!$reported} { critcl::msg "$prefix$blue[string trim $code]$off" }
    incr reported
    critcl::msg "$prefix${common}: $mag$msg$off"
}

proc ::critcl::Transition9TclSize {} {
    return {
	InParam Tcl_AppendFormatToObj
	InParam Tcl_AppendLimitedToObj
	InParam Tcl_AppendLimitedToObj
	InParam Tcl_AppendToObj
	InParam Tcl_AppendUnicodeToObj
	InParam Tcl_AttemptSetObjLength
	InParam Tcl_Char16ToUtfDString
	InParam Tcl_Concat
	InParam Tcl_ConcatObj
	InParam Tcl_ConvertCountedElement
	InParam Tcl_CreateAlias
	InParam Tcl_CreateAliasObj
	InParam Tcl_CreateObjTrace
	InParam Tcl_CreateObjTrace2
	InParam Tcl_CreateTrace
	InParam Tcl_DbNewByteArrayObj
	InParam Tcl_DbNewListObj
	InParam Tcl_DbNewStringObj
	InParam Tcl_DetachPids
	InParam Tcl_DictObjPutKeyList
	InParam Tcl_DictObjRemoveKeyList
	InParam Tcl_DStringAppend
	InParam Tcl_DStringSetLength
	InParam Tcl_EvalEx
	InParam Tcl_EvalObjv
	InParam Tcl_EvalTokensStandard
	InParam Tcl_ExternalToUtf
	InParam Tcl_ExternalToUtf
	InParam Tcl_ExternalToUtfDString
	InParam Tcl_ExternalToUtfDStringEx
	InParam Tcl_Format
	InParam Tcl_FSJoinPath
	InParam Tcl_FSJoinToPath
	InParam Tcl_GetIndexFromObjStruct
	InParam Tcl_GetIntForIndex
	InParam Tcl_GetNumber
	InParam Tcl_GetRange
	InParam Tcl_GetRange
	InParam Tcl_GetThreadData
	InParam Tcl_GetUniChar
	InParam Tcl_JoinPath
	InParam Tcl_LimitSetCommands
	InParam Tcl_LinkArray
	InParam Tcl_ListObjIndex
	InParam Tcl_ListObjReplace
	InParam Tcl_ListObjReplace
	InParam Tcl_ListObjReplace
	InParam Tcl_LogCommandInfo
	InParam Tcl_MacOSXOpenVersionedBundleResources
	InParam Tcl_MainEx
	InParam Tcl_Merge
	InParam Tcl_NewByteArrayObj
	InParam Tcl_NewListObj
	InParam Tcl_NewStringObj
	InParam Tcl_NewUnicodeObj
	InParam Tcl_NRCallObjProc
	InParam Tcl_NRCallObjProc2
	InParam Tcl_NRCmdSwap
	InParam Tcl_NREvalObjv
	InParam Tcl_NumUtfChars
	InParam Tcl_OpenCommandChannel
	InParam Tcl_ParseBraces
	InParam Tcl_ParseCommand
	InParam Tcl_ParseExpr
	InParam Tcl_ParseQuotedString
	InParam Tcl_ParseVarName
	InParam Tcl_PkgRequireProc
	InParam Tcl_ProcObjCmd
	InParam Tcl_Read
	InParam Tcl_ReadChars
	InParam Tcl_ReadRaw
	InParam Tcl_RegExpExecObj
	InParam Tcl_RegExpExecObj
	InParam Tcl_RegExpRange
	InParam Tcl_ScanCountedElement
	InParam Tcl_SetByteArrayLength
	InParam Tcl_SetByteArrayObj
	InParam Tcl_SetChannelBufferSize
	InParam Tcl_SetListObj
	InParam Tcl_SetObjLength
	InParam Tcl_SetRecursionLimit
	InParam Tcl_SetStringObj
	InParam Tcl_SetUnicodeObj
	InParam Tcl_Ungets
	InParam Tcl_UniCharAtIndex
	InParam Tcl_UniCharToUtfDString
	InParam Tcl_UtfAtIndex
	InParam Tcl_UtfCharComplete
	InParam Tcl_UtfToChar16DString
	InParam Tcl_UtfToExternal
	InParam Tcl_UtfToExternal
	InParam Tcl_UtfToExternalDString
	InParam Tcl_UtfToExternalDStringEx
	InParam Tcl_UtfToUniCharDString
	InParam Tcl_Write
	InParam Tcl_WriteChars
	InParam Tcl_WriteRaw
	InParam Tcl_WrongNumArgs
	InParam Tcl_ZlibAdler32
	InParam Tcl_ZlibCRC32
	InParam Tcl_ZlibInflate
	InParam Tcl_ZlibStreamGet
	InParam TclGetRange
	InParam TclGetRange
	InParam TclGetUniChar
	InParam TclNumUtfChars
	InParam TclUtfAtIndex
	InParam TclUtfCharComplete

	OutParam Tcl_DictObjSize
	OutParam Tcl_ExternalToUtfDStringEx
	OutParam Tcl_FSSplitPath
	OutParam Tcl_GetByteArrayFromObj
	OutParam Tcl_GetBytesFromObj
	OutParam Tcl_GetIntForIndex
	OutParam Tcl_GetSizeIntFromObj
	OutParam Tcl_GetStringFromObj
	OutParam Tcl_GetUnicodeFromObj
	OutParam Tcl_ListObjGetElements
	OutParam Tcl_ListObjLength
	OutParam Tcl_ParseArgsObjv
	OutParam Tcl_SplitList
	OutParam Tcl_SplitPath
	OutParam Tcl_UtfToExternalDStringEx

	Return Tcl_Char16Len
	Return Tcl_ConvertCountedElement
	Return Tcl_ConvertElement
	Return Tcl_GetChannelBufferSize
	Return Tcl_GetCharLength
	Return Tcl_GetEncodingNulLength
	Return Tcl_Gets
	Return Tcl_GetsObj
	Return Tcl_NumUtfChars
	Return Tcl_Read
	Return Tcl_ReadChars
	Return Tcl_ReadRaw
	Return Tcl_ScanCountedElement
	Return Tcl_ScanElement
	Return Tcl_SetRecursionLimit
	Return Tcl_Ungets
	Return Tcl_UniCharLen
	Return Tcl_UniCharToUtf
	Return Tcl_UtfBackslash
	Return Tcl_UtfToChar16
	Return Tcl_UtfToLower
	Return Tcl_UtfToTitle
	Return Tcl_UtfToUniChar
	Return Tcl_UtfToUpper
	Return Tcl_Write
	Return Tcl_WriteChars
	Return Tcl_WriteObj
	Return Tcl_WriteRaw
	Return TclGetCharLength
	Return TclNumUtfChars
    }
}

# # ## ### ##### ######## ############# #####################
## Initialization

proc ::critcl::Initialize {} {
    variable mydir [Here] ; # Path of the critcl package directory.

    variable run              [interp create]
    variable v::buildplatform [BuildPlatform]
    variable v::hdrdir	      [file join $mydir critcl_c]
    variable v::hdrsavailable
    variable v::storageclass  [Cat [file join $hdrdir storageclass.c]]

    # Scan the directory holding the C fragments and our copies of the
    # Tcl header and determine for which versions of Tcl we actually
    # have headers. This allows distributions to modify the directory,
    # i.e. drop our copies and refer to the system headers instead, as
    # much as are installed, and critcl adapts. The tcl versions are
    # recorded in ascending order, making upcoming searches easier,
    # the first satisfying version is also always the smallest.

    foreach d [lsort -dict [glob -types {d r} -directory $hdrdir -tails tcl*]] {
	lappend hdrsavailable [regsub {^tcl} $d {}]
    }

    # The prefix is based on the package's version. This allows
    # multiple versions of the package to use the same cache without
    # interfering with each. Note that we cannot use 'pid' and similar
    # information, because this would circumvent the goal of the
    # cache, the reuse of binaries whose sources did not change.

    variable v::prefix	"v[package require critcl]"

    regsub -all {\.} $prefix {} prefix

    # keep config options in a namespace
    foreach var $v::configvars {
	set c::$var {}
    }

    # read default configuration. This also chooses and sets the
    # target platform.
    readconfig [file join $mydir Config]

    # Declare the standard argument types for cproc.

    argtype int {
	if (Tcl_GetIntFromObj(interp, @@, &@A) != TCL_OK) return TCL_ERROR;
    }
    argtype boolean {
	if (Tcl_GetBooleanFromObj(interp, @@, &@A) != TCL_OK) return TCL_ERROR;
    } int int
    argtype bool = boolean

    argtype long {
	if (Tcl_GetLongFromObj(interp, @@, &@A) != TCL_OK) return TCL_ERROR;
    }

    argtype wideint {
	if (Tcl_GetWideIntFromObj(interp, @@, &@A) != TCL_OK) return TCL_ERROR;
    } Tcl_WideInt Tcl_WideInt

    argtype double {
	if (Tcl_GetDoubleFromObj(interp, @@, &@A) != TCL_OK) return TCL_ERROR;
    }
    argtype float {
	double t;
	if (Tcl_GetDoubleFromObj(interp, @@, &t) != TCL_OK) return TCL_ERROR;
	@A = (float) t;
    }

    # Premade scalar type derivations for common range restrictions.
    # Look to marker XXXA for the places where auto-creation would
    # need fitting in (future).
    #
    # See also `MakeScalarLimited`, which is able to generate validators for extended forms of this
    # kind (multiple relations, arbitrary limit values, ...)
    foreach type {
	int long wideint double float
    } {
	set ctype [ArgumentCType $type]
	set code  [ArgumentConversion $type]
	foreach restriction {
	    {> 0}	    {>= 0}	    {> 1}	    {>= 1}
	    {< 0}	    {<= 0}	    {< 1}	    {<= 1}
	} {
	    set ntype "$type $restriction"
	    set head  "expected $ntype, but got \\\""
	    set tail  "\\\""
	    set msg   "\"$head\", Tcl_GetString (@@), \"$tail\""
	    set    new $code
	    append new \
		"\n\t/* Range check, assert (x $restriction) */" \
		"\n\tif (!(@A $restriction)) \{" \
		"\n\t    Tcl_AppendResult (interp, $msg, NULL);" \
		"\n\t    return TCL_ERROR;" \
		"\n\t\}"

	    argtype $ntype $new $ctype $ctype
	}
    }

    argtype char* {
	@A = Tcl_GetString(@@);
    } {const char*} {const char*}

    argtype pstring {
	@A.s = Tcl_GetStringFromObj(@@, &(@A.len));
	@A.o = @@;
    } critcl_pstring critcl_pstring

    argtypesupport pstring {
	typedef struct critcl_pstring {
	    Tcl_Obj*    o;
	    const char* s;
	    Tcl_Size    len;
	} critcl_pstring;
    }

    argtype dict {
	Tcl_Size size;
	if (Tcl_DictObjSize (interp, @@, &size) != TCL_OK) return TCL_ERROR;
	@A = @@;
    } Tcl_Obj* Tcl_Obj*

    argtype list {
	if (Tcl_ListObjGetElements (interp, @@, /* OK tcl9 */
		    &(@A.c), (Tcl_Obj***) &(@A.v)) != TCL_OK) return TCL_ERROR;
	@A.o = @@;
    } critcl_list critcl_list

    argtypesupport list {
	typedef struct critcl_list {
	    Tcl_Obj*        o;
	    Tcl_Obj* const* v;
	    Tcl_Size        c;
	} critcl_list;
    }

    # See also `MakeList` which is able to generate arbitrary length-limited lists, lists over a
    # base type, or a combination of both. This here defines the base case of the recognized syntax
    # for "unlimited-length list with no base type". This shortcuts the operation of `MakeList`, no
    # special types and code needed.
    argtype {[]} = list
    argtype {[*]} = list

    argtype Tcl_Obj* {
	@A = @@;
    }
    argtype object = Tcl_Obj*

    # Predefined variadic type for the special Tcl_Obj*.
    # - No actual conversion, nor allocation, copying, release needed.
    # - Just point into and reuse the incoming ov[] array.
    # This shortcuts the operation of 'MakeVariadicTypeFor'.

    argtype variadic_object {
	@A.c = @C;
	@A.v = &ov[@I];
    } critcl_variadic_object critcl_variadic_object

    argtypesupport variadic_object {
	typedef struct critcl_variadic_object {
	    int             c;
	    Tcl_Obj* const* v;
	} critcl_variadic_object;
    }

    argtype variadic_Tcl_Obj* = variadic_object

    # NEW Raw binary string _with_ length information.

    argtype bytes {
	/* Raw binary string _with_ length information */
	@A.s = Tcl_GetBytesFromObj(interp, @@, &(@A.len));
	if (@A.s == NULL) return TCL_ERROR;
	@A.o = @@;
    } critcl_bytes critcl_bytes

    argtypesupport bytes {
	typedef struct critcl_bytes {
	    Tcl_Obj*             o;
	    const unsigned char* s;
	    Tcl_Size             len;
	} critcl_bytes;
    }

    argtype channel {
	int mode;
	@A = Tcl_GetChannel(interp, Tcl_GetString (@@), &mode);
	if (@A == NULL) return TCL_ERROR;
    } Tcl_Channel Tcl_Channel

    argtype unshared-channel {
	int mode;
	@A = Tcl_GetChannel(interp, Tcl_GetString (@@), &mode);
	if (@A == NULL) return TCL_ERROR;
	if (Tcl_IsChannelShared (@A)) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj("channel is shared", -1));
	    return TCL_ERROR;
	}
    } Tcl_Channel Tcl_Channel

    # Note, the complementary resulttype is `return-channel`.
    argtype take-channel {
	int mode;
	@A = Tcl_GetChannel(interp, Tcl_GetString (@@), &mode);
	if (@A == NULL) return TCL_ERROR;
	if (Tcl_IsChannelShared (@A)) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj("channel is shared", -1));
	    return TCL_ERROR;
	}
	{
	    /* Disable event processing for the channel, both by
	     * removing any registered handler, and forcing interest
	     * to none. This also disables the processing of pending
	     * events which are ready to fire for the given
	     * channel. If we do not do this, events will hit the
	     * detached channel and potentially wreck havoc on our
	     * memory and eventually badly hurt us...
	     */
	    Tcl_DriverWatchProc *watchProc;
	    Tcl_ClearChannelHandlers(@A);
	    watchProc = Tcl_ChannelWatchProc(Tcl_GetChannelType(@A));
	    if (watchProc) {
		(*watchProc)(Tcl_GetChannelInstanceData(@A), 0);
	    }
	    /* Next some fiddling with the reference count to prevent
	     * the unregistration from killing it. We basically record
	     * it as globally known before removing it from the
	     * current interpreter
	     */
	    Tcl_RegisterChannel((Tcl_Interp *) NULL, @A);
	    Tcl_UnregisterChannel(interp, @A);
	}
    } Tcl_Channel Tcl_Channel

    resulttype void {
	return TCL_OK;
    }

    resulttype ok {
	return rv;
    } int

    resulttype int {
	Tcl_SetObjResult(interp, Tcl_NewIntObj(rv));
	return TCL_OK;
    }
    resulttype boolean = int
    resulttype bool    = int

    resulttype long {
	Tcl_SetObjResult(interp, Tcl_NewLongObj(rv));
	return TCL_OK;
    }

    resulttype wideint {
	Tcl_SetObjResult(interp, Tcl_NewWideIntObj(rv));
	return TCL_OK;
    } Tcl_WideInt

    resulttype double {
	Tcl_SetObjResult(interp, Tcl_NewDoubleObj(rv));
	return TCL_OK;
    }
    resulttype float {
	Tcl_SetObjResult(interp, Tcl_NewDoubleObj(rv));
	return TCL_OK;
    }

    # Static and volatile strings. Duplicate.
    resulttype char* {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(rv, -1));
	return TCL_OK;
    }
    resulttype {const char*} {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(rv, -1));
	return TCL_OK;
    }
    resulttype vstring = char*

    # Dynamic strings, allocated via Tcl_Alloc.
    #
    # We are avoiding the Tcl_Obj* API here, as its use requires an
    # additional duplicate of the string, churning memory and
    # requiring more copying.
    #   Tcl_SetObjResult(interp, Tcl_NewStringObj(rv, -1));
    #   Tcl_Free (rv);
    resulttype string {
	Tcl_SetResult (interp, rv, TCL_DYNAMIC);
	return TCL_OK;
    } char*
    resulttype dstring = string

    resulttype Tcl_Obj* {
	if (rv == NULL) { return TCL_ERROR; }
	Tcl_SetObjResult(interp, rv);
	Tcl_DecrRefCount(rv);
	return TCL_OK;
    }
    resulttype object = Tcl_Obj*

    critcl::resulttype Tcl_Obj*0 {
	if (rv == NULL) { return TCL_ERROR; }
	Tcl_SetObjResult(interp, rv);
	/* No refcount adjustment */
	return TCL_OK;
    } Tcl_Obj*
    resulttype object0 = Tcl_Obj*0

    resulttype new-channel {
	if (rv == NULL) { return TCL_ERROR; }
	Tcl_RegisterChannel (interp, rv);
	Tcl_SetObjResult (interp, Tcl_NewStringObj (Tcl_GetChannelName (rv), -1));
	return TCL_OK;
    } Tcl_Channel

    resulttype known-channel {
	if (rv == NULL) { return TCL_ERROR; }
	Tcl_SetObjResult (interp, Tcl_NewStringObj (Tcl_GetChannelName (rv), -1));
	return TCL_OK;
    } Tcl_Channel

    # Note, this is complementary to argtype `take-channel`.
    resulttype return-channel {
	if (rv == NULL) { return TCL_ERROR; }
	Tcl_RegisterChannel (interp, rv);
	Tcl_UnregisterChannel(NULL, rv);
	Tcl_SetObjResult (interp, Tcl_NewStringObj (Tcl_GetChannelName (rv), -1));
	return TCL_OK;
    } Tcl_Channel

    rename ::critcl::Initialize {}
    return
}

# # ## ### ##### ######## ############# #####################
## State

namespace eval ::critcl {
    variable mydir    ;# Path of the critcl package directory.
    variable run      ;# interpreter to run commands, eval when, etc

    # XXX configfile - See the *config commands, path of last config file run through 'readconfig'.

    # namespace to flag when options set
    namespace eval option {
        variable debug_symbols  0
    }

    # keep all variables in a sub-namespace for easy access
    namespace eval v {
	variable cache           ;# Path. Cache directory. Platform-dependent
				  # (target platform).

	# ----------------------------------------------------------------

	# (XX) To understand the set of variables below and their
	# differences some terminology is required.
	#
	# First we have to distinguish between "target identifiers"
	# and "platform identifiers". The first is the name for a
	# particular set of configuration settings specifying commands
	# and command line arguments to use. The second is the name of
	# a machine configuration, identifying both operating system,
	# and cpu architecture.
	#
	# The problem critcl has is that in 99% of the cases found in
	# a critcl config file the "target identifier" is also a valid
	# "platform identifier". Example: "linux-ix86". That does not
	# make them semantically interchangable however.
	#
	# Especially when we add cross-compilation to the mix, where
	# we have to further distinguish between the platform critcl
	# itself is running on (build), and the platform for which
	# critcl is generating code (target), and the last one sounds
	# similar to "target identifier".

	variable targetconfig    ;# Target identifier. The chosen configuration.
	variable targetplatform  ;# Platform identifier. Type of generated binaries.
	variable buildplatform   ;# Platform identifier. We run here.

	variable knowntargets {} ;# List of all target identifiers found
	# in the configuration file last processed by "readconfig".

	variable xtargets        ;# Cross-compile targets. This array maps from
	array set xtargets {}    ;# the target identifier to the actual platform
	# identifier of the target platform in question. If a target identifier
	# has no entry here, it is assumed to be the platform identifier itself.
	# See "critcl::actualtarget".

	# ----------------------------------------------------------------

	variable version ""      ;# String. Min version number on platform
	variable hdrdir          ;# Path. Directory containing the helper
				  # files of the package. A sub-
				  # directory of 'mydir', see above.
	variable hdrsavailable   ;# List. Of Tcl versions for which we have
	                          # Tcl header files available. For details
	                          # see procedure 'Initialize' above.
	variable prefix          ;# String. The string to start all file names
				  # generated by the package with. See
				  # 'Initialize' for our choice and
				  # explanation of it.
	variable options         ;# An array containing options
				  # controlling the code generator.
				  # For more details see below.
	set options(outdir)   "" ;# - Path. If set the place where the generated
				  #   shared library is saved for permanent use.
	set options(keepsrc)  0  ;# - Boolean. If set all generated .c files are
				  #   kept after compilation. Helps with debugging
				  #   the critcl package.
	set options(combine)  "" ;# - XXX standalone/dynamic/static
				  #   XXX Meaning of combine?
	set options(force)    0  ;# - Boolean. If set (re)compilation is
				  #   forced, regardless of the state of
				  #   the cache.
	set options(I)        "" ;# - List. Additional include
				  #   directories, globally specified by
				  #   the user for mode 'generate
				  #   package', for all components put
				  #   into the package's library.
	set options(L)        "" ;# - List. Additional library search
				  #   directories, globally specified by
				  #   the user for mode 'generate
				  #   package'.
	set options(language) "" ;# - String. XXX
	set options(tcl9)     1  ;# - Boolean. If set critcl will check C code
				  #   fragments for 8.6/9 compatibility problems.
	set options(lines)    1  ;# - Boolean. If set the generator will
				  #   emit #line-directives to help locating
				  #   C code in the .tcl in case of compile
				  #   warnings and errors.
	set options(trace)    0  ;# - Boolean. If set the generator will
	                          #   emit code tracing command entry
	                          #   and return, for all cprocs and
	                          #   ccommands. The latter is done by
	                          #   creating a shim function. For
	                          #   cprocs their regular shim
	                          #   function is used and modified.
	                          #   The functionality is based on
	                          #   'critcl::cutil's 'tracer'
	                          #   command and C code.

	# XXX clientdata() per-command (See ccommand). per-file+ccommand better?
	# XXX delproc()    per-command (See ccommand). s.a

	# XXX toolchain()  <platform>,<configvarname> -> data
	# XXX            Used only in {read,set,show}config.
	# XXX            Seems to be a database holding the total contents of the
	# XXX            config file.

	# knowntargets  - See the *config commands, list of all platforms we can compile for.

	# I suspect that this came later

	# Conversion maps, Tcl types for procedure arguments and
	# results to C types and code fragments for the conversion
	# between the realms. Used by the helper commands
	# "ArgumentCType", "ArgumentConversion", and
	# "ResultConversion". These commands also supply the default
	# values for unknown types.

	variable  actype
	array set actype {}

	variable  actypeb
	array set actypeb {}

	# In the code fragments below we have the following environment (placeholders, variables):
	# ip - C variable, Tcl_Interp* of the interpreter providing the arguments.
	# @@ - Tcl_Obj* valued expression returning the Tcl argument value.
	# @A - Name of the C-level argument variable.
	#
	variable  aconv
	array set aconv {}

	# Mapping from cproc result to C result type of the function.
	# This is also the C type of the helper variable holding the result.
	# NOTE: 'void' is special, as it has no result, nor result variable.
	variable  rctype
	array set rctype {}

	# In the code fragments for result conversion:
	# 'rv' == variable capturing the return value of the C function.
	# 'ip' == variable containing pointer to the interp to set the result into.
	variable  rconv
	array set rconv {}

	variable storageclass {} ;# See Initialize for setup.

	variable code	         ;# This array collects all code snippets and
				  # data about them.

	# Keys for 'code' (above) and their contents:
	#
	# <file> -> Per-file information, nested dictionary. Sub keys:
	#
	#	result		- Results needed for 'generate package'.
	#		initname	- String. Foo in Foo_Init().
	#		tsources	- List. The companion tcl sources for <file>.
	#		object		- String. Name of the object file backing <file>.
	#		objects		- List. All object files, main and companions.
	#		shlib		- String. Name of the shared library backing <file>.
	#		base		- String. Common prefix (file root) of 'object' and 'shlib'.
	#		clibraries	- List. See config. Copy for global linkage.
	#		ldflags		- List. See config. Copy for global linkage.
	#		mintcl		- String. Minimum version of Tcl required by the package.
	#		preload		- List. Names of all libraries to load before the package library.
	#		license		- String. License text.
	#	<= "critcl::cresults"
	#
	#	config		- Collected code and configuration (ccode, etc.).
	#		tsources	- List. The companion tcl sources for <file>.
	#				  => "critcl::tsources".
	#		cheaders	- List. => "critcl::cheaders"
	#		csources	- List. => "critcl::csources"
	#		clibraries	- List. => "critcl::clibraries"
	#		cflags		- List. => "critcl::cflags", "critcl::framework",
	#					   "critcl::debug", "critcl::include"
	#		ldflags		- List. => "critcl::ldflags", "critcl::framework"
	#		initc		- String. Initialization code for Foo_Init(), "critcl::cinit"
	#		edecls		- String. Declarations of externals needed by Foo_Init(), "critcl::cinit"
	#		functions	- List. Collected function names.
	#		fragments	- List. Hashes of the collected C source bodies (functions, and unnamed code).
	#		block		- Dictionary. Maps the hashes to their C sources for fragments.
	#		defs		- List. Hashes of the collected C source bodies (only unnamed code), for extraction of defines.
	#		const		- Dictionary. Maps the names of defines to the namespace their variables will be in.
	#		uuid		- List. Strings used to generate the file's uuid/hash.
	#		mintcl		- String. Minimum version of Tcl required by the package.
	#		preload		- List. Names of all libraries to load
	#				  before the package library. This
	#				  information is used only by mode
	#				  'generate package'. This means that
	#				  packages with preload can't be used
	#				  in mode 'compile & run'.
	#		license		- String. License text.
	#		api_self	- String. Name of our API. Defaults to package name.
	#		api_hdrs	- List. Exported public headers of the API.
	#		api_ehdrs	- List. Exported external public headers of the API.
	#		api_fun		- List. Exported functions (signatures of result type, name, and arguments (C syntax))
	#		meta		- Dictionary. Arbitrary keys to values, the user meta-data for the package.
	#		package		- Dictionary. Keys, see below. System meta data for the package. Values are lists.
	#			name		- Name of current package
	#			version		- Version of same.
	#			description	- Long description.
	#			summary		- Short description (one line).
	#			subject		- Keywords and -phrases.
	#			as::build::date	- Date-stamp for the build.
	#
	# ---------------------------------------------------------------------
	#
	# <file>,failed -> Per-file information: Boolean. Build status. Failed or not.
	#
	# 'ccode'     -> Accumulated in-memory storage of code-fragments.
	#                Extended by 'ccode', used by 'BuildDefines',
	#                called by 'cbuild'. Apparently tries to extract defines
	#                and enums, and their values, for comparison with 'cdefine'd
	#		 values.
	#
	# NOTE: <file> are normalized absolute path names for exact
	#       identification of the relevant .tcl file.

	# _____________________________________________________________________
	# State used by "cbuild" ______________________________________________

	variable log     ""      ;# Log channel, opened to logfile.
	variable logfile ""      ;# Path of logfile. Accessed by
				  # "Log*" and "ExecWithLogging".
	variable failed  0       ;# Build status. Used by "Status*"
	variable err     ""	 ;# and "Exec*". Build error text.

	variable uuidcounter 0   ;# Counter for uuid generation in package mode.
	                         ;# md5 is bypassed when used.

	variable buildforpackage 0 ;# Boolean flag controlling
				    # cbuild's behaviour. Named after
				    # the mode 'generate package'.
				    # Auto-resets to OFF after each
				    # call of "cbuild". Can be activated
				    # by "buildforpackage".

	# _____________________________________________________________________
	# State used by "BeginCommand", "EndCommand", "Emit*" _________________

	variable curr	         ;# Hash of the last BeginCommand.
	variable block           ;# C code assembled by Emit* calls
				  # between Begin- and EndCommand.

	# _____________________________________________________________________

	variable compiling 0     ;# Boolean. Indicates that a C compiler
				  # (gcc, native, cl) is available.

	# _____________________________________________________________________
	# config variables
	variable configvars {
	    compile
	    debug_memory
	    debug_symbols
	    include
	    libinclude
	    ldoutput
	    embed_manifest
	    link
	    link_debug
	    link_preload
	    link_release
	    link_rpath
	    noassert
	    object
	    optimize
	    output
	    platform
	    preproc_define
	    preproc_enum
	    sharedlibext
	    strip
	    tclstubs
	    threadflags
	    tkstubs
	    version
	}
    }

    # namespace holding the compiler configuration (commands and
    # options for the various tasks, i.e. compilation, linking, etc.).
    namespace eval c {
	# See sibling file 'Config' for the detailed and full
	# information about the variables in use. configvars above, and
	# the code below list only the variables relevant to C. Keep this
	# information in sync with the contents of 'Config'.

	# compile         Command to compile a C source file to an object file
	# debug_memory    Compiler flags to enable memory debugging
	# debug_symbols   Compiler flags to add symbols to resulting library
	# include         Compiler flag to add an include directory
	# libinclude      Linker flag to add a library directory
	# ldoutput       - ? See 'Config'
	# link            Command to link one or more object files and create a shared library
	# embed_manifest  Command to embed a manifest into a DLL. (Win-specific)
	# link_debug     - ? See 'Config'
	# link_preload   Linker flags to use when dependent libraries are pre-loaded.
	# link_release   - ? See 'Config'
	# noassert        Compiler flag to turn off assertions in Tcl code
	# object          File extension for object files
	# optimize        Compiler flag to specify optimization level
	# output          Compiler flag to set output file, with argument $object => Use via [subst].
	# platform        Platform identification string (defaults to platform::generic)
	# preproc_define  Command to preprocess C source file (for critcl::cdefines)
	# preproc_enum    ditto
	# sharedlibext    The platform's file extension used for shared library files.
	# strip           Compiler flag to tell the linker to strip symbols
	# target          Presence of this key indicates that this is a cross-compile target
	# tclstubs        Compiler flag to set USE_TCL_STUBS
	# threadflags     Compiler flags to enable threaded build
	# tkstubs         Compiler flag to set USE_TK_STUBS
	# version         Command to print the compiler version number
    }
}

# # ## ### ##### ######## ############# #####################
## Export API

namespace eval ::critcl {
    namespace export \
	at cache ccode ccommand cdata cdefines cflags cheaders \
	check cinit clibraries compiled compiling config cproc \
	csources debug done failed framework ldflags platform \
	tk tsources preload license load tcl api userconfig meta \
	source include make
    # This is exported for critcl::app to pick up when generating the
    # dummy commands in the runtime support of a generated package.
    namespace export Ignore
    catch { namespace ensemble create }
}

# # ## ### ##### ######## ############# #####################
## Ready

::critcl::Initialize
return
