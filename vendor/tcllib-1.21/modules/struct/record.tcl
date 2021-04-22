#============================================================
# ::struct::record --
#
#    Implements a container data structure similar to a 'C'
#    structure. It hides the ugly details about keeping the
#    data organized by using a combination of arrays, lists
#    and namespaces.
#
#    Each record definition is kept in a master array
#    (_recorddefn) under the ::struct::record namespace. Each
#    instance of a record is kept within a separate namespace
#    for each record definition. Hence, instances of
#    the same record definition are managed under the
#    same namespace. This avoids possible collisions, and
#    also limits one big global array mechanism.
#
# Copyright (c) 2002 by Brett Schwarz
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# This code may be distributed under the same terms as Tcl.
#
#============================================================
#
####  FIX ERROR MESSAGES SO THEY MAKE SENSE (Wrong args)

namespace eval ::struct {}

namespace eval ::struct::record {

    ##
    ##  array of lists that holds the definition (variables) for each
    ##  record
    ##
    ##  _recorddefn(some_record) var1 var2 var3 ...
    ##
    variable _recorddefn

    ##
    ##  holds the count for each record in cases where the instance is
    ##  automatically generated
    ##
    ##  _count(some_record) 0
    ##

    ## This is not a count, but an id generator. Its value has to
    ## increase monotonicaly.

    variable _count

    ##
    ##  array that holds the defining record's name for each instances
    ##
    ##  _defn(some_instances) name_of_defining_record
    ##
    variable  _defn
    array set _defn {}

    ##
    ##  This holds the defaults for a record definition.  If no
    ##  default is given for a member of a record, then the value is
    ##  assigned to the empty string
    ##
    variable _defaults

    ##
    ##  These are the possible sub commands
    ##
    variable commands
    set commands [list define delete exists show]

    ##
    ##  This keeps track of the level that we are in when handling
    ##  nested records. This is kind of a hack, and probably can be
    ##  handled better
    ##
    set _level 0

    namespace export record
}

#------------------------------------------------------------
# ::struct::record::record --
#
#    main command used to access the other sub commands
#
# Arguments:
#    cmd_   The sub command (i.e. define, show, delete, exists)
#    args   arguments to pass to the sub command
#
# Results:
#  none returned
#------------------------------------------------------------
#
proc ::struct::record::record {cmd_ args} {
    variable commands

    if {[lsearch $commands $cmd_] < 0} {
        error "Sub command \"$cmd_\" is not recognized. Must be [join $commands ,]"
    }

    set cmd_ [string totitle "$cmd_"]
    return [uplevel 1 ::struct::record::${cmd_} $args]

}; # end proc ::struct::record::record


#------------------------------------------------------------
# ::struct::record::Define --
#
#    Used to define a record
#
# Arguments:
#    defn_    the name of the record definition
#    vars_    the variables of the record (as a list)
#    args     instances to be create during definition
#
# Results:
#   Returns the name of the definition during successful
#   creation.
#------------------------------------------------------------
#
proc ::struct::record::Define {defn_ vars_ args} {
    variable _recorddefn
    variable _count
    variable _defaults

    # puts .([info level 0])...

    set defn_ [Qualify $defn_]

    if {[info exists _recorddefn($defn_)]} {
        error "Record definition $defn_ already exists"
    }

    if {[lsearch [info commands] $defn_] >= 0} {
        error "Structure definition name can not be a Tcl command name"
    }

    set _defaults($defn_)   [list]
    set _recorddefn($defn_) [list]

    ##
    ##  Loop through the members of the record
    ##  definition
    ##
    foreach V $vars_ {
        set len [llength $V]
        set D ""

        if {$len == 2} {
	    ##  2 --> there is a default value
	    ##        assigned to the member

            set D [lindex $V 1]
            set V [lindex $V 0]

        } elseif {$len == 3} {
	    ##  3 --> there is a nested record
	    ##        definition given as a member
	    ##  V = ('record' record-name field-name)

            if {![string match "record" "[lindex $V 0]"]} {
                Delete record $defn_
                error "$V is a Bad member for record definition. Definition creation aborted."
            }

            set new [lindex $V 1]
            set new [Qualify $new]
	    # puts .\tchild=$new
            ##
            ##  Right now, there can not be circular records
            ##  so, we abort the creation
            ##
            if {[string match "$defn_" "$new"]} {
		# puts .\tabort
                Delete record $defn_
                error "Can not have circular records. Structure was not created."
            }

            ##
            ##  Will take care of the nested record later
            ##  We just join by :: because this is how it
            ##  use to be declared, so the parsing code
            ##  is already there.
            ##
            set V [join [lrange $V 1 2] "::"]
        }

	# puts .\tfield($V)=default($D)

        lappend _recorddefn($defn_) $V
        lappend _defaults($defn_)   $D
    }

    # Create class command as alias to instance creator.
    uplevel #0 [list interp alias \
		    {} $defn_ \
		    {} ::struct::record::Create $defn_]

    set _count($defn_) 0

    # Create class namespace. This will hold all the instance information.
    namespace eval ::struct::record${defn_} {
        variable values
        variable instances
	variable record

        set instances [list]
    }

    set ::struct::record${defn_}::record $defn_

    ##
    ##    If there were args given (instances), then
    ##    create them now
    ##
    foreach A $args {
        uplevel 1 [list ::struct::record::Create $defn_ $A]
    }

    # puts .=>${defn_}
    return $defn_

}; # end proc ::struct::record::Define


#------------------------------------------------------------
# ::struct::record::Create --
#
#    Creates an instance of a record definition
#
# Arguments:
#    defn_    the name of the record definition
#    inst_    the name of the instances to create
#    args     values to set to the record's members
#
# Results:
#   Returns the name of the instance for a successful creation
#------------------------------------------------------------
#
proc ::struct::record::Create {defn_ inst_ args} {
    variable _recorddefn
    variable _count
    variable _defn
    variable _defaults
    variable _level

    # puts .([info level 0])...

    set inst_ [Qualify "$inst_"]

    ##
    ##    test to see if the record
    ##    definition has been defined yet
    ##
    if {![info exists _recorddefn($defn_)]} {
        error "Structure $defn_ does not exist"
    }

    ##
    ##    if there was no argument given,
    ##    then assume that the record
    ##    variable is automatically
    ##    generated
    ##
    if {[string match "[Qualify #auto]" "$inst_"]} {
        set c $_count($defn_)
        set inst_ [format "%s%s" ${defn_} $_count($defn_)]
        incr _count($defn_)
    }

    ##
    ##    Test to see if this instance is already
    ##    created. This avoids any collisions with
    ##    previously created instances
    ##
    if {[info exists _defn($inst_)]} {
        incr _count($defn_) -1
        error "Instances $inst_ already exists"
    }

    set _defn($inst_) $defn_

    ##
    ##    Initialize record variables to defaults
    ##

    # Create instance command as alias of instance dispatcher.
    uplevel #0 [list interp alias {} ${inst_} {} ::struct::record::Cmd $inst_]

    # Locate manager namespace, i.e. class namespace for new instance
    set nsi [Ns $inst_]
    # puts .\tnsi=$nsi

    # Import the state of the manager namespace
    upvar 0 ${nsi}values    __values
    upvar 0 ${nsi}instances __instances

    set cnt 0
    foreach V $_recorddefn($defn_) D $_defaults($defn_) {

	# puts .\tfield($V)=default($D)

	set __values($inst_,$V) $D

        ##
        ##  Test to see if there is a nested record
        ##
        if {[regexp -- {([\w]*)::([\w]*)} $V -> def inst]} {

            if {$_level == 0} {
                set _level 2
            }

            ##
            ##  This is to guard against if the creation had failed,
            ##  that there isn't any lingering variables/alias around
            ##
            set def [Qualify $def $_level]

            if {![info exists _recorddefn($def)]} {
                Delete inst "$inst_"
                return
            }

            ##
            ##    evaluate the nested record. If there were values for
            ##    the variables passed in, then we assume that the
            ##    value for this nested record is a list corresponding
            ##    the the nested list's variables, and so we pass that
            ##    to the nested record's instantiation.  We then get
            ##    rid of those args for later processing.
            ##
            set cnt_plus [expr {$cnt + 1}]
            set mem [lindex $args $cnt]
            if {![string match "" "$mem"]} {
		if {![string match "-$inst" "$mem"]} {
                    Delete inst "$inst_"
                    error "$inst is not a member of $defn_"
                }
            }
            incr _level
            set narg [lindex $args $cnt_plus]

	    # Create instance of the nested record.
            eval [linsert $narg 0 Create $def ${inst_}.${inst}]

            set args [lreplace $args $cnt $cnt_plus]

            incr _level -1
        } else {
	    # Regular field, not a nested record. Create alias for
	    # field access.
            uplevel #0 [list interp alias \
			    {} ${inst_}.$V \
			    {} ::struct::record::Access $defn_ $inst_ $V]
            incr cnt 2
        }
    }; # end foreach variable

    # Remember new instance.
    lappend __instances $inst_

    # Apply field values handed to the instance constructor.
    foreach {k v} $args {
        Access $defn_ $inst_ [string trimleft "$k" -] $v
    }; # end foreach arg {}

    if {$_level == 2} {
	set _level 0
    }

    # puts .=>${inst_}
    return $inst_

}; # end proc ::struct::record::Create


#------------------------------------------------------------
# ::struct::record::Access --
#
#    Provides a common proc to access the variables
#    from the aliases create for each variable in the record
#
# Arguments:
#    defn_    the name of the record to access
#    inst_    the name of the instance to create
#    var_     the variable of the record to access
#    args     a value to set to var_ (if any)
#
# Results:
#    Returns the value of the record member (var_)
#------------------------------------------------------------
#
proc ::struct::record::Access {defn_ inst_ var_ args} {

    variable _recorddefn
    variable _defn

    set i [lsearch $_recorddefn($defn_) $var_]

    if {$i < 0} {
	error "$var_ does not exist in record $defn_"
    }

    if {![info exists _defn($inst_)]} {

	error "$inst_ does not exist"
    }

    if {[set idx [lsearch $args "="]] >= 0} {
        set args [lreplace $args $idx $idx]
    }

    set nsi [Ns $inst_]
    # puts .\tnsi=$nsi

    # Import the state of the manager namespace
    upvar 0 ${nsi}values    __values

    ##
    ##    If a value was given, then set it
    ##
    if {[llength $args] != 0} {

        set val_ [lindex $args 0]

        set __values($inst_,$var_) $val_
    }

    return $__values($inst_,$var_)

}; # end proc ::struct::record::Access


#------------------------------------------------------------
# ::struct::record::Cmd --
#
#    Used to process the set/get requests.
#
# Arguments:
#    inst_    the record instance name
#    args     For 'get' this is the record members to
#             retrieve. For 'set' this is a member/value
#             pair.
#
# Results:
#   For 'set' returns the empty string. For 'get' it returns
#   the member values.
#------------------------------------------------------------
#
proc ::struct::record::Cmd {inst_ args} {

    variable _defn

    set result [list]

    set len [llength $args]
    if {$len <= 1} {return [Show values "$inst_"]}

    set cmd [lindex $args 0]

    if {[string match "cget" "$cmd"]} {

	set cnt 0
	foreach k [lrange $args 1 end] {
	    if {[catch {set r [${inst_}.[string trimleft ${k} -]]} err]} {
		error "Bad option \"$k\""
	    }

	    lappend result $r
	    incr cnt
	}
	if {$cnt == 1} {set result [lindex $result 0]}
	return $result

    } elseif {[string match "config*" "$cmd"]} {

	set L [lrange $args 1 end]
	foreach {k v} $L {
	    ${inst_}.[string trimleft ${k} -] $v
	}

    } else {
	error "Wrong argument.
            must be \"object cget|configure args\""
    }

    return [list]

}; # end proc ::struct::record::Cmd


#------------------------------------------------------------
# ::struct::record::Ns --
#
#    This just constructs a fully qualified namespace for a
#    particular instance.
#
# Arguments;
#    inst_    instance to construct the namespace for.
#
# Results:
#    Returns the fully qualified namespace for the instance
#------------------------------------------------------------
#
proc ::struct::record::Ns {inst_} {

    variable _defn

    if {[catch {set ret $_defn($inst_)} err]} {
        return $inst_
    }

    return [format "%s%s%s" "::struct::record" $ret "::"]

}; # end proc ::struct::record::Ns


#------------------------------------------------------------
# ::struct::record::Show --
#
#     Display info about the record that exist
#
# Arguments:
#    what_    subcommand
#    record_  record or instance to process
#
# Results:
#    if what_ = record, then return list of records
#               definition names.
#    if what_ = members, then return list of members
#               or members of the record.
#    if what_ = instance, then return a list of instances
#               with record definition of record_
#    if what_ = values, then it will return the values
#               for a particular instance
#------------------------------------------------------------
#
proc ::struct::record::Show {what_ {record_ ""}} {
    variable _recorddefn
    variable _defn
    variable _defaults

    set record_ [Qualify $record_]

    ##
    ## We just prepend :: to the record_ argument
    ##
    #if {![string match "::*" "$record_"]} {set record_ "::$record_"}

    if {[string match "record*" "$what_"]} {
	# Show record

        return [lsort [array names _recorddefn]]
    }

    if {[string match "mem*" "$what_"]} {
	# Show members

	if {[string match "" "$record_"] || ![info exists _recorddefn($record_)]} {
	    error "Bad arguments while accessing members. Bad record name"
	}

	set res [list]
	set cnt 0
	foreach m $_recorddefn($record_) {
	    set def [lindex $_defaults($record_) $cnt]
	    if {[regexp -- {([\w]+)::([\w]+)} $m m d i]} {
		lappend res [list record $d $i]
	    } elseif {![string match "" "$def"]} {
		lappend res [list $m $def]
	    } else {
		lappend res $m
	    }

	    incr cnt
	}

	return $res
    }

    if {[string match "inst*" "$what_"]} {
	# Show instances

	if {![namespace exists ::struct::record${record_}]} {
	    return [list]
	}

	# Import the state of the manager namespace
	upvar 0 ::struct::record${record_}::instances __instances

        if {![info exists __instances]} {
            return [list]
        }
        return [lsort $__instances]

    }

    if {[string match "val*" "$what_"]} {
	# Show values

	set nsi [Ns $record_]
	upvar 0 ${nsi}::instances __instances
	upvar 0 ${nsi}::values    __values
	upvar 0 ${nsi}::record    __record

	if {[string match "" "$record_"] ||
	    ([lsearch $__instances $record_] < 0)} {

	    error "Wrong arguments to values. Bad instance name"
	}

	set ret [list]
	foreach k $_recorddefn($__record) {
	    set v $__values($record_,$k)

	    if {[regexp -- {([\w]*)::([\w]*)} $k m def inst]} {
		set v [::struct::record::Show values ${record_}.${inst}]
	    }

	    lappend ret -[namespace tail $k] $v
	}
	return $ret

    }

    # Bogus submethod
    return [list]

}; # end proc ::struct::record::Show


#------------------------------------------------------------
# ::struct::record::Delete --
#
#    Deletes a record instance or a record definition
#
# Arguments:
#    sub_    what to delete. Either 'instance' or 'record'
#    item_   the specific record instance or definition
#            delete.
#
# Returns:
#    none
#
#------------------------------------------------------------
#
proc ::struct::record::Delete {sub_ item_} {
    variable _recorddefn
    variable _defn
    variable _count
    variable _defaults

    # puts .([info level 0])...

    set item_ [Qualify $item_]

    switch -- $sub_ {
        instance -
        instances -
        inst    {
	    # puts .instance
	    # puts .is-instance=[Exists instance $item_]

            if {[Exists instance $item_]} {

		# Locate manager namespace, i.e. class namespace for
		# instance to remove
		set nsi [Ns $item_]
		# puts .\tnsi=$nsi

		# Import the state of the manager namespace
		upvar 0 ${nsi}values    __values
		upvar 0 ${nsi}instances __instances
		upvar 0 ${nsi}record    __record
		# puts .\trecord=$__record

		# Remove instance from state
		set i [lsearch $__instances $item_]
		set __instances [lreplace $__instances $i $i]
		unset _defn($item_)

		# Process instance fields.

		foreach V $_recorddefn($__record) {
		    # puts .\tfield($V)=/clear

		    if {[regexp -- {([\w]*)::([\w]*)} $V m def inst]} {
			# Nested record detected.
			# Determine associated instance and delete recursively.
			Delete inst ${item_}.${inst}
		    } else {
			# Delete field accessor alias
			# puts .de-alias\t($item_.$V)
			uplevel #0 [list interp alias {} ${item_}.$V {}]
		    }

		    unset __values($item_,$V)
		}

		# Auto-generated id numbers increase monotonically.
		# Reverting here causes the next auto to fail, claiming
		# that the instance exists.
                # incr _count($ns) -1

            } else {
                #error "$item_ is not a instance"
            }
        }
        record  -
        records   {
	    # puts .record
            ##
            ##  Delete the instances for this
            ##  record
            ##
	    # puts .get-instances
            foreach I [Show instance "$item_"] {
                catch {
		    # puts .di/$I
		    Delete instance "$I"
		}
            }

            catch {
                unset _recorddefn($item_)
                unset _defaults($item_)
                unset _count($item_)
                namespace delete ::struct::record${item_}
            }
        }
        default   {
            error "Wrong arguments to delete"
        }

    }; # end switch

    # Remove alias associated with instance or record (class)
    # puts .de-alias\t($item_)
    catch { uplevel #0 [list interp alias {} $item_ {}]}

    # puts ./
    return

}; # end proc ::struct::record::Delete


#------------------------------------------------------------
# ::struct::record::Exists --
#
#    Tests whether a record definition or record
#    instance exists.
#
# Arguments:
#    sub_    what to test. Either 'instance' or 'record'
#    item_   the specific record instance or definition
#            that needs to be tested.
#
# Tests to see if a particular instance exists
#
#------------------------------------------------------------
#
proc ::struct::record::Exists {sub_ item_} {

    # puts .([info level 0])...

    set item_ [Qualify $item_]

    switch -glob -- $sub_ {
        inst* {
	    variable _defn
            return [info exists _defn($item_)]
        }
        record {
	    variable _recorddefn
            return [info exists _recorddefn($item_)]
        }
        default  {
            error "Wrong arguments. Must be exists record|instance target"
        }
    }; # end switch

}; # end proc ::struct::record::Exists


#------------------------------------------------------------
# ::struct::record::Qualify --
#
#    Contructs the qualified name of the calling scope. This
#    defaults to 2 levels since there is an extra proc call in
#    between.
#
# Arguments:
#    item_   the command that needs to be qualified
#    level_  how many levels to go up (default = 2)
#
# Results:
#    the item_ passed in fully qualified
#
#------------------------------------------------------------
#
proc ::struct::record::Qualify {item_ {level_ 2}} {
    if {![string match "::*" "$item_"]} {
        set ns [uplevel $level_ [list namespace current]]

        if {![string match "::" "$ns"]} {
            append ns "::"
        }

        set item_ "$ns${item_}"
    }

    return "$item_"

}; # end proc ::struct::record::Qualify

# ### ### ### ######### ######### #########
## Ready

namespace eval ::struct {
    # Get 'record::record' into the general structure namespace.
    namespace import -force record::record
    namespace export record
}

package provide struct::record 1.2.2
return
