## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
# Pragmas for MetaData Scanner.
# @mdgen OWNER: class.h

# CriTcl Utility Commands. Specification of a command representing a
# class made easy, with code for object command and method dispatch
# generated.

package provide critcl::class 1.2.1

# # ## ### ##### ######## ############# #####################
## Requirements.

package require Tcl    8.6 9  ; # Min supported version.
package require critcl 3.1.17 ; # Need 'meta?' to get the package name.
                                # Need 'name2c' returning 4 values.
                                # Need 'Deline' helper.
                                # Need cproc -tracename
package require critcl::util  ; # Use the package's Get/Put commands.

namespace eval ::critcl::class {}

# # ## ### ##### ######## ############# #####################
## API: Generate the declaration and implementation files for the class.

proc ::critcl::class::define {classname script} {
    variable state

    # Structure of the specification database
    #
    # TODO: Separate the spec::Process results from the template placeholders.
    # TODO: Explain the various keys
    #
    # NOTE: All toplevel keys go into the map
    #       used to configure the template file (class.h).
    #       See `GenerateCode` and `MakeMap`.
    #
    #       The various `Process*` procedures are responsible
    #       for converting the base specification delivered by
    #       `spec::Process` into the placeholders expected by
    #       template
    ##
    # state = dict <<
    #   tcl-api      -> bool
    #   c-api        -> bool
    #   capiprefix   -> string
    #   buildflags   -> string
    #   classmgrstruct -> string
    #   classmgrsetup  -> string
    #   classmgrnin    -> string
    #   classcommand   -> string
    #   tclconscmd     -> string
    #   package      -> string
    #   class        -> string
    #   stem         -> string
    #   classtype    -> string (C type class structure)
    #   (class)method       -> dict <<
    #     names   -> list (string)
    #     def -> (name) -> <<
    #       enum
    #       case
    #       code
    #       syntax
    #     >>
    #     typedef -> ^instancetype
    #     menum   ->
    #     typekey ->
    #     prefix  -> ''|'class_' (see *1*)
    #     startn  ->
    #     starte  ->
    #   >>
    #   (class)variable     -> dict <<
    #     names   -> list (string)
    #     def     -> (name) -> <<
    #       ctype   ->
    #       loc     ->
    #       comment ->
    #     >>
    #   >>
    #   stop         -> bool|presence
    #   includes     -> string (C code fragment)
    #   include      ->
    #   instancetype ->
    #   ivardecl     -> string (C code fragment)
    #   ivarrelease  -> string (C code fragment)
    #   ivarerror    -> string (C code fragment)
    #   itypedecl    -> string (C code fragment, instance type)
    #   ctypedecl    -> string (C code fragment, class type)
    # *1*, (class_)method.prefix use
    #   (class_)method_names
    #   (class_)method_enumeration
    #   (class_)method_dispatch
    #   (class_)method_implementations
    # >>

    catch { unset state }

    # Arguments:
    # - name of the Tcl command representing the class.
    #   May contain namespace qualifiers. Represented by a ccommand.
    # - script specifying the state structure and methods.

    #puts "=== |$classname|"
    #puts "--- $script"

    # Pull the package we are working on out of the system.

    set package [critcl::meta? name]
    set qpackage [expr {[string match ::* $package]
			? "$package"
			: "::$package"}]
    lassign [uplevel 1 [list ::critcl::name2c $classname]] ns  cns  classname cclassname
    lassign [uplevel 1 [list ::critcl::name2c $qpackage]]  pns pcns package   cpackage

    #puts "%%% pNS  |$pns|"
    #puts "%%% Pkg  |$package|"
    #puts "%%% pCNS |$pcns|"
    #puts "%%% cPkg |$cpackage|"

    #puts "%%% NS    |$ns|"
    #puts "%%% CName |$classname|"
    #puts "%%% CNS   |$cns|"
    #puts "%%% CCName|$cclassname|"

    set stem ${pcns}${cpackage}_$cns$cclassname

    dict set state tcl-api      1
    dict set state c-api        0
    dict set state capiprefix   $cns$cclassname
    dict set state package      $pns$package
    dict set state class        $ns$classname
    dict set state stem         $stem
    dict set state classtype    ${stem}_CLASS
    dict set state method      names {}
    dict set state classmethod names {}

    # Check if the 'info frame' information for 'script' passes through properly.
    spec::Process $script

    #puts "@@@ <<$state>>"

    ProcessFlags
    ProcessIncludes
    ProcessExternalType
    ProcessInstanceVariables
    ProcessClassVariables

    ProcessMethods method
    ProcessMethods classmethod

    ProcessFragment classconstructor "\{\n" " " "\}"
    ProcessFragment classdestructor  "\{\n" " " "\}"
    ProcessFragment constructor      "\{\n" " " "\}"
    ProcessFragment postconstructor  "\{\n" " " "\}"
    ProcessFragment destructor       "\{\n" " " "\}"
    ProcessFragment support          "" \n ""

    GenerateCode

    unset state
    return
}

proc ::critcl::class::ProcessFlags {} {
    variable state
    set flags {}
    foreach key {tcl-api c-api} {
	if {![dict get $state $key]} continue
	lappend flags $key
    }
    if {![llength $flags]} {
	return -code error "No APIs to generate found. Please activate at least one API."
    }

    dict set state buildflags [join $flags {, }]
    critcl::msg "\n\tClass flags:     $flags"
    return
}

proc ::critcl::class::ProcessIncludes {} {
    variable state
    if {[dict exists $state include]} {
	ProcessFragment include "#include <" "\n" ">"
	dict set state includes [dict get $state include]
	dict unset state include
    } else {
	dict set state includes {/* No inclusions */}
    }
    return
}

proc ::critcl::class::ProcessExternalType {} {
    variable state
    if {![dict exists $state instancetype]} return

    # Handle external C type for instances.
    set itype [dict get $state instancetype]
    dict set state ivardecl    "    $itype instance"
    dict set state ivarrelease ""
    dict set state ivarerror   "error:\n    return NULL;"
    dict set state itypedecl   "/* External type for instance state: $itype */"

    # For ProcessMethods
    dict set state method typedef $itype
    return
}

proc ::critcl::class::ProcessInstanceVariables {} {
    variable state

    if {![dict exists $state variable]} {
	if {![dict exists $state instancetype]} {
	    # We have neither external type, nor instance variables.
	    # Fake ourselves out, recurse.
	    dict set state variable names {}
	    ProcessInstanceVariables itype
	    return
	}

	# For ProcessMethods
	dict set state method menum   M_EMPTY
	dict set state method typekey @instancetype@
	dict set state method prefix  {}
	dict set state method startn  {}
	dict set state method starte  {}
	return
    }

    # Convert the set of instance variables (which can be empty) into
    # a C instance structure type declaration, plus variable name.

    set itype [dict get $state stem]_INSTANCE

    set decl {}
    lappend decl "typedef struct ${itype}__ \{"

    foreach fname [dict get $state variable names] {
	set ctype   [dict get $state variable def $fname ctype]
	set vloc    [dict get $state variable def $fname loc]
	set comment [dict get $state variable def $fname comment]

	set field "$vloc    $ctype $fname;"
	if {$comment ne {}} {
	    append field " /* $comment */"
	}
	lappend decl $field
    }

    lappend decl "\} ${itype}__;"
    lappend decl "typedef struct ${itype}__* $itype;"

    dict set state instancetype $itype
    dict set state ivardecl    "    $itype instance = ($itype) ckalloc (sizeof (${itype}__))"
    dict set state ivarerror   "error:\n    ckfree ((char*) instance);\n    return NULL;"
    dict set state ivarrelease "    ckfree ((char*) instance)"
    dict set state itypedecl   [join $decl \n]

    # For ProcessMethods
    dict set state method typedef $itype
    dict set state method menum   M_EMPTY
    dict set state method typekey @instancetype@
    dict set state method prefix  {}
    dict set state method startn  {}
    dict set state method starte  {}
    return
}

proc ::critcl::class::ProcessClassVariables {} {
    variable state

    # For ProcessMethods
    dict set state classmethod typedef [dict get $state classtype]
    dict set state classmethod menum   {}
    dict set state classmethod typekey @classtype@
    dict set state classmethod prefix  class_
    dict set state classmethod startn  "\n"
    dict set state classmethod starte  ",\n"
    dict set state ctypedecl {}

    dict set state capiclassvaraccess {}

    if {![dict exists $state classvariable]} {
	# Some compilers are unable to handle a structure without
	# members (notably ANSI C89 Solaris, AIX). Taking the easy way
	# out here, adding a dummy element. A more complex solution
	# would be to ifdef the empty structure out of the system.

	dict set state ctypedecl {int __dummy__;}
	return
    }

    # Convert class variables  into class type field declarations.

    set decl {}
    lappend decl "/* # # ## ### ##### ######## User: Class variables */"

    if {[dict get $state c-api]} {
	lappend acc  "/* # # ## ### ##### ######## User: C-API :: Class variable accessors */\n"
    }

    foreach fname [dict get $state classvariable names] {
	set ctype   [dict get $state classvariable def $fname ctype]
	set vloc    [dict get $state classvariable def $fname loc]
	set comment [dict get $state classvariable def $fname comment]

	set field "$vloc$ctype $fname;"
	if {$comment ne {}} {
	    append field " /* $comment */"
	}
	lappend decl $field

	# If needed, generate accessor functions for all class variables,
	# i.e setters and getters.

	if {[dict get $state c-api]} {
	    lappend acc "$ctype @capiprefix@_${fname}_get (Tcl_Interp* interp) \{"
	    lappend acc "    return @stem@_Class (interp)->user.$fname;"
	    lappend acc "\}"
	    lappend acc ""
	    lappend acc "void @capiprefix@_${fname}_set (Tcl_Interp* interp, $ctype v) \{"
	    lappend acc "    @stem@_Class (interp)->user.$fname = v;"
	    lappend acc "\}"
	}
    }

    lappend decl "/* # # ## ### ##### ######## */"

    dict set state ctypedecl "    [join $decl "\n    "]\n"

    if {[dict get $state c-api]} {
	dict set state capiclassvaraccess [join $acc \n]
    }
    return
}

proc ::critcl::class::Max {v s} {
    upvar 1 $v max
    set l [string length $s]
    if {$l < $max} return
    set max $l
    return
}

proc ::critcl::class::ProcessMethods {key} {
    variable state
    # Process method declarations. Ensure that the names are listed in
    # alphabetical order, to be nice.

    # From Process(Instance|Class)Variables
    set pfx  [dict get $state $key prefix]
    set stn  [dict get $state $key startn]
    set ste  [dict get $state $key starte]

    if {[dict exists $state $key names] &&
	[llength [dict get $state $key names]]} {
	set map [list @stem@ [dict get $state stem] \
		     [dict get $state $key typekey] \
		     [dict get $state $key typedef]]

	set maxe 0
	set maxn 0
	foreach name [lsort -dict [dict get $state $key names]] {
	    Max maxn $name
	    Max maxe [dict get $state $key def $name enum]
	}
	incr maxn 3

	foreach name [lsort -dict [dict get $state $key names]] {
	    set enum   [string map $map [dict get $state $key def $name enum]]
	    set case   [string map $map [dict get $state $key def $name case]]
	    set code   [string map $map [dict get $state $key def $name code]]
	    set syntax [string map $map [dict get $state $key def $name syntax]]

	    lappend names "[format %-${maxn}s \"$name\",] $syntax"
	    lappend enums "[format %-${maxe}s $enum] $syntax"
	    regexp {(:.*)$} $case tail
	    set case "case [format %-${maxe}s $enum]$tail"
	    lappend cases $case
	    lappend codes $code
	}

	dict set state ${pfx}method_names           "${stn}    [join $names  "\n    "]"
	dict set state ${pfx}method_enumeration     "${ste}    [join $enums ",\n    "]"
	dict set state ${pfx}method_dispatch        "${stn}\t[join $cases \n\t]"
	dict set state ${pfx}method_implementations [join $codes \n\n]
    } else {
	set enums [dict get $state $key menum]
	if {[llength $enums]} {
	    set enums "${ste}    [join $enums ",\n    "]"
	}

	dict set state ${pfx}method_names           {}
	dict set state ${pfx}method_enumeration     $enums
	dict set state ${pfx}method_dispatch        {}
	dict set state ${pfx}method_implementations {}
    }


    dict unset state $key
    return
}

proc ::critcl::class::ProcessFragment {key prefix sep suffix} {
    # Process code fragments into a single block, if any.
    # Ensure it exists, even if empty. Required by template.
    # Optional in specification.

    variable state
    if {![dict exists $state $key]} {
	set new {}
    } else {
	set new ${prefix}[join [dict get $state $key] $suffix$sep$prefix]$suffix
    }
    dict set state $key $new
    return
}

proc ::critcl::class::GenerateCode {} {
    variable state

    set stem     [dict get $state stem]
    set class    [dict get $state class]
    set hdr      ${stem}_class.h
    set header   [file join [critcl::cache] $hdr]

    file mkdir [critcl::cache]
    set template [critcl::Deline [Template class.h]]
    #puts T=[string length $template]

    # Note, the template file is many files/parts, separated by ^Z
    lassign [split $template \x1a] \
	template mgrstruct mgrsetup newinsname classcmd tclconscmd \
	cconscmd

    # Configure the flag-dependent parts of the template

    if {[dict get $state tcl-api]} {
	dict set state classmgrstruct $mgrstruct
	dict set state classmgrsetup  $mgrsetup
	dict set state classmgrnin    $newinsname
	dict set state classcommand   $classcmd
	dict set state tclconscmd     $tclconscmd
    } else {
	dict set state classmgrstruct {}
	dict set state classmgrsetup  {}
	dict set state classmgrnin    {}
	dict set state classcommand   {}
	dict set state tclconscmd     {}
    }

    if {[dict get $state c-api]} {
	dict set state cconscmd     $cconscmd
    } else {
	dict set state cconscmd     {}
    }

    critcl::util::Put $header [string map [MakeMap] $template]

    critcl::ccode "#include <$hdr>"
    if {[dict get $state tcl-api]} {
	uplevel 2 [list critcl::ccommand $class ${stem}_ClassCommand]
    }
    return
}

proc ::critcl::class::MakeMap {} {
    variable state

    # First set of substitutions.
    set premap {}
    dict for {k v} $state {
	lappend premap @${k}@ $v
    }

    # Resolve the substitutions used in the fragments of code to
    # generate the final map.
    set map {}
    foreach {k v} $premap {
	lappend map $k [string map $premap $v]
    }

    return $map
}

proc ::critcl::class::Template {path} {
    variable selfdir
    set path $selfdir/$path
    critcl::msg "\tClass templates: $path"
    return [Get $path]
}

proc ::critcl::class::Get {path} {
    if {[catch {
	set c [open $path r]
	fconfigure $c -eofchar {}
	set d [read $c]
	close $c
    }]} {
	set d {}
    }
    return $d
}

proc ::critcl::class::Dedent {pfx text} {
    set result {}
    foreach l [split $text \n] {
	lappend result [regsub ^$pfx $l {}]
    }
    join $result \n
}

# # ## ### ##### ######## ############# #####################
##
# Internal: All the helper commands providing access to the system
# state to the specification commands (see next section)
##
# # ## ### ##### ######## ############# #####################

proc ::critcl::class::CAPIPrefix {name} {
    variable state
    dict set state capiprefix $name
    return
}

proc ::critcl::class::Flag {key flag} {
    critcl::msg " ($key = $flag)"
    variable state
    dict set state $key $flag
    return
}

proc ::critcl::class::Include {header} {
    # Name of an API to include in the generated code.
    variable state
    dict lappend state include $header
    return
}

proc ::critcl::class::ExternalType {name} {
    # Declaration of the C type to use for the object state.  This
    # type is expected to be declared externally. It allows us to use
    # a 3rd party structure directly. Cannot be specified if instance
    # and/or class variables for our own structures have been declared
    # already.

    variable state

    if {[dict exists $state variable]} {
	return -code error "Invalid external instance type. Instance variables already declared."
    }
    if {[dict exists $state classvariable]} {
	return -code error "Invalid external instance type. Class variables already declared."
    }

    dict set state instancetype $name
    return
}

proc ::critcl::class::Variable {ctype name comment vloc} {
    # Declaration of an instance variable. In other words, a field in
    # the C structure for instances. Cannot be specified if an
    # external "type" has been specified already.

    variable state

    if {[dict exists $state instancetype]} {
	return -code error \
	    "Invalid instance variable. External instance type already declared."
    }

    if {[dict exists $state variable def $name]} {
	return -code error "Duplicate definition of instance variable \"$name\""
    }

    # Create the automatic instance variable to hold the instance
    # command token.

    if {![dict exists $state stop] &&
	(![dict exists $state variable] ||
	 ![llength [dict get $state variable names]])
    } {
	# To make it easier on us we reuse the existing definition
	# commands to set everything up. To avoid infinite recursion
	# we set a flag stopping us from re-entering this block.

	dict set state stop 1
	critcl::at::here ; Variable Tcl_Command cmd {
	    Automatically generated. Holds the token for the instance command,
	    for use by the automatically created destroy method.
	} [critcl::at::get]
	dict unset state stop

	PostConstructor "[critcl::at::here!]\tinstance->cmd = cmd;\n"

	# And the destroy method using the above instance variable.
	critcl::at::here ; MethodExplicit destroy proc {} void {
	    Tcl_DeleteCommandFromToken(interp, instance->cmd);
	}
    }

    dict update state variable f {
	dict lappend f names $name
    }
    dict set state variable def $name ctype   $ctype
    dict set state variable def $name loc     $vloc
    dict set state variable def $name comment [string trim $comment]
    return
}

proc ::critcl::class::ClassVariable {ctype name comment vloc} {
    # Declaration of a class variable. In other words, a field in the
    # C structure for the class. Cannot be specified if a an external
    # "type" has been specified already.

    variable state

    if {[dict exists $state instancetype]} {
	return -code error \
	    "Invalid class variable. External instance type already declared."
    }

    if {[dict exists $state classvariable def $name]} {
	return -code error "Duplicate definition of class variable \"$name\""
    }

    dict update state classvariable c {
	dict lappend c names $name
    }
    dict set state classvariable def $name ctype   $ctype
    dict set state classvariable def $name loc     $vloc
    dict set state classvariable def $name comment [string trim $comment]

    if {[llength [dict get $state classvariable names]] == 1} {
	# On declaration of the first class variable we declare an
	# instance variable which provides the instances with a
	# reference to their class (structure).
	critcl::at::here ; Variable @classtype@ class {
	    Automatically generated. Reference to the class (variables)
	    from the instance.
	} [critcl::at::get]
	Constructor "[critcl::at::here!]\tinstance->class = class;\n"
    }
    return
}

proc ::critcl::class::Constructor {code} {
    CodeFragment constructor $code
    return
}

proc ::critcl::class::PostConstructor {code} {
    CodeFragment postconstructor $code
    return
}

proc ::critcl::class::Destructor {code} {
    CodeFragment destructor $code
    return
}

proc ::critcl::class::ClassConstructor {code} {
    CodeFragment classconstructor $code
    return
}

proc ::critcl::class::ClassDestructor {code} {
    CodeFragment classdestructor $code
    return
 }

proc ::critcl::class::Support {code} {
    CodeFragment support $code
    return
}

proc ::critcl::class::MethodExternal {name function details} {
    MethodCheck method instance $name

    set map {}
    if {[llength $details]} {
	set  details [join $details {, }]
	lappend map objv "objv, $details"
	set details " ($details)"
    }

    MethodDef method instance $name [MethodEnum method $name] {} $function $map \
	"/* $name : External function @function@$details */"
    return
}

proc ::critcl::class::MethodExplicit {name mtype arguments args} {
    # mtype in {proc, command}
    MethodCheck method instance $name
    variable state

    set bloc     [critcl::at::get]
    set enum     [MethodEnum method $name]
    set function ${enum}_Cmd
    set cdimport "[critcl::at::here!]    @instancetype@ instance = (@instancetype@) clientdata;"
    set tname    "[dict get $state class] M  $name"

    if {$mtype eq "proc"} {
	# Method is cproc.
	# |args| == 2, args => rtype, body
	# arguments is (argtype argname...)
	# (See critcl::cproc for full details)

	# Force availability of the interp in methods.
	if {[lindex $arguments 0] ne "Tcl_Interp*"} {
	    set arguments [linsert $arguments 0 Tcl_Interp* interp]
	}

	lassign $args rtype body

	set body   $bloc[string trimright $body]
	set cargs  [critcl::argnames $arguments]
	if {[llength $cargs]} { set cargs " $cargs" }
	set syntax "/* Syntax: <instance> $name$cargs */"
	set body   "\n    $syntax\n$cdimport\n    $body"

	set code [critcl::collect {
	    critcl::cproc $function $arguments $rtype $body \
		-cname 1 -pass-cdata 1 -arg-offset 1 -tracename $tname
	}]

    } else {
	# Method is ccommand.
	# |args| == 1, args => body
	lassign $args body

	if {$arguments ne {}} {set arguments " cmd<<$arguments>>"}
	set body   $bloc[string trimright $body]
	set syntax "/* Syntax: <instance> $name$arguments */"
	set body   "\n    $syntax\n$cdimport\n    $body"

	set code [critcl::collect {
	    critcl::ccommand $function {} $body \
		-cname 1 -tracename $tname
	}]
    }

    MethodDef method instance $name $enum $syntax $function {} $code
    return
}

proc ::critcl::class::ClassMethodExternal {name function details} {
    MethodCheck classmethod class $name

    set map {}
    if {[llength $details]} {
	lappend map objv "objv, [join $details {, }]"
    }

    MethodDef classmethod "&classmgr->user" $name [MethodEnum classmethod $name] {} $function $map \
	"/* $name : External function @function@ */"
    return
}

proc ::critcl::class::ClassMethodExplicit {name mtype arguments args} {
    # mtype in {proc, command}
    MethodCheck classmethod class $name
    variable state

    set bloc     [critcl::at::get]
    set enum     [MethodEnum classmethod $name]
    set function ${enum}_Cmd
    set cdimport "[critcl::at::here!]    @classtype@ class = (@classtype@) clientdata;"
    set tname    "[dict get $state class] CM $name"

    if {$mtype eq "proc"} {
	# Method is cproc.
	# |args| == 2, args => rtype, body
	# arguments is (argtype argname...)
	# (See critcl::cproc for full details)

	# Force availability of the interp in methods.
	if {[lindex $arguments 0] ne "Tcl_Interp*"} {
	    set arguments [linsert $arguments 0 Tcl_Interp* interp]
	}

	lassign $args rtype body

	set body   $bloc[string trimright $body]
	set cargs  [critcl::argnames $arguments]
	if {[llength $cargs]} { set cargs " $cargs" }
	set syntax "/* Syntax: <class> $name$cargs */"
	set body   "\n    $syntax\n$cdimport\n    $body"

	set code [critcl::collect {
	    critcl::cproc $function $arguments $rtype $body \
		-cname 1 -pass-cdata 1 -arg-offset 1 \
		-tracename $tname
	}]

    } else {
	# Method is ccommand.
	# |args| == 1, args => body
	lassign $args body

	if {$arguments ne {}} {set arguments " cmd<<$arguments>>"}
	set body   $bloc[string trimright $body]
	set syntax "/* Syntax: <class> $name$arguments */"
	set body   "\n    $syntax\n$cdimport\n    $body"

	set code [critcl::collect {
	    critcl::ccommand $function {} $body \
		-cname 1 -tracename $tname
	}]
    }

    MethodDef classmethod class $name $enum $syntax $function {} $code
    return
}

proc ::critcl::class::MethodCheck {section label name} {
    variable state
    if {[dict exists $state $section def $name]} {
	return -code error "Duplicate definition of $label method \"$name\""
    }
    return
}

proc ::critcl::class::MethodEnum {section name} {
    variable state
    # Compute a C enum identifier from the (class) method name.

    # To avoid trouble we have to remove any non-alphabetic
    # characters. A serial number is required to distinguish methods
    # which would, despite having different names, transform to the
    # same C enum identifier.

    regsub -all -- {[^a-zA-Z0-9_]} $name _ name
    regsub -all -- {_+} $name _ name

    set serial [llength [dict get $state $section names]]
    set M [expr {$section eq "method" ? "M" : "CM"}]

    return @stem@_${M}_${serial}_[string toupper $name]
}

proc ::critcl::class::MethodDef {section var name enum syntax function xmap code} {
    variable state

    set case  "case $enum: return @function@ ($var, interp, objc, objv); break;"
    set case [string map $xmap $case]

    set map [list @function@ $function]

    dict update state $section m {
	dict lappend m names $name
    }
    dict set state $section def $name enum $enum
    dict set state $section def $name case   [string map $map $case]
    dict set state $section def $name code   [string map $map $code]
    dict set state $section def $name syntax [string map $map $syntax]
    return
}

proc ::critcl::class::CodeFragment {section code} {
    variable state
    set code [string trim $code \n]
    if {$code ne {}} {
	dict lappend state $section $code
    }
    return
}

# # ## ### ##### ######## ############# #####################
##
# Internal: Namespace holding the class specification commands. The
# associated state resides in the outer namespace, as do all the
# procedures actually accessing that state (see above). Treat it like
# a sub-package, with a proper API.
##
# # ## ### ##### ######## ############# #####################

namespace eval ::critcl::class::spec {}

proc ::critcl::class::spec::Process {script} {
    # Note how this script is evaluated within the 'spec' namespace,
    # providing it with access to the specification methods.

    # Point the global namespace resolution into the spec namespace,
    # to ensure that the commands are properly found even if the
    # script moved through helper commands and other namespaces.

    # Note that even this will not override the builtin 'variable'
    # command with ours, which is why ours is now called
    # 'insvariable'.

    namespace eval :: [list namespace path [list [namespace current] ::]]

    eval $script

    namespace eval :: {namespace path {}}
    return
}

proc ::critcl::class::spec::tcl-api {flag} {
    ::critcl::class::Flag tcl-api $flag
}

proc ::critcl::class::spec::c-api {flag {name {}}} {
    ::critcl::class::Flag c-api $flag
    if {$name eq {}} return
    ::critcl::class::CAPIPrefix $name
}

proc ::critcl::class::spec::include {header} {
    ::critcl::class::Include $header
}

proc ::critcl::class::spec::type {name} {
    ::critcl::class::ExternalType $name
}

proc ::critcl::class::spec::insvariable {ctype name {comment {}} {constructor {}} {destructor {}}} {
    ::critcl::at::caller
    set vloc [critcl::at::get*]
    ::critcl::at::incrt $comment     ; set cloc [::critcl::at::get*]
    ::critcl::at::incrt $constructor ; set dloc [::critcl::at::get]


    ::critcl::class::Variable $ctype $name $comment $vloc

    if {$constructor ne {}} {
	::critcl::class::Constructor $cloc$constructor
    }
    if {$destructor ne {}} {
	::critcl::class::Destructor $dloc$destructor
    }

    return
}

proc ::critcl::class::spec::constructor {code {postcode {}}} {
    ::critcl::at::caller      ; set cloc [::critcl::at::get*]
    ::critcl::at::incrt $code ; set ploc [::critcl::at::get]

    if {$code ne {}} {
	::critcl::class::Constructor $cloc$code
    }
    if {$postcode ne {}} {
	::critcl::class::PostConstructor $ploc$postcode
    }
    return
}

proc ::critcl::class::spec::destructor {code} {
    ::critcl::class::Destructor [::critcl::at::caller!]$code
    return
}

proc ::critcl::class::spec::method {name op detail args} {
    # Syntax
    # (1) method <name> as      <function>  ...
    # (2) method <name> proc    <arguments> <rtype> <body>
    # (3) method <name> command <arguments> <body>
    #            name   op      detail      args__________

    # op = as|proc|cmd|command

    # op == proc
    # detail  = argument list, syntax as per cproc.
    # args[0] = r(esult)type
    # args[1] = body

    # op == command
    # detail  = argument syntax. not used in code, purely descriptive.
    # args[0] = body

    switch -exact -- $op {
	as {
	    # The instance method is an external C function matching
	    # an ObjCmd in signature, possibly with additional
	    # parameters at the end.
	    #
	    # detail = name of that function
	    # args   = values for the additional parameters, if any.

	    ::critcl::class::MethodExternal $name $detail $args
	    return
	}
	proc {
	    if {[llength $args] != 2} {
		return -code error "wrong#args"
	    }
	}
	cmd - command {
	    set op command
	    if {[llength $args] != 1} {
		return -code error "wrong#args"
	    }
	}
	default {
	    return -code error "Illegal method type \"$op\", expected one of cmd, command, or proc"
	}
    }

    ::critcl::at::caller
    ::critcl::at::incrt $detail

    eval [linsert $args 0 ::critcl::class::MethodExplicit $name $op [string trim $detail]]
    #::critcl::class::MethodExplicit $name $op [string trim $detail] {*}$args
    return
}

proc ::critcl::class::spec::classvariable {ctype name {comment {}} {constructor {}} {destructor {}}} {
    ::critcl::at::caller
    set vloc [critcl::at::get*]
    ::critcl::at::incrt $comment     ; set cloc [::critcl::at::get*]
    ::critcl::at::incrt $constructor ; set dloc [::critcl::at::get]

    ::critcl::class::ClassVariable $ctype $name $comment $vloc

    if {$constructor ne {}} {
	::critcl::class::ClassConstructor $cloc$constructor
    }
    if {$destructor ne {}} {
	::critcl::class::ClassDestructor $dloc$destructor
    }
    return
}

proc ::critcl::class::spec::classconstructor {code} {
    ::critcl::class::ClassConstructor [::critcl::at::caller!]$code
    return
}

proc ::critcl::class::spec::classdestructor {code} {
    ::critcl::class::ClassDestructor [::critcl::at::caller!]$code
    return
}

proc ::critcl::class::spec::classmethod {name op detail args} {
    # Syntax
    # (1) classmethod <name> as      <function>  ...
    # (2) classmethod <name> proc    <arguments> <rtype> <body>
    # (3) classmethod <name> command <arguments> <body>
    #                 name   op      detail      args__________

    # op = as|proc|cmd|command

    # op == proc
    # detail  = argument syntax per cproc.
    # args[0] = r(esult)type
    # args[1] = body

    # op == command
    # detail  = argument syntax. not used in code, purely descriptive.
    # args[0] = body

    switch -exact -- $op {
	as {
	    # The class method is an external C function matching an
	    # ObjCmd in signature, possibly with additional parameters
	    # at the end.
	    #
	    # detail = name of that function
	    # args   = values for the additional parameters, if any.

	    ::critcl::class::ClassMethodExternal $name $detail $args
	    return
	}
	proc {
	    if {[llength $args] != 2} {
		return -code error "wrong#args"
	    }
	}
	cmd - command {
	    set op command
	    if {[llength $args] != 1} {
		return -code error "wrong#args"
	    }
	}
	default {
	    return -code error "Illegal method type \"$op\", expected one of cmd, command, or proc"
	}
    }

    ::critcl::at::caller
    ::critcl::at::incrt $detail
    eval [linsert $args 0 ::critcl::class::ClassMethodExplicit $name $op [string trim $detail]]
    # ::critcl::class::ClassMethodExplicit $name $op [string trim $detail] {*}$args
    return
}

proc ::critcl::class::spec::support {code} {
    ::critcl::class::Support [::critcl::at::caller!]$code
    return
}

proc ::critcl::class::spec::method_introspection {} {
    ::critcl::class::spec::classvariable Tcl_Obj* methods {
	Cache for the list of method names.
    } {
	class->methods = ComputeMethodList (@stem@_methodnames);
	Tcl_IncrRefCount (class->methods);
    } {
	Tcl_DecrRefCount (class->methods);
	class->methods = NULL;
    }

    # The ifdef/define/endif block below ensures that the supporting
    # code will be defined only once, even if multiple classes
    # activate method-introspection. Note that what we cannot prevent
    # is the appearance of multiple copies of the code below in the
    # generated output, only that it is compiled multiple times.

    ::critcl::class::spec::support {
#ifndef CRITCL_CLASS__HAVE_COMPUTE_METHOD_LIST
#define CRITCL_CLASS__HAVE_COMPUTE_METHOD_LIST
static Tcl_Obj*
ComputeMethodList (CONST char** table)
{
    Tcl_Size n, i;
    char** item;
    Tcl_Obj** lv;
    Tcl_Obj* result;

    item = (char**) table;
    n = 0;
    while (*item) {
	n ++;
	item ++;
    }

    lv = (Tcl_Obj**) ckalloc (n * sizeof (Tcl_Obj*));
    i = 0;
    while (table [i]) {
	lv [i] = Tcl_NewStringObj (table [i], -1);
	i ++;
    }

    result = Tcl_NewListObj (n, lv);
    ckfree ((char*) lv);

    return result;
}
#endif /* CRITCL_CLASS__HAVE_COMPUTE_METHOD_LIST */
    }

    ::critcl::class::spec::method methods proc {} void {
	Tcl_SetObjResult (interp, instance->class->methods);
    }

    ::critcl::class::spec::classmethod methods proc {} void {
	Tcl_SetObjResult (interp, class->methods);
    }
    return
}

# # ## ### ##### ######## ############# #####################
## State

namespace eval ::critcl::class {
    variable selfdir [file dirname [file normalize [info script]]]
}

# # ## ### ##### ######## ############# #####################
## Export API

namespace eval ::critcl::class {
    namespace export define
    catch { namespace ensemble create } ; # 8.5+
}

# # ## ### ##### ######## ############# #####################
## Ready
return
