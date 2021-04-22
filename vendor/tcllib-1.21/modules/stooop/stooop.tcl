# stooop
# Simple Tcl Only Object Oriented Programming
# An object oriented extension to the Tcl programming language
#
# Copyright (c) 2002 by Jean-Luc Fontaine <jfontain@free.fr>.
# This code may be distributed under the same terms as Tcl.
#
# $Id: stooop.tcl,v 1.9 2004/01/15 06:36:14 andreas_kupries Exp $


# check whether empty named arrays and array unset are supported:
package require Tcl 8.3

package provide stooop 4.4.1

# rename proc before it is overloaded, ignore error in case of multiple
# inclusion of this file:
catch {rename proc _proc}

namespace eval ::stooop {
    variable check
    variable trace

    # no checking by default: use an empty instruction to avoid any performance
    # hit:
    set check(code) {}
    if {[info exists ::env(STOOOPCHECKALL)]&&$::env(STOOOPCHECKALL)} {
        array set ::env\
            {STOOOPCHECKPROCEDURES 1 STOOOPCHECKDATA 1 STOOOPCHECKOBJECTS 1}
    }
    set check(procedures) [expr {\
        [info exists ::env(STOOOPCHECKPROCEDURES)]&&\
        $::env(STOOOPCHECKPROCEDURES)\
    }]
    set check(data) [expr {\
        [info exists ::env(STOOOPCHECKDATA)]&&$::env(STOOOPCHECKDATA)\
    }]
    set check(objects) [expr {\
        [info exists ::env(STOOOPCHECKOBJECTS)]&&$::env(STOOOPCHECKOBJECTS)\
    }]
    if {$check(procedures)} {
        append check(code) {::stooop::checkProcedure;}
    }
    if {[info exists ::env(STOOOPTRACEALL)]} {
        # use same channel for both traces
        set ::env(STOOOPTRACEPROCEDURES) $::env(STOOOPTRACEALL)
        set ::env(STOOOPTRACEDATA) $::env(STOOOPTRACEALL)
    }
    if {[info exists ::env(STOOOPTRACEPROCEDURES)]} {
        set trace(procedureChannel) $::env(STOOOPTRACEPROCEDURES)
        switch $trace(procedureChannel) {
            stdout - stderr {}
            default {
                # eventually truncate output file if it exists:
                set trace(procedureChannel) [open $::env(STOOOPTRACEPROCEDURES) w+]
            }
        }
        # default format:
        set trace(procedureFormat)\
            {class: %C, procedure: %p, object: %O, arguments: %a}
        # eventually override with user defined format:
        catch {set trace(procedureFormat) $::env(STOOOPTRACEPROCEDURESFORMAT)}
        append check(code) {::stooop::traceProcedure;}
    }
    if {[info exists ::env(STOOOPTRACEDATA)]} {
        set trace(dataChannel) $::env(STOOOPTRACEDATA)
        switch $trace(dataChannel) {
            stdout - stderr {}
            default {
                # eventually truncate output file if it exists
                set trace(dataChannel) [open $::env(STOOOPTRACEDATA) w+]
            }
        }
        # default format:
        set trace(dataFormat) {class: %C, procedure: %p, array: %A, object: %O, member: %m, operation: %o, value: %v}
        # eventually override with user defined format:
        catch {set trace(dataFormat) $::env(STOOOPTRACEDATAFORMAT)}
        # trace all operations by default:
        set trace(dataOperations) rwu
        # eventually override with user defined operations:
        catch {set trace(dataOperations) $::env(STOOOPTRACEDATAOPERATIONS)}
    }

    namespace export class virtual new delete classof  ;# export public commands

    if {![info exists newId]} {
        # initialize object id counter only once even if this file is sourced
        # several times:
        variable newId 0
    }

    # create an object of specified class or copy an existing object:
    _proc new {classOrId args} {
        variable newId
        variable fullClass

        # use local variable for identifier because new can be invoked
        # recursively:
        if {[string is integer $classOrId]} {
            # first argument is an object identifier (unsigned integer), copy
            # source object to new object of identical class
            if {[catch {\
                set fullClass([set id [incr newId]]) $fullClass($classOrId)\
            }]} {
                error "invalid object identifier $classOrId"
            }
            # invoke the copy constructor for the class in caller's variable
            # context so that object copy is transparent (see above):
            uplevel 1 $fullClass($classOrId)::_copy $id $classOrId
        } else {                                    ;# first argument is a class
            # generate constructor name:
            set constructor ${classOrId}::[namespace tail $classOrId]
            # we could detect here whether class was ever declared but that
            # would prevent stooop packages to load properly, because
            # constructor would not be invoked and thus class source file never
            # sourced
            # invoke the constructor for the class with optional arguments in
            # caller's variable context so that object creation is transparent
            # and that array names as constructor parameters work with a simple
            # upvar
            # note: if class is in a package, the class namespace code is loaded
            # here, as the first object of the class is created
            uplevel 1 $constructor [set id [incr newId]] $args
            # generate fully qualified class namespace name now that we are sure
            # that class namespace code has been invoked:
            set fullClass($id) [namespace qualifiers\
                [uplevel 1 namespace which -command $constructor]\
            ]
        }
        return $id                          ;# return a unique object identifier
    }

    _proc delete {args} {                          ;# delete one or more objects
        variable fullClass

        foreach id $args {
            # destruct in caller's variable context so that object deletion is
            # transparent:
            uplevel 1 ::stooop::deleteObject $fullClass($id) $id
            unset fullClass($id)
        }
    }

    # delete object data starting at specified class layer and going up the base
    # class hierarchy if any
    # invoke the destructor for the object class and unset all the object data
    # members for the class
    # the destructor will in turn delete the base classes layers
    _proc deleteObject {fullClass id} {
        # invoke the destructor for the class in caller's variable context so
        # that object deletion is transparent:
        uplevel 1 ${fullClass}::~[namespace tail $fullClass] $id
        # delete all this object data members if any (assume that they were
        # stored as ${class}::($id,memberName)):
        array unset ${fullClass}:: $id,*
        # data member arrays deletion is left to the user
    }

    _proc classof {id} {
        variable fullClass

        return $fullClass($id)                         ;# return class of object
    }

    # copy object data members from one object to another:
    _proc copy {fullClass from to} {
        set index [string length $from]
        # copy regular data members:
        foreach {name value} [array get ${fullClass}:: $from,*] {
            set ${fullClass}::($to[string range $name $index end]) $value
        }
        # if any, array data members copy is left to the class programmer
        # through the then mandatory copy constructor
    }
}

_proc ::stooop::class {args} {
    variable declared

    set class [lindex $args 0]
    # register class using its fully qualified name:
    set declared([uplevel 1 namespace eval $class {namespace current}]) {}
    # create the empty name array used to hold all class objects so that static
    # members can be directly initialized within the class declaration but
    # outside member procedures
    uplevel 1 namespace eval $class [list "::variable {}\n[lindex $args end]"]
}

# if procedure is a member of a known class, class and procedure names are set
# and true is returned, otherwise false is returned:
_proc ::stooop::parseProcedureName {\
    namespace name fullClassVariable procedureVariable messageVariable\
} {
    # namespace argument is the current namespace (fully qualified) in which the
    # procedure is defined
    variable declared
    upvar 1 $fullClassVariable fullClass $procedureVariable procedure\
        $messageVariable message

    if {\
        [info exists declared($namespace)]&&\
        ([string length [namespace qualifiers $name]]==0)\
    } {
        # a member procedure is being defined inside a class namespace
        set fullClass $namespace
        set procedure $name                ;# member procedure name is full name
        return 1
    } else {
        # procedure is either a member of a known class or a regular procedure
        if {![string match ::* $name]} {
            # eventually fully qualify procedure name
            if {[string equal $namespace ::]} { ;# global namespace special case
                set name ::$name
            } else {
                set name ${namespace}::$name
            }
        }
        # eventual class name is leading part:
        set fullClass [namespace qualifiers $name]
        if {[info exists declared($fullClass)]} {           ;# if class is known
            set procedure [namespace tail $name] ;# procedure always is the tail
            return 1
        } else {                                       ;# not a member procedure
            if {[string length $fullClass]==0} {
                set message "procedure $name class name is empty"
            } else {
                set message "procedure $name class $fullClass is unknown"
            }
            return 0
        }
    }
}

# virtual operator, to be placed before proc
# virtualize a member procedure, determine whether it is a pure virtual, check
# for procedures that cannot be virtualized
_proc ::stooop::virtual {keyword name arguments args} {
    # set a flag so that proc knows it is acting upon a virtual procedure, also
    # serves as a pure indicator:
    variable pureVirtual

    if {![string equal [uplevel 1 namespace which -command $keyword] ::proc]} {
        error "virtual operator works only on proc, not $keyword"
    }
    if {![parseProcedureName\
        [uplevel 1 namespace current] $name fullClass procedure message\
    ]} {
        error $message                   ;# not in a member procedure definition
    }
    set class [namespace tail $fullClass]
    if {[string equal $class $procedure]} {
        error "cannot make class $fullClass constructor virtual"
    }
    if {[string equal ~$class $procedure]} {
        error "cannot make class $fullClass destructor virtual"
    }
    if {![string equal [lindex $arguments 0] this]} {
        error "cannot make static procedure $procedure of class $fullClass virtual"
    }
    # no procedure body means pure virtual:
    set pureVirtual [expr {[llength $args]==0}]
    # process procedure declaration, body being empty for pure virtual procedure
    # make virtual transparent by using uplevel:
    uplevel 1 ::proc [list $name $arguments [lindex $args 0]]
    unset pureVirtual
}

_proc proc {name arguments args} {
    if {![::stooop::parseProcedureName\
        [uplevel 1 namespace current] $name fullClass procedure message\
    ]} {
        # not in a member procedure definition, fall back to normal procedure
        # declaration
        # uplevel is required instead of eval here otherwise tcl seems to forget
        # the procedure namespace if it exists
        uplevel 1 _proc [list $name $arguments] $args
        return
    }
    if {[llength $args]==0} {               ;# check for procedure body presence
        error "missing body for ${fullClass}::$procedure"
    }
    set class [namespace tail $fullClass]
    if {[string equal $class $procedure]} {      ;# class constructor definition
        if {![string equal [lindex $arguments 0] this]} {
            error "class $fullClass constructor first argument must be this"
        }
        if {[string equal [lindex $arguments 1] copy]} {
            # user defined copy constructor definition
            if {[llength $arguments]!=2} {
                error "class $fullClass copy constructor must have 2 arguments exactly"
            }
            # make sure of proper declaration order:
            if {[catch {info body ::${fullClass}::$class}]} {
                error "class $fullClass copy constructor defined before constructor"
            }
            eval ::stooop::constructorDeclaration\
                $fullClass $class 1 \{$arguments\} $args
        } else {                                             ;# main constructor
            eval ::stooop::constructorDeclaration\
                $fullClass $class 0 \{$arguments\} $args
            # always generate default copy constructor:
            ::stooop::generateDefaultCopyConstructor $fullClass
        }
    } elseif {[string equal ~$class $procedure]} {
        # class destructor declaration
        if {[llength $arguments]!=1} {
            error "class $fullClass destructor must have 1 argument exactly"
        }
        if {![string equal [lindex $arguments 0] this]} {
            error "class $fullClass destructor argument must be this"
        }
        # make sure of proper declaration order
        # (use fastest method for testing procedure existence):
        if {[catch {info body ::${fullClass}::$class}]} {
            error "class $fullClass destructor defined before constructor"
        }
        ::stooop::destructorDeclaration\
            $fullClass $class $arguments [lindex $args 0]
    } else {
        # regular member procedure, may be static if there is no this first
        # argument
        # make sure of proper declaration order:
        if {[catch {info body ::${fullClass}::$class}]} {
            error "class $fullClass member procedure $procedure defined before constructor"
        }
        ::stooop::memberProcedureDeclaration\
            $fullClass $class $procedure $arguments [lindex $args 0]
    }
}

# copy flag is set for user defined copy constructor:
_proc ::stooop::constructorDeclaration {fullClass class copy arguments args} {
    variable check
    variable fullBases
    variable variable

    set number [llength $args]
    # check that each base class constructor has arguments:
    if {($number%2)==0} {
        error "bad class $fullClass constructor declaration, a base class, contructor arguments or body may be missing"
    }
    if {[string equal [lindex $arguments end] args]} {
        # remember that there is a variable number of arguments in class
        # constructor
        set variable($fullClass) {}
    }
    if {!$copy} {
        # do not initialize (or reinitialize in case of multiple class file
        # source statements) base classes for copy constructor
        set fullBases($fullClass) {}
    }
    # check base classes and their constructor arguments:
    foreach {base baseArguments} [lrange $args 0 [expr {$number-2}]] {
        # fully qualify base class namespace by looking up constructor, which
        # must exist
        set constructor ${base}::[namespace tail $base]
        # in case base class is defined in a file that is part of a package,
        # make sure that file is sourced through the tcl package auto-loading
        # mechanism by directly invoking the base class constructor while
        # ignoring the resulting error
        catch {$constructor}
        # determine fully qualified base class name in user invocation level
        # (up 2 levels from here since this procedure is invoked exclusively by
        # proc)
        set fullBase [namespace qualifiers\
            [uplevel 2 namespace which -command $constructor]\
        ]
        if {[string length $fullBase]==0} {   ;# base constructor is not defined
            if {[string match *$base $fullClass]} {
                # if the specified base class name is included last in the fully
                # qualified class name, assume that it was meant to be the same
                error "class $fullClass cannot be derived from itself"
            } else {
                error "class $fullClass constructor defined before base class $base constructor"
            }
        }
        # check and save base classes only for main constructor that defines
        # them:
        if {!$copy} {
            if {[lsearch -exact $fullBases($fullClass) $fullBase]>=0} {
                error "class $fullClass directly inherits from class $fullBase more than once"
            }
            lappend fullBases($fullClass) $fullBase
        }
        # replace new lines with blanks in base arguments part in case user has
        # formatted long declarations with new lines
        regsub -all {\n} $baseArguments { } constructorArguments($fullBase)
    }
    # setup access to class data (an empty named array)
    # fully qualify tcl variable command for it may have been redefined within
    # the class namespace
    # since constructor is directly invoked by new, the object identifier must
    # be valid, so debugging the procedure is pointless
    set constructorBody \
"::variable {}
$check(code)
"
    # base class(es) derivation specified:
    if {[llength $fullBases($fullClass)]>0} {
        # invoke base class constructors before evaluating constructor body
        # then set base part hidden derived member so that virtual procedures
        # are invoked at base class level as in C++
        if {[info exists variable($fullClass)]} {
            # variable number of arguments in derived class constructor
            foreach fullBase $fullBases($fullClass) {
                if {![info exists constructorArguments($fullBase)]} {
                    error "missing base class $fullBase constructor arguments from class $fullClass constructor"
                }
                set baseConstructor ${fullBase}::[namespace tail $fullBase]
                if {\
                    [info exists variable($fullBase)]&&\
                    ([string first {$args} $constructorArguments($fullBase)]>=0)\
                } {
                    # variable number of arguments in base class constructor and
                    # in derived class base class constructor arguments
                    # use eval so that base class constructor sees arguments
                    # instead of a list
                    # only the last argument of the base class constructor
                    # arguments is considered as a variable list
                    # (it usually is $args but could be a procedure invocation,
                    # such as [filter $args])
                    # fully qualify tcl commands such as set, for they may have
                    #  been redefined within the class namespace
                    append constructorBody \
"::set _list \[::list $constructorArguments($fullBase)\]
::eval $baseConstructor \$this \[::lrange \$_list 0 \[::expr {\[::llength \$_list\]-2}\]\] \[::lindex \$_list end\]
::unset _list
::set ${fullBase}::(\$this,_derived) $fullClass
"
                } else {
                    # no special processing needed
                    # variable number of arguments in base class constructor or
                    # variable arguments list passed as is to base class
                    #  constructor
                    append constructorBody \
"$baseConstructor \$this $constructorArguments($fullBase)
::set ${fullBase}::(\$this,_derived) $fullClass
"
                }
            }
        } else {                                 ;# constant number of arguments
            foreach fullBase $fullBases($fullClass) {
                if {![info exists constructorArguments($fullBase)]} {
                    error "missing base class $fullBase constructor arguments from class $fullClass constructor"
                }
                set baseConstructor ${fullBase}::[namespace tail $fullBase]
                append constructorBody \
"$baseConstructor \$this $constructorArguments($fullBase)
::set ${fullBase}::(\$this,_derived) $fullClass
"
            }
        }
    }                                 ;# else no base class derivation specified
    if {$copy} {
        # for user defined copy constructor, copy derived class member if it
        # exists
        append constructorBody \
"::catch {::set (\$this,_derived) \$(\$[::lindex $arguments 1],_derived)}
"
    }
    # finally append user defined procedure body:
    append constructorBody [lindex $args end]
    if {$copy} {
        _proc ${fullClass}::_copy $arguments $constructorBody
    } else {
        _proc ${fullClass}::$class $arguments $constructorBody
    }
}

_proc ::stooop::destructorDeclaration {fullClass class arguments body} {
    variable check
    variable fullBases

    # setup access to class data
    # since the object identifier is always valid at this point, debugging the
    # procedure is pointless
    set body \
"::variable {}
$check(code)
$body
"
    # if there are any, delete base classes parts in reverse order of
    # construction
    for {set index [expr {[llength $fullBases($fullClass)]-1}]} {$index>=0}\
        {incr index -1}\
    {
        set fullBase [lindex $fullBases($fullClass) $index]
        append body \
"::stooop::deleteObject $fullBase \$this
"
    }
    _proc ${fullClass}::~$class $arguments $body
}

_proc ::stooop::memberProcedureDeclaration {\
    fullClass class procedure arguments body\
} {
    variable check
    variable pureVirtual

    if {[info exists pureVirtual]} {                      ;# virtual declaration
        if {$pureVirtual} {                          ;# pure virtual declaration
            # setup access to class data
            # evaluate derived procedure which must exists. derived procedure
            # return value is automatically returned
            _proc ${fullClass}::$procedure $arguments \
"::variable {}
$check(code)
::uplevel 1 \$(\$this,_derived)::$procedure \[::lrange \[::info level 0\] 1 end\]
"
        } else {                                  ;# regular virtual declaration
            # setup access to class data
            # evaluate derived procedure and return if it exists
            # else evaluate the base class procedure which can be invoked from
            # derived class procedure by prepending _
            _proc ${fullClass}::_$procedure $arguments \
"::variable {}
$check(code)
$body
"
            _proc ${fullClass}::$procedure $arguments \
"::variable {}
$check(code)
if {!\[::catch {::info body \$(\$this,_derived)::$procedure}\]} {
::return \[::uplevel 1 \$(\$this,_derived)::$procedure \[::lrange \[::info level 0\] 1 end\]\]
}
::uplevel 1 ${fullClass}::_$procedure \[::lrange \[::info level 0\] 1 end\]
"
        }
    } else {                                          ;# non virtual declaration
        # setup access to class data:
        _proc ${fullClass}::$procedure $arguments \
"::variable {}
$check(code)
$body
"
    }
}

# generate default copy procedure which may be overriden by the user for any
# class layer:
_proc ::stooop::generateDefaultCopyConstructor {fullClass} {
    variable fullBases

    # generate code for cloning base classes layers if there is at least one
    # base class
    foreach fullBase $fullBases($fullClass) {
        append body \
"${fullBase}::_copy \$this \$sibling
"
    }
    append body \
"::stooop::copy $fullClass \$sibling \$this
"
    _proc ${fullClass}::_copy {this sibling} $body
}


if {[llength [array names ::env STOOOP*]]>0} {
    # if one or more environment variables are set, we are in debugging mode

    # gracefully handle multiple sourcing of this file:
    catch {rename ::stooop::class ::stooop::_class}
    # use a new class procedure instead of adding debugging code to existing one
    _proc ::stooop::class {args} {
        variable trace
        variable check

        set class [lindex $args 0]
        if {$check(data)} {
            # check write and unset operations on empty named array holding
            # class data
            uplevel 1 namespace eval $class\
                [list {::trace variable {} wu ::stooop::checkData}]
        }
        if {[info exists ::env(STOOOPTRACEDATA)]} {
            # trace write and unset operations on empty named array holding
            # class data
            uplevel 1 namespace eval $class [list\
                "::trace variable {} $trace(dataOperations) ::stooop::traceData"\
            ]
        }
        uplevel 1 ::stooop::_class $args
    }

    if {$::stooop::check(procedures)} {
        # prevent the creation of any object of a pure interface class
        # use a new virtual procedure instead of adding debugging code to
        # existing one
        # gracefully handle multiple sourcing of this file:
        catch {rename ::stooop::virtual ::stooop::_virtual}
        # keep track of interface classes (which have at least 1 pure virtual
        # procedure):
        _proc ::stooop::virtual {keyword name arguments args} {
            variable interface

            uplevel 1 ::stooop::_virtual [list $keyword $name $arguments] $args
            parseProcedureName [uplevel 1 namespace current] $name\
                fullClass procedure message
            if {[llength $args]==0} {    ;# no procedure body means pure virtual
                set interface($fullClass) {}
            }
        }
    }

    if {$::stooop::check(objects)} {
        _proc invokingProcedure {} {
            if {[catch {set procedure [lindex [info level -2] 0]}]} {
                # no invoking procedure
                return {top level}
            } elseif {\
                ([string length $procedure]==0)||\
                [string equal $procedure namespace]\
            } {                                 ;# invoked from a namespace body
                return "namespace [uplevel 2 namespace current]"
            } else {
                # store fully qualified name, visible from creator procedure
                # invoking procedure
                return [uplevel 3 namespace which -command $procedure]
            }
        }
    }

    if {$::stooop::check(procedures)||$::stooop::check(objects)} {
        # gracefully handle multiple sourcing of this file:
        catch {rename ::stooop::new ::stooop::_new}
        # use a new new procedure instead of adding debugging code to existing
        # one:
        _proc ::stooop::new {classOrId args} {
            variable newId
            variable check

            if {$check(procedures)} {
                variable fullClass
                variable interface
            }
            if {$check(objects)} {
                variable creator
            }
            if {$check(procedures)} {
                if {[string is integer $classOrId]} {
                    # first argument is an object identifier
                    # class code, if from a package, must already be loaded
                    set fullName $fullClass($classOrId)
                } else {                            ;# first argument is a class
                    # generate constructor name:
                    set constructor ${classOrId}::[namespace tail $classOrId]
                    # force loading in case class is in a package so namespace
                    # commands work properly:
                    catch {$constructor}
                    set fullName [namespace qualifiers\
                        [uplevel 1 namespace which -command $constructor]\
                    ]
                    # anticipate full class name storage in original new{} in
                    # order to avoid invalid object identifier error in
                    # checkProcedure{} when member procedure is invoked from
                    # within contructor, in which case full class name would
                    # have yet to be stored.
                    set fullClass([expr {$newId+1}]) $fullName
                    # new identifier is really incremented in original new{}
                }
                if {[info exists interface($fullName)]} {
                    error "class $fullName with pure virtual procedures should not be instanciated"
                }
            }
            if {$check(objects)} {
                # keep track of procedure in which creation occured (new
                # identifier is really incremented in original new{})
                set creator([expr {$newId+1}]) [invokingProcedure]
            }
            return [uplevel 1 ::stooop::_new $classOrId $args]
        }
    }

    if {$::stooop::check(objects)} {
        _proc ::stooop::delete {args} {
            variable fullClass
            variable deleter

            # keep track of procedure in which deletion occured:
            set procedure [invokingProcedure]
            foreach id $args {
                uplevel 1 ::stooop::deleteObject $fullClass($id) $id
                unset fullClass($id)
                set deleter($id) $procedure
            }
        }
    }

    # return the unsorted list of ancestors in class hierarchy:
    _proc ::stooop::ancestors {fullClass} {
        variable ancestors                         ;# use a cache for efficiency
        variable fullBases

        if {[info exists ancestors($fullClass)]} {
            return $ancestors($fullClass)                  ;# found in the cache
        }
        set list {}
        foreach class $fullBases($fullClass) {
            set list [concat $list [list $class] [ancestors $class]]
        }
        set ancestors($fullClass) $list                         ;# save in cache
        return $list
    }

    # since this procedure is always invoked from a debug procedure, take the
    # extra level in the stack frame into account
    # parameters (passed as references) that cannot be determined are not set
    _proc ::stooop::debugInformation {\
        className fullClassName procedureName fullProcedureName\
        thisParameterName\
    } {
        upvar 1 $className class $fullClassName fullClass\
            $procedureName procedure $fullProcedureName fullProcedure\
            $thisParameterName thisParameter
        variable declared

        set namespace [uplevel 2 namespace current]
        # not in a class namespace:
        if {[lsearch -exact [array names declared] $namespace]<0} return
        # remove redundant global qualifier:
        set fullClass [string trimleft $namespace :]
        set class [namespace tail $fullClass]                      ;# class name
        set list [info level -2]
        set first [lindex $list 0]
        if {([llength $list]==0)||[string equal $first namespace]}\
            return                     ;# not in a procedure, nothing else to do
        set procedure $first
        # procedure must be known at the invoker level:
        set fullProcedure [uplevel 3 namespace which -command $procedure]
        set procedure [namespace tail $procedure]        ;# strip procedure name
        if {[string equal $class $procedure]} {                   ;# constructor
            set procedure constructor
        } elseif {[string equal ~$class $procedure]} {             ;# destructor
            set procedure destructor
        }
        if {[string equal [lindex [info args $fullProcedure] 0] this]} {
            # non static procedure
            # object identifier is first argument:
            set thisParameter [lindex $list 1]
        }
    }

    # check that member procedure is valid for object passed as parameter:
    _proc ::stooop::checkProcedure {} {
        variable fullClass

        debugInformation class qualifiedClass procedure qualifiedProcedure this
        # static procedure, no checking possible:
        if {![info exists this]} return
        # in constructor, checking useless since object is not yet created:
        if {[string equal $procedure constructor]} return
        if {![info exists fullClass($this)]} {
            error "$this is not a valid object identifier"
        }
        set fullName [string trimleft $fullClass($this) :]
        # procedure and object classes match:
        if {[string equal $fullName $qualifiedClass]} return
        # restore global qualifiers to compare with internal full class array
        # data
        if {[lsearch -exact [ancestors ::$fullName] ::$qualifiedClass]<0} {
            error "class $qualifiedClass of $qualifiedProcedure procedure not an ancestor of object $this class $fullName"
        }
    }

    # gather current procedure data, perform substitutions and output to trace
    # channel:
    _proc ::stooop::traceProcedure {} {
        variable trace

        debugInformation class qualifiedClass procedure qualifiedProcedure this
        # all debug data is available since we are for sure in a class procedure
        set text $trace(procedureFormat)
        regsub -all %C $text $qualifiedClass text  ;# fully qualified class name
        regsub -all %c $text $class text
        # fully qualified procedure name:
        regsub -all %P $text $qualifiedProcedure text
        regsub -all %p $text $procedure text
        if {[info exists this]} {                        ;# non static procedure
            regsub -all %O $text $this text
            # remaining arguments:
            regsub -all %a $text [lrange [info level -1] 2 end] text
        } else {                                             ;# static procedure
            regsub -all %O $text {} text
            # remaining arguments:
            regsub -all %a $text [lrange [info level -1] 1 end] text
        }
        puts $trace(procedureChannel) $text
    }

    # check that class data member is accessed within procedure of identical
    # class
    # then if procedure is not static, check that only data belonging to the
    # object passed as parameter is accessed
    _proc ::stooop::checkData {array name operation} {
        scan $name %u,%s identifier member
        # ignore internally defined members:
        if {[info exists member]&&[string equal $member _derived]} return

        debugInformation class qualifiedClass procedure qualifiedProcedure this
        # no checking can be done outside of a class namespace:
        if {![info exists class]} return
        # determine array full name:
        set array [uplevel 1 [list namespace which -variable $array]]
        if {![info exists procedure]} {              ;# inside a class namespace
            # compare with empty named array fully qualified name:
            if {![string equal $array ::${qualifiedClass}::]} {
                # trace command error message is automatically prepended and
                # indicates operation
                error\
                    "class access violation in class $qualifiedClass namespace"
            }
            return                                                       ;# done
        }
        # ignore internal copy procedure:
        if {[string equal $qualifiedProcedure ::stooop::copy]} return
        if {![string equal $array ::${qualifiedClass}::]} {
            # compare with empty named array fully qualified name
            # trace command error message is automatically prepended and
            # indicates operation
            error "class access violation in procedure $qualifiedProcedure"
        }
        # static procedure, all objects can be accessed:
        if {![info exists this]} return
        # static data members can be accessed:
        if {![info exists identifier]} return
        # check that accessed data belongs to this object:
        if {$this!=$identifier} {
            error "object $identifier access violation in procedure $qualifiedProcedure acting on object $this"
        }
    }

    # gather accessed data member information, perform substitutions and output
    # to trace channel
    _proc ::stooop::traceData {array name operation} {
        variable trace

        scan $name %u,%s identifier member
        # ignore internally defined members:
        if {[info exists member]&&[string equal $member _derived]} return

        # ignore internal destruction:
        if {\
            ![catch {lindex [info level -1] 0} procedure]&&\
            [string equal ::stooop::deleteObject $procedure]\
        } return
        set class {}                           ;# in case we are outside a class
        set qualifiedClass {}
        set procedure {}             ;# in case we are outside a class procedure
        set qualifiedProcedure {}

        debugInformation class qualifiedClass procedure qualifiedProcedure this
        set text $trace(dataFormat)
        regsub -all %C $text $qualifiedClass text  ;# fully qualified class name
        regsub -all %c $text $class text
        if {[info exists member]} {
            regsub -all %m $text $member text
        } else {
            regsub -all %m $text $name text                     ;# static member
        }
        # fully qualified procedure name:
        regsub -all %P $text $qualifiedProcedure text
        regsub -all %p $text $procedure text
        # fully qualified array name with global qualifiers stripped:
        regsub -all %A $text [string trimleft\
            [uplevel 1 [list namespace which -variable $array]] :\
        ] text
        if {[info exists this]} {                        ;# non static procedure
            regsub -all %O $text $this text
        } else {                                             ;# static procedure
            regsub -all %O $text {} text
        }
        array set string {r read w write u unset}
        regsub -all %o $text $string($operation) text
        if {[string equal $operation u]} {
            regsub -all %v $text {} text              ;# no value when unsetting
        } else {
            regsub -all %v $text [uplevel 1 set ${array}($name)] text
        }
        puts $trace(dataChannel) $text
    }

    if {$::stooop::check(objects)} {
        # print existing objects along with creation procedure, with optional
        # class pattern (see the string Tcl command manual)
        _proc ::stooop::printObjects {{pattern *}} {
            variable fullClass
            variable creator

            puts "stooop::printObjects invoked from [invokingProcedure]:"
            foreach id [lsort -integer [array names fullClass]] {
                if {[string match $pattern $fullClass($id)]} {
                    puts "$fullClass($id)\($id\) + $creator($id)"
                }
            }
        }

        # record all existing objects for later report:
        _proc ::stooop::record {} {
            variable fullClass
            variable checkpointFullClass

            puts "stooop::record invoked from [invokingProcedure]"
            catch {unset checkpointFullClass}
            array set checkpointFullClass [array get fullClass]
        }

        # print all new or deleted object since last record, with optional class
        # pattern:
        _proc ::stooop::report {{pattern *}} {
            variable fullClass
            variable checkpointFullClass
            variable creator
            variable deleter

            puts "stooop::report invoked from [invokingProcedure]:"
            set checkpointIds [lsort -integer [array names checkpointFullClass]]
            set currentIds [lsort -integer [array names fullClass]]
            foreach id $currentIds {
                if {\
                    [string match $pattern $fullClass($id)]&&\
                    ([lsearch -exact $checkpointIds $id]<0)\
                } {
                    puts "+ $fullClass($id)\($id\) + $creator($id)"
                }
            }
            foreach id $checkpointIds {
                if {\
                    [string match $pattern $checkpointFullClass($id)]&&\
                    ([lsearch -exact $currentIds $id]<0)\
                } {
                    puts "- $checkpointFullClass($id)\($id\) - $deleter($id) + $creator($id)"
                }
            }
        }
    }

}
