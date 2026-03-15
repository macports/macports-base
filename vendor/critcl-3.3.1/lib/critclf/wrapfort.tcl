# wrapfort.tcl --
#     Utility for quickly wrapping Fortran (77) routines
#
#     TODO:
#     - Fortran functions are not covered yet (void __stdcall ...)
#

package require Tcl 8.6 9
package provide wrapfort 0.3

# Wrapfort --
#     Namespace which holds all relevant information and procedures
#
namespace eval ::Wrapfort {
    variable srcout          ;# Handle to the output file
    variable incritcl 0      ;# Interaction with Critcl
    variable tclfname        ;# C file with Tcl_CreateCommand()
    variable pkgfname        ;# C file to compile

    variable header          ;# Template for routine header
    variable routines        ;# List of routines to be registered
    variable declaration     ;# Array containing the declaration templates
    variable initialisation  ;# Array containing the initialisation templates
    variable cleanup         ;# Array containing the templates for clean up code
    variable result          ;# Array containing the templates for result code

    variable fheader         ;# Template for Tcl proc wrapper, called from Fortran
    variable fdeclaration    ;# Array containing the declaration templates
    variable finitialisation ;# Array containing the initialisation templates
    variable fcleanup        ;# Array containing the templates for clean up code
    variable fresult         ;# Array containing the templates for result code

    variable ref_interfaces  ;# List of referenced interfaces
    variable dfn_interfaces  ;# List of defined interfaces

    set ref_interfaces {}
    set dfn_interfaces {}

    namespace export fproc fsource fexternal

    variable wrapdir [file dirname [info script]] ;# Directory containing auxiliary files

    source [file join $wrapdir "wrapfort.code"]
}


# incritcl --
#     Set the parameter that determines whether used via Critcl
#
# Arguments:
#     in              If true, called via Critcl, otherwise standalone
#
proc ::Wrapfort::incritcl {in} {
    variable incritcl

    set incritcl $in

}


# Output --
#     Write the C code fragments
#
# Arguments:
#     code            Code to be written to file or stored in a variable
#
proc ::Wrapfort::Output {code} {
    variable incritcl
    variable srcout

    if { ! $incritcl } {
        puts $srcout $code
    } else {
        ::critcl::Emitln $code
    }
}
proc ::Wrapfort::Output2 {code} {
    variable incritcl
    variable cmdout

    if { ! $incritcl } {
        puts $cmdout $code
    } else {
	return -code error "Cmdemit does not exist!!"
        ::critcl::Cmdemit $code
    }
}


# fsource --
#     Open the source file
#
# Arguments:
#     pkgname         Name of the package
#     filename        Name of the file to write
#
proc ::Wrapfort::fsource {pkgname filename} {
    variable srcout
    variable cmdout
    variable wrapdir
    variable tclfname
    variable pkgfname
    variable incritcl

    set srcout [open $filename w]
    set cmdout [open [file join [file dirname $filename] "tcl_[file tail $filename]"] w]

    #
    # The template files
    #
    set infile   [open [file join $wrapdir "pkg_wrap.c"]]
    set pkgfname [file join [file dirname $filename] "pkg_[file tail $filename]"]
    set tclfname [file join [file dirname $filename] "tcl_[file tail $filename]"]

    set contents [string map [list PKGNAME $pkgname \
        PKGINIT [string totitle $pkgname] FILENAME $filename TCLFNAME $tclfname] \
        [read $infile]]

    set outfile  [open $pkgfname w]
    if { $incritcl } {
        puts $outfile "#define CRITCLF"
    }
    puts -nonewline $outfile $contents
    close $outfile
    close $infile

    set infile  [open [file join $wrapdir "idx_wrap.tcl"]]
    set outfile [open "pkgIndex.tcl" w]
    set contents [string map [list PKGNAME $pkgname] [read $infile]]
    puts -nonewline $outfile $contents
    close $outfile
    close $infile
}


# fproc --
#     Procedure to drive the generation of the wrapper code
#
# Arguments:
#     cmdname         Name of the corresponding Tcl command
#     froutine        Name of the Fortran routine/function that is to be wrapped
#     arglist         Description of the argument list and local
#                     variables, as well as specific code
#
proc ::Wrapfort::fproc {cmdname routine arglist} {
    #
    # Check any external interfaces
    #
    ExternalInterfaces $arglist

    #
    # The generation occurs in stages
    #
    WriteTclCreateCommand $cmdname $routine
    WriteRoutineHeader    $cmdname $routine $arglist

    WriteDeclarations   $arglist
    WriteInitialisation $arglist
    WriteBody           $arglist
    WriteResultCode     $arglist
    WriteCleanup        $arglist
}


# ExternalInterfaces --
#     Check and update the lists of external interfaces
#
# Arguments:
#     arglist         Argument list for the Fortran routine
# Result:
#     None
#
# Side effects:
#     Updates the list ref_interfaces. May throw
#     an error
#
proc ::Wrapfort::ExternalInterfaces {arglist} {
    variable ref_interfaces
    variable dfn_interfaces

    foreach {type name specs} $arglist {
        if { $type == "external" } {
            if { [lsearch $ref_interfaces $name] >= 0 } {
                return -code error "Interface $name already referenced!"
            } else {
                lappend ref_interfaces $name
            }
            if { [lsearch $dfn_interfaces $name] < 0 } {
                return -code error "Interface $name has not been defined yet!"
            }
        }
    }
}


# WriteTclCreateCommand --
#     Write the Tcl_CreateObjCommand line to register the command
#
# Arguments:
#     cmdname         Name of the corresponding Tcl command
#     routine         Name of the C routine/function that will be created
# Result:
#     None
#
# Side effects:
#     Writes a piece of the code to the second file
#
proc ::Wrapfort::WriteTclCreateCommand {cmdname routine} {

    Output2 [string map [list CMDNAME $cmdname ROUTINE $routine] \
        "    Tcl_CreateObjCommand2( interp, \"CMDNAME\", c__ROUTINE, NULL, NULL );"]
}


# WriteRoutineHeader --
#     Write the header for the routine/function
#
# Arguments:
#     cmdname         Name of the corresponding Tcl command
#     routine         Name of the C routine/function that will be created
#     arglist         Description of the argument list and local
#                     variables, as well as specific code
# Result:
#     None
#
# Side effects:
#     Writes a piece of the code to file, also stores the command
#     and routine names for later use.
#
proc ::Wrapfort::WriteRoutineHeader {cmdname routine arglist} {
    variable routines
    variable header
    variable external_decl

    lappend routines [list $cmdname $routine]

    Output [string map [list ROUTINE $routine ALLCAPS [string toupper $routine] \
                             CMDNAME $cmdname] $header]
}


# WriteInitialisation --
#     Write the initialisation code for the routine
#
# Arguments:
#     arglist         Description of the argument list and local
#                     variables, as well as specific code
# Result:
#     None
#
# Side effects:
#     Writes a piece of the code to file
#
proc ::Wrapfort::WriteInitialisation {arglist} {
    variable initialisation

    #
    # First count the arguments
    #
    set count 1
    foreach {type name specs} $arglist {
        switch -- $type {
            "integer" - "real" - "double" - "string" - "logical" -
            "integer-vector" - "real-vector" - "double-vector" -
            "integer-array"  - "real-array"  - "double-array"  -
            "integer-matrix" - "real-matrix" - "double-matrix" {
                if { [lindex $specs 0] == "input" } {
                    incr count
                }
            }
            "external" {
                incr count
            }
        }
    }

    Output [string map [list COUNT $count] $initialisation(check)]

    #
    # Then handle the arguments
    #
    set count 1
    foreach {type name specs} $arglist {
        switch -- $type {
            "integer" - "real" - "double" - "string" - "logical" -
            "integer-vector" - "real-vector" - "double-vector" -
            "integer-array"  - "real-array"  - "double-array"  -
            "integer-matrix" - "real-matrix" - "double-matrix" {
                if { [lindex $specs 0] == "input"} {
                    Output [string map [list NAME $name COUNT $count] \
                    $initialisation($type)]
                }
            }
            "external" {
                Output [string map [list NAME $name COUNT $count] \
                    $initialisation($type)]
            }
        }
        if { [lindex $specs 0] != "result" } {
            incr count
        }
    }

    #
    # Finally handle the local variables
    #
    foreach {type name specs} $arglist {
        switch -- $type {
            "integer" - "double" - "string" - "logical" -
            "integer-vector" - "real-vector" - "double-vector" -
            "integer-array"  - "real-array"  - "double-array"  -
            "integer-matrix" - "real-matrix" - "double-matrix" {
                if { [lindex $specs 0] != "input"} {
                    #
                    # TODO: Requires more code!
                    #
                    Output "[MakeInitCode $type $name $specs]"
                }
            }
        }
    }
}


# MakeInitCode --
#     Make the code to initialise the given variable
#
# Arguments:
#     type            Type of the variable
#     name            Name of the variable
#     specs           Specification of how to initialise the variable
# Result:
#     Fragment of C code to initialise the variable
#
proc ::Wrapfort::MakeInitCode {type name specs} {

    # For the moment: just replace size() by the hidden C variable

    if { [lindex $specs 0] == "assign" } {
        regsub -all {size\((.+)\)} [lrange $specs 1 end] {size__\1} ccode
        return "    $name = $ccode ;"
    } elseif { [lindex $specs 0] == "allocate" } {
        set ctype [DetermineCType $type]

        regsub -all {size\((.+)\)} [lrange $specs 1 end] {size__\1} ccode
        return "    $name = ($ctype *) ckalloc(sizeof($ctype)*($ccode)) ;
    size__$name = $ccode;"
    } elseif { [lindex $specs 0] == "result" && [string match "*-array" $type] } {
        set ctype [DetermineCType $type]

        regsub -all {size\((.+)\)} [lrange $specs 1 end] {size__\1} ccode
        return "    $name = ($ctype *) ckalloc(sizeof($ctype)*($ccode)) ;
    size__$name = $ccode;"
    } else {
        return "    /* No initialisation for $name ($specs) */"
    }
}


# WriteDeclarations --
#     Extract the definitions and declarations from the list and
#     write to the source file
#
# Arguments:
#     arglist         Description of the argument list and local
#                     variables, as well as specific code
# Result:
#     None
#
# Side effects:
#     Writes a piece of the code to file
#
proc ::Wrapfort::WriteDeclarations {arglist} {
    variable srcout
    variable declaration

    foreach {type name specs} $arglist {
        switch -- $type {
            "integer" - "double" - "real" - "string" - "logical" -
            "integer-vector" - "real-vector" - "double-vector" -
            "integer-array"  - "real-array"  - "double-array"  -
            "integer-matrix" - "real-matrix" - "double-matrix" {
                Output [string map [list NAME $name] $declaration($type)]
            }
            "code" - "external" {
                continue  ;# Just skip those at this stage
            }
            default {
                return -code error "Unknown keyword/type: $type"
            }
        }
    }
}


# WriteBody --
#     Write the literal code that may appear as type "code"
#
# Arguments:
#     arglist         Description of the argument list and local
#                     variables, as well as specific code
# Result:
#     None
#
# Side effects:
#     Writes a piece of the code to file
#
proc ::Wrapfort::WriteBody {arglist} {
    variable srcout

    foreach {type name specs} $arglist {
        switch -- $type {
            "code" {
                Output $specs
            }
        }
    }
}


# WriteResultCode --
#     Write the code to pass on the results
#
# Arguments:
#     arglist         Description of the argument list and local
#                     variables, as well as specific code
# Result:
#     None
#
# Side effects:
#     Writes a piece of the code to file
#
proc ::Wrapfort::WriteResultCode {arglist} {
    variable result
    variable srcout

    set count 0
    foreach {type name specs} $arglist {
        switch -- [lindex $specs 0] {
            "result" {
                Output [string map [list NAME $name] $result($type)]
            }
        }
    }
}


# WriteCleanup --
#     Write the code to clean up before returning
#
# Arguments:
#     arglist         Description of the argument list and local
#                     variables, as well as specific code
# Result:
#     None
#
# Side effects:
#     Writes a piece of the code to file
#
proc ::Wrapfort::WriteCleanup {arglist} {
    variable cleanup
    variable srcout

    set count 0
    foreach {type name specs} $arglist {
        switch -- $type {
            "integer" - "real" - "double" - "string" - "logical" -
            "integer-vector" - "real-vector" - "double-vector" -
            "integer-array"  - "real-array"  - "double-array"  -
            "integer-matrix" - "real-matrix" - "double-matrix" - "external" {
                Output [string map [list NAME $name] $cleanup($type)]
            }
        }
    }

    Output $cleanup(close)
}


# fexternal --
#     Procedure to generate a wrapper for a Tcl procedure
#
# Arguments:
#     interface       Name of the Fortran interface
#     arglist         Description of the arguments on the Fortran and Tcl side
#
proc ::Wrapfort::fexternal {interface arglist} {

    set data(onerror) {}
    array set data $arglist

    #
    # Check that the calling Fortran routine has already been defined!
    #
    CheckCallingRoutine $interface

    #
    # The generation occurs in stages
    #
    FortranWriteRoutineHeader  $interface $data(fortran)

    FortranWriteInitialisation $interface $data(fortran) $data(toproc)
    FortranWriteResultCode     $interface $data(fortran) $data(toproc) $data(onerror)
    FortranWriteCleanup        $interface $data(fortran) $data(toproc)
}


# CheckCallingRoutine --
#     Check if the calling Fortran routine has already been defined
#
# Arguments:
#     name            Name of the interface
# Result:
#     None
#
# Side effects:
#     Updates the list dfn_interfaces. May throw an error
#
proc ::Wrapfort::CheckCallingRoutine {name} {
    variable ref_interfaces
    variable dfn_interfaces

    if { [lsearch $dfn_interfaces $name] >= 0 } {
         return -code error "Interface $name has already been defined!"
    }

    lappend dfn_interfaces $name
}


# FortranWriteRoutineHeader --
#     Write the header for the wrapper routine
#
# Arguments:
#     interface       Name of the Fortran interface
#     arglist         Description of the arguments on the Fortran side
#
proc ::Wrapfort::FortranWriteRoutineHeader {interface arglist} {
    variable srcout
    variable fheader
    variable fdeclaration

    set ftype [DetermineFunctionType $arglist]

    Output "[string map [list TYPE $ftype NAME $interface \
                              ALLCAPS [string toupper $interface]] $fheader(start)]"

    set arguments {}
    foreach {type var specs} $arglist {
        if { [lindex $specs 0] != "result" } {
            lappend arguments "[string map [list NAME $var] $fdeclaration($type)]"
        }
    }
    Output [join $arguments ",\n"]
    Output $fheader(end)

    #
    # Local declarations we need
    #
    foreach {type var specs} $arglist {
        if { [string match "*-array" $type] } {
            set size [lindex $specs 1]
            Output "[string map [list SIZE $size NAME $var] $fdeclaration(length)]"
        }
    }
}


# DetermineFunctionType --
#     Determine the type of the C wrapper
#
# Arguments:
#     arglist         Description of the arguments on the Fortran side
#
proc ::Wrapfort::DetermineFunctionType {arglist} {
    variable ctype

    set functiontype "void"

    foreach {type name specs} $arglist {
         if { [lindex $specs 0] == "result" } {
             set functiontype $type
             break
         }
    }
    return $ctype($functiontype)
}


# DetermineCType --
#     Determine the C type that corresponds to the given type
#
# Arguments:
#     type            Type of the variable in the interface definition
#
proc ::Wrapfort::DetermineCType {type} {
    variable ctype

    return $ctype($type)
}


# ReturnDummyValue --
#     Determine the correct dummy return value (if any)
#
# Arguments:
#     arglist         Description of the arguments on the Fortran side
#
proc ::Wrapfort::ReturnDummyValue {arglist} {

    set dummy [DetermineFunctionType $arglist]

    if { $dummy == "void" } {
        set dummy ""
    } else {
        set dummy "($dummy) 0"
    }
    return $dummy
}


# FortranWriteInitialisation --
#     Write the initialisation part of the wrapper routine
#
# Arguments:
#     interface       Name of the Fortran interface
#     fortargs        Description of the arguments on the Fortran side
#     tclargs         Description of the arguments on the Tcl side
#
proc ::Wrapfort::FortranWriteInitialisation {interface fortargs tclargs} {
    variable srcout
    variable finitialisation
    variable fdecl_result

    foreach {type name specs} $fortargs {
         if { [lindex $specs 0] == "result" } {
            Output "[string map [list NAME $name] \
                     $fdecl_result($type)]"
         }
    }

    set noargs [NumberArguments $tclargs]
    Output "[string map [list NOARGS $noargs NAME $interface \
        DUMMY [ReturnDummyValue $fortargs]] $finitialisation(start)]"

    set idx 1
    foreach {var role} $tclargs {
        if { $role != "result" } {
            set pos  [lsearch $fortargs $var]
            set type [lindex  $fortargs [expr {$pos-1}]]
            Output "[string map [list NAME $var IDX $idx] $finitialisation($type)]"
            incr idx
        }
    }
}


# NumberArguments --
#     Determine the number of arguments to be passed to the Tcl proc
#
# Arguments:
#     arglist         Description of the arguments on the Tcl side
#
proc ::Wrapfort::NumberArguments {arglist} {

    set number 1
    foreach {name role} $arglist {
        if { $role != "result" } {
            incr number
        }
    }
    return $number
}


# FortranWriteResultCode --
#     Write the part for calling the Tcl proc and handling the result
#
# Arguments:
#     interface       Name of the Fortran interface
#     fortargs        Description of the arguments on the Fortran side
#     tclargs         Description of the arguments on the Tcl side
#     errorhandling   Error handling code
#
proc ::Wrapfort::FortranWriteResultCode {interface fortargs tclargs errorhandling} {
    variable srcout
    variable frunproc
    variable fresult
    variable ferror

    Output $frunproc

    foreach {var role} $tclargs {
        if { $role == "result" } {
            set pos  [lsearch $fortargs $var]
            set type [lindex  $fortargs [expr {$pos-1}]]
            Output "[string map [list NAME $var] $fresult($type)]"
        }
    }
   #foreach {type var specs} $fortargs {
   #    if { [lindex $specs 0] == "result" } {
   #        Output "[string map [list NAME $var] $fresult($type)]"
   #    }
   #}

   Output [string map [list ERROR $errorhandling] $ferror]
}


# FortranWriteCleanup --
#     Write the cleanup code
#
# Arguments:
#     interface       Name of the Fortran interface
#     fortargs        Description of the arguments on the Fortran side
#     tclargs         Description of the arguments on the Tcl side
#
proc ::Wrapfort::FortranWriteCleanup {interface fortargs tclargs} {
    variable srcout
    variable fcleanup
    variable freturn

    set idx 1
    foreach {var role} $tclargs {
        if { $role != "result" } {
            set pos  [lsearch $fortargs $var]
            set type [lindex  $fortargs [expr {$pos-1}]]
            Output "[string map [list NAME $var IDX $idx] $fcleanup($type)]"
            incr idx
        }
    }

    set ftype [DetermineFunctionType $fortargs]

    if { $ftype != "void" } {
        foreach {type var specs} $fortargs {
            if { [lindex $specs 0] == "result" } {
                Output "[string map [list NAME $var] $freturn($type)]"
            }
        }
    }

    Output "\}"
}
