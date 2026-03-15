## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
# Pragmas for MetaData Scanner.
# n/a

# CriTcl Utility Package for en- and decoding an external enum.
# Based on i-assoc.
#
# Copyright (c) 2014-2023 Andreas Kupries <andreas_kupries@users.sourceforge.net>

package provide critcl::emap 1.3.1

# # ## ### ##### ######## ############# #####################
## Requirements.

package require Tcl    8.6 9   ; # Min supported version.
package require critcl 3.1.11  ; # make, include -- dict portability
package require critcl::iassoc

namespace eval ::critcl::emap {}

# # ## ### ##### ######## ############# #####################
## Implementation -- API: Embed C Code

proc critcl::emap::def {name dict args} {
    # dict: Tcl symbolic name -> (C int value (1))
    #
    # (Ad 1) Can be numeric, or symbolic, as long as it is a C int
    #        expression in the end.

    # args = options. Currently supported:
    # * -nocase : case-insensitive strings on encoding.
    # * -mode   : list of use cases, access case: tcl, c (default: tcl)

    Options $args
    Index $dict id symbols last
    # symbols :: list of words, lexicographically sorted
    # id   :: symbol -> index (sorted)
    # last :: number of symbols

    Header $name
    ConstStringTable $name $symbols $dict $nocase $last
    set isdirect [DecideIfDirect $dict min max direct]
    if {$isdirect} {
	DecodeDirect $name $min $max id direct
    }
    Tcl  Iassoc       $name $symbols $dict $nocase $last
    Tcl  EncoderTcl   $name                $nocase
    Tcl  DecoderTcl   $name $isdirect              $last
    List Decoder+List $name
    Tcl  ArgType      $name
    Tcl  ResultType   $name
    C    EncoderC     $name                $nocase $last
    C    DecoderC     $name $isdirect              $last
    return
}

# # ## ### ##### ######## ############# #####################
## Internals

proc critcl::emap::DecoderTcl {name isdirect last} {
    if {$isdirect} {
	DecoderTclDirect $name
    } else {
	DecoderTclSearch $name $last
    }
    return
}

proc critcl::emap::DecoderTclSearch {name last} {
    # Decoder based on linear search. Because we either
    # - see some symbolic values (= do not know actual value)
    # - the direct mapping table would be too large (> 50 entries).
    lappend map @NAME@  $name
    lappend map @UNAME@ [string toupper $name]
    lappend map @LAST@  $last

    critcl::ccode \n[critcl::at::here!][string map $map {
	Tcl_Obj*
	@NAME@_decode (Tcl_Interp* interp, int state)
	{
	    /* Decode via linear search */
	    char buf [20];
	    int i;
	    @NAME@_iassoc_data context = @NAME@_iassoc (interp);

	    for (i = 0; i < @LAST@; i++)  {
		if (@NAME@_emap_state [i] != state) continue;
		return context->tcl [i];
	    }

	    sprintf (buf, "%d", state);
	    Tcl_AppendResult (interp, "Invalid @NAME@ state code ", buf, NULL);
	    Tcl_SetErrorCode (interp, "@UNAME@", "STATE", NULL);
	    return NULL;
	}
    }]
    return
}

proc critcl::emap::DecodeDirect {name min max iv dv} {
    upvar 1 $iv id $dv direct
    # Decoder based on a direct mapping table. We can do this because
    # we found that all the values are pure integers, i.e. we know
    # them in detail, and that the table is not too big (< 50 entries).

    lassign [DirectTable $min $max id direct] table size

    lappend map @NAME@      $name
    lappend map @DIRECT@    $table
    lappend map @SIZE@      $size
    lappend map @MIN@       $min
    lappend map @MAX@       $max
    lappend map @OFFSET@    [Offset $min]

    critcl::ccode \n[critcl::at::here!][string map $map {
	static int @NAME@_direct (int state)
	{
	    static const int direct [@SIZE@] = {@DIRECT@
	    };
	    /* Check limits first */
	    if (state < @MIN@) { return -1; }
	    if (state > @MAX@) { return -1; }
	    /* Map to string index */
	    return direct [state@OFFSET@];
	}
    }]
}

proc critcl::emap::DecoderTclDirect {name} {
    lappend map @NAME@      $name
    lappend map @UNAME@     [string toupper $name]

    critcl::ccode \n[critcl::at::here!][string map $map {
	Tcl_Obj*
	@NAME@_decode (Tcl_Interp* interp, int state)
	{
	    /* Decode via direct mapping */
	    char buf [20];
	    int i;
	    @NAME@_iassoc_data context = @NAME@_iassoc (interp);

	    i = @NAME@_direct (state);
	    if (i < 0) { goto error; }

	    /* Return the chosen string */
	    return context->tcl [i];

	    error:
	    sprintf (buf, "%d", state);
	    Tcl_AppendResult (interp, "Invalid @NAME@ state code ", buf, NULL);
	    Tcl_SetErrorCode (interp, "@UNAME@", "STATE", NULL);
	    return NULL;
	}
    }]
    return
}

proc critcl::emap::Decoder+List {name} {
    lappend map @NAME@      $name
    lappend map @UNAME@     [string toupper $name]

    # Note on perf: O(mc), for m states in the definition, and c
    # states to convert. As the number of declared states is however
    # fixed, and small, we can say O(c) for some larger constant
    # factor.

    critcl::ccode \n[critcl::at::here!][string map $map {
	Tcl_Obj*
	@NAME@_decode_list (Tcl_Interp* interp, int c, int* state)
	{
	    int k;
	    Tcl_Obj* result = Tcl_NewListObj (0, 0);
	    /* Failed to create, abort immediately */
	    if (!result) {
		return result;
	    }
	    for (k=0; k < c; k++) {
		Tcl_Obj* lit = @NAME@_decode (interp, state[k]);
		if (lit && (TCL_OK == Tcl_ListObjAppendElement (interp, result, lit))) {
		    continue;
		}
		/* Failed to translate or append; release and abort */
		Tcl_DecrRefCount (result);
		return NULL;
	    }
	    return result;
	}
    }]
    return
}

proc critcl::emap::DirectTable {min max iv dv} {
    upvar 1 $iv id $dv direct

    set table {}
    set fmt   %[string length $max]d

    for {set i $min} {$i <= $max} {incr i} {
	if {[info exists direct($i)]} {
	    set sym [lindex $direct($i) 0]
	    set code $id($sym)
	    lappend table "$code,\t/* [format $fmt $i] <=> \"$sym\" */"
	} else {
	    lappend table "-1,"
	}
    }

    return [list "\n\t\t    [join $table "\n\t\t    "]" [llength $table]]
}

proc critcl::emap::Offset {min} {
    if {$min == 0} {
	return ""
    } elseif {$min < 0} {
	return "+[expr {0-$min}]"
    } else {
	# Note: The 0+... ensures that we get a decimal number.
	return "-[expr {0+$min}]"
    }
}

proc critcl::emap::DecideIfDirect {dict minv maxv dv} {
    upvar 1 $minv min $maxv max $dv direct

    set min  {}
    set max  {}

    dict for {sym value} $dict {
	# Manage a direct mapping table from stati to strings, if we
	# can see the numeric value of all stati.
	if {[string is integer -strict $value]} {
	    if {($min eq {}) || ($value < $min)} { set min $value }
	    if {($max eq {}) || ($value > $max)} { set max $value }
	    lappend direct($value) $sym
	} else {
	    return 0
	}
    }

    if {$min eq {}}        { return 0 }
    if {$max eq {}}        { return 0 }
    if {($max-$min) >= 50} { return 0 }
    return 1
}

proc critcl::emap::EncoderTcl {name nocase} {
    if {$nocase} {
	EncoderTclNocase $name
    } else {
	EncoderTclPlain $name
    }
    return
}

proc critcl::emap::EncoderTclPlain {name} {
    lappend map @NAME@ $name
    lappend map @UNAME@ [string toupper $name]

    critcl::ccode \n[critcl::at::here!][string map $map {
	int
	@NAME@_encode (Tcl_Interp* interp,
		       Tcl_Obj*    state,
		       int*        result)
	{
	    int id, res;
	    res = Tcl_GetIndexFromObj (interp, state, @NAME@_emap_cstr, "@NAME@", 0, &id);
	    if (res != TCL_OK) {
		Tcl_SetErrorCode (interp, "@UNAME@", "STATE", NULL);
		return TCL_ERROR;
	    }

	    *result = @NAME@_emap_state [id];
	    return TCL_OK;
	}
    }]
    return
}

proc critcl::emap::EncoderTclNocase {name} {
    lappend map @NAME@ $name
    lappend map @UNAME@ [string toupper $name]

    critcl::ccode \n[critcl::at::here!][string map $map {
	int
	@NAME@_encode (Tcl_Interp* interp,
		       Tcl_Obj*    state,
		       int*        result)
	{
	    int id, res;
	    /* -nocase :: We duplicate the state string, making it unshared,
	     * allowing us to convert in place. As the string may change
	     * length (shrinking) we have to reset the length after
	     * conversion.
	     */
	    state = Tcl_DuplicateObj (state);
	    Tcl_SetObjLength(state, Tcl_UtfToLower (Tcl_GetString (state))); /* OK tcl9 */
	    res = Tcl_GetIndexFromObj (interp, state, @NAME@_emap_cstr, "@NAME@", 0, &id);
	    Tcl_DecrRefCount (state);
	    if (res != TCL_OK) {
		Tcl_SetErrorCode (interp, "@UNAME@", "STATE", NULL);
		return TCL_ERROR;
	    }

	    *result = @NAME@_emap_state [id];
	    return TCL_OK;
	}
    }]
    return
}

proc critcl::emap::EncoderC {name nocase last} {
    if {$nocase} {
	EncoderCNocase $name $last
    } else {
	EncoderCPlain $name $last
    }
    return
}

proc critcl::emap::EncoderCPlain {name last} {
    lappend map @NAME@ $name
    lappend map @UNAME@ [string toupper $name]
    lappend map @LAST@  $last

    # case-sensitive search
    critcl::ccode \n[critcl::at::here!][string map $map {
	#include <string.h>

	int
	@NAME@_encode_cstr (const char* state)
	{
	    int id;
	    /* explicit linear search */
	    for (id = 0; id < @LAST@; id++)  {
		if (strcmp (state, @NAME@_emap_cstr [id]) != 0) continue;
		return @NAME@_emap_state [id];
	    }
	    return -1;
	}
    }]
    return
}

proc critcl::emap::EncoderCNocase {name last} {
    lappend map @NAME@ $name
    lappend map @UNAME@ [string toupper $name]
    lappend map @LAST@  $last

    # case-insensitive search
    critcl::ccode \n[critcl::at::here!][string map $map {
	#include <string.h>

	int
	@NAME@_encode_cstr (const char* state)
	{
	    /* -nocase :: We duplicate the state string, allowing us to
	     * convert in place. As the string may change length (shrink)
	     * we have to re-terminate it after conversion.
	     */
	    int id, slen = 1 + strlen (state);
	    char* lower = ckalloc (slen);

	    memcpy (lower, state, slen);
	    lower [Tcl_UtfToLower (lower)] = '\0';

	    /* explicit linear search */
	    for (id = 0; id < @LAST@; id++)  {
		if (strcmp (lower, @NAME@_emap_cstr [id]) != 0) continue;
		ckfree ((char*) lower);
		return @NAME@_emap_state [id];
	    }
	    ckfree ((char*) lower);
	    return -1;
	}
    }]
    return
}

proc critcl::emap::DecoderC {name isdirect last} {
    if {$isdirect} {
	DecoderCDirect $name
    } else {
	DecoderCSearch $name $last
    }
    return
}

proc critcl::emap::DecoderCSearch {name last} {
    # Decoder based on linear search. Because we either
    # - see some symbolic values (= do not know actual value)
    # - the direct mapping table would be too large (> 50 entries).
    lappend map @NAME@  $name
    lappend map @UNAME@ [string toupper $name]
    lappend map @LAST@  $last

    critcl::ccode \n[critcl::at::here!][string map $map {
	const char*
	@NAME@_decode_cstr (int state)
	{
	    /* Decode via linear search */
	    int id;
	    for (id = 0; id < @LAST@; id++)  {
		if (@NAME@_emap_state [id] != state) continue;
		return @NAME@_emap_cstr [id];
	    }
	    return NULL;
	}
    }]
    return
}

proc critcl::emap::DecoderCDirect {name} {
    lappend map @NAME@      $name
    lappend map @UNAME@     [string toupper $name]

    critcl::ccode \n[critcl::at::here!][string map $map {
	const char*
	@NAME@_decode_cstr (int state)
	{
	    /* Decode via direct mapping */
	    int i = @NAME@_direct (state);
	    if (i < 0) { return NULL; }
	    /* Return the chosen string */
	    return @NAME@_emap_cstr [i];
	}
    }]
    return
}

proc critcl::emap::ResultType {name} {
    lappend map @NAME@ $name
    critcl::resulttype $name \n[critcl::at::here!][string map $map {
	/* @NAME@_decode result is 0-refcount */
	{ Tcl_Obj* ro = @NAME@_decode (interp, rv);
	if (ro == NULL) { return TCL_ERROR; }
	Tcl_SetObjResult (interp, ro);
	return TCL_OK; }
    }] int
    return
}

proc critcl::emap::ArgType {name} {
    lappend map @NAME@ $name
    critcl::argtype $name \n[critcl::at::here!][string map $map {
	if (@NAME@_encode (interp, @@, &@A) != TCL_OK) return TCL_ERROR;
    }] int int
    return
}

proc critcl::emap::Header {name} {
    # I. Generate a header file for inclusion by other parts of the
    #    package, i.e. csources. Include the header here as well, for
    #    the following blocks of code.
    #
    #    Declaration of the en- and decoder functions.
    upvar 1 mode mode
    append h [HeaderIntro      $name]
    append h [Tcl  HeaderTcl   $name]
    append h [List Header+List $name]
    append h [C    HeaderC     $name]
    append h [HeaderEnd        $name]
    critcl::include [critcl::make ${name}.h $h]
    return
}

proc critcl::emap::HeaderIntro {name} {
    lappend map @NAME@  $name
    return \n[critcl::at::here!][string map $map {
	#ifndef @NAME@_EMAP_HEADER
	#define @NAME@_EMAP_HEADER

	#include <tcl.h>
    }]
}

proc critcl::emap::HeaderEnd {name} {
    lappend map @NAME@ $name
    return [string map $map {
	#endif /* @NAME@_EMAP_HEADER */
    }]
}

proc critcl::emap::HeaderTcl {name} {
    lappend map @NAME@ $name
    return \n[critcl::at::here!][string map $map {
	/* "tcl"
	 * Encode a Tcl string into the corresponding state code
	 * Decode a state into the corresponding Tcl string
	 */
	extern int      @NAME@_encode (Tcl_Interp* interp, Tcl_Obj* state, int* result);
	extern Tcl_Obj* @NAME@_decode (Tcl_Interp* interp, int state);
    }]
}

proc critcl::emap::Header+List {name} {
    lappend map @NAME@ $name
    return \n[critcl::at::here!][string map $map {
	/* "+list"
	 * Decode a set of states into a list of the corresponding Tcl strings
	 */
	extern Tcl_Obj* @NAME@_decode_list (Tcl_Interp* interp, int c, int* state);
    }]
}

proc critcl::emap::HeaderC {name} {
    lappend map @NAME@ $name
    return \n[critcl::at::here!][string map $map {
	/* "c"
	 * Encode a C string into the corresponding state code
	 * Decode a state into the corresponding C string
	 */
	extern int         @NAME@_encode_cstr (const char* state);
	extern const char* @NAME@_decode_cstr (int state);
    }]
}

proc critcl::emap::Iassoc {name symbols dict nocase last} {
    upvar 1 mode mode
    critcl::iassoc def ${name}_iassoc {} \
	[IassocStructure $last] \
	[IassocInit  $name $symbols $dict $nocase $last] \
	[IassocFinal       $symbols $dict]
    return
}

proc critcl::emap::IassocStructure {last} {
    lappend map @LAST@ $last
    return \n[critcl::at::here!][string map $map {
	Tcl_Obj* tcl [@LAST@]; /* State name, Tcl_Obj*, sharable */
    }]
}

proc critcl::emap::IassocInit {name symbols dict nocase last} {
    set id -1
    foreach sym $symbols {
	set value [dict get $dict $sym]
	incr id
	if {$nocase} { set sym [string tolower $sym] }
	set map [list @ID@ $id @SYM@ $sym @VALUE@ $value @NAME@ $name]

	# iassoc initialization, direct from string, no C level
	append init \n[critcl::at::here!][string map $map {
	    data->tcl [@ID@] = Tcl_NewStringObj (@NAME@_emap_cstr[@ID@], -1);
	    Tcl_IncrRefCount (data->tcl [@ID@]);
	}]
    }
    return $init
}

proc critcl::emap::IassocFinal {symbols dict} {
    set id -1
    foreach sym $symbols {
	incr id
	set map [list @ID@ $id]
	append final \n[critcl::at::here!][string map $map {
	    Tcl_DecrRefCount (data->tcl [@ID@]);
	}]
    }
    return $final
}

proc critcl::emap::ConstStringTable {name symbols dict nocase last} {
    # C level table initialization (constant data)
    foreach sym $symbols {
	set value [dict get $dict $sym]
	if {$nocase} { set sym [string tolower $sym] }
	append ctable "\n\t    \"${sym}\","
	append stable "\n\t    ${value},"
    }
    append ctable "\n\t    0"
    set stable [string trimright $stable ,]

    lappend map @NAME@    $name
    lappend map @STRINGS@ $ctable
    lappend map @STATES@  $stable
    lappend map @LAST@    $last

    critcl::ccode [critcl::at::here!][string map $map {
	/* State names, C string */
	static const char* @NAME@_emap_cstr [@LAST@+1] = {@STRINGS@
	};

	/* State codes */
	static int @NAME@_emap_state [@LAST@] = {@STATES@
	};
    }]
    return
}

proc critcl::emap::C {args} {
    upvar 1 mode mode
    if {!$mode(c)} return
    return [uplevel 1 $args]
}

proc critcl::emap::!C {args} {
    upvar 1 mode mode
    if {$mode(c)} return
    return [uplevel 1 $args]
}

proc critcl::emap::Tcl {args} {
    upvar 1 mode mode
    if {!$mode(tcl)} return
    return [uplevel 1 $args]
}

proc critcl::emap::!Tcl {args} {
    upvar 1 mode mode
    if {$mode(tcl)} return
    return [uplevel 1 $args]
}

proc critcl::emap::List {args} {
    upvar 1 mode mode
    if {!$mode(+list)} return
    return [uplevel 1 $args]
}

proc critcl::emap::!List {args} {
    upvar 1 mode mode
    if {$mode(+list)} return
    return [uplevel 1 $args]
}

proc critcl::emap::Index {dict iv sv lv} {
    upvar 1 $iv id $sv symbols $lv last
    # For the C level search we want lexicographically sorted elements
    set symbols [lsort -dict [dict keys $dict]]
    set i 0
    foreach s $symbols {
	set id($s) $i
	incr i
    }
    set last $i
    # id :: symbol -> index (sorted)
    return
}

proc critcl::emap::Options {options} {
    upvar 1 nocase nocase mode mode
    set nocase 0
    set use    tcl

    while {[llength $options]} {
	set options [lassign $options o]
	switch -glob -- $o {
	    -nocase -
	    -nocas -
	    -noca -
	    -noc -
	    -no -
	    -n { set nocase 1 }
	    -mode -
	    -mod -
	    -mo -
	    -m { set options [lassign $options use] }
	    -* -
	    default {
		return -code error -errorcode {CRITCL EMAP INVALID-OPTION} \
		    "Expected option -nocase, or -use, got \"$o\""
	    }
	}
    }
    Use $use
    return
}

proc critcl::emap::Use {use} {
    # Use cases: tcl, c, both
    upvar 1 mode mode
    set uses 0
    foreach u {c tcl +list} { set mode($u) 0 }
    foreach u $use          { set mode($u) 1 ; incr uses }
    if {$mode(+list)} { set mode(tcl) 1 }
    if {$uses} return
    return -code error "Need at least one use case (c, tcl, or +list)"
}

# # ## ### ##### ######## ############# #####################
## Export API

namespace eval ::critcl::emap {
    namespace export def
    catch { namespace ensemble create }
}

namespace eval ::critcl {
    namespace export emap
    catch { namespace ensemble create }
}

# # ## ### ##### ######## ############# #####################
## Ready
return
