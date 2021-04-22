# -*- tcl -*-
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>

# Parser for doctoc formatted input. The result is a struct::tree
# repesenting the contents of the document in a structured form.

# - root = table, attributes for title and label.
# - children of the root  = if any, elements of the table, references and divisions.
# - children of divisions = if any, elements of the division, references and divisions.
#
# The order of the elements under root, and of the elements under
# their division reflects the order of the information in the parsed
# document.

# Attributes in the nodes, except root provide location information,
# i.e. referring from there in the input the information is coming from
# (human-readable output: line/col for end of token, offset start/end
# for range covered by token.

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.4                  ; # Required runtime.
package require doctools::toc::structure ; # Parse Tcl script, like subst.
package require doctools::msgcat         ; # Error message L10N
package require doctools::tcl::parse     ; # Parse Tcl script, like subst.
package require fileutil                 ; # Easy loading of files.
package require logger                   ; # User feedback.
package require snit                     ; # OO system.
package require struct::list             ; # Assign
package require struct::tree             ; # Internal syntax tree

# # ## ### ##### ######## ############# #####################
##

logger::initNamespace ::doctools::toc::parse
snit::type            ::doctools::toc::parse {
    # # ## ### ##### ######## #############
    ## Public API

    typemethod file {path} {
	log::debug [list $type file]
	return [$type text [fileutil::cat $path] $path]
    }

    typemethod text {text {path {}}} {
	log::debug [list $type text]

	set ourfile $path

	array set vars [array get ourvars]
	array set _file {}
	ClearErrors

	set t [struct::tree AST]

	Process $t $text [$t rootname] vars _file
	StopOnErrors

	ReshapeTree $t
	StopOnErrors

	set serial [Serialize $t]
	StopOnErrors

	$t destroy
	return $serial
    }

    # # ## ### ##### ######## #############
    ## Manage symbol table (vset variables).

    typemethod vars {} {
	return [array get ourvars]
    }

    typemethod {var set} {name value} {
	set ourvars($name) $value
	return
    }

    typemethod {var load} {dict} {
	array set ourvars $dict
	return
    }

    typemethod {var unset} {args} {
	if {![llength $args]} { lappend args * }
	foreach pattern $args {
	    array unset ourvars $pattern
	}
	return
    }

    # # ## ### ##### ######## #############
    ## Manage search paths for include files.

    typemethod includes {} {
	return $ourincpaths
    }

    typemethod {include set} {paths} {
	set ourincpaths [lsort -uniq $paths]
	return
    }

    typemethod {include add} {path} {
	lappend ourincpaths $path
	set     ourincpaths [lsort -uniq $ourincpaths]
	return
    }

    typemethod {include remove} {path} {
	set pos [lsearch $ourincpaths $path]
	if {$pos < 0} return
	set  ourincpaths [lreplace $ourincpaths $pos $pos]
	return
    }

    typemethod {include clear} {} {
	set ourincpaths {}
	return
    }

    # # ## ### ##### ######## #############

    proc Process {t text root vv fv} {
	upvar 1 $vv vars $fv _file

	DropChildren $t $root

	# Phase 1. Generate the basic syntax tree

	if {[catch {
	    doctools::tcl::parse text $t $text $root
	} msg]} {
	    if {![string match {doctools::tcl::parse *} $::errorCode]} {
		# Not a parse error, rethrow.
		return \
		    -code      error \
		    -errorcode $::errorCode \
		    -errorinfo $::errorInfo \
		    $msg
	    }

	    # Parse error, low-level syntax breakdown, extract the
	    # machine-info from the errorCode, and report internally.
	    # See the documentation of doctools::tcl::parse for the
	    # definition of the format.
	    struct::list assign $::errorCode _ msg pos line col
	    # msg in {eof, char}
	    ReportAt $_file($root) [list $pos $pos] $line $col doctoc/$msg/syntax {}
	    return 0
	}

	#doctools::parse::tcl::ShowTreeX $t {Raw Result}

	# Phase 2. Check for errors.

	CheckBasicConstraints  $t $root      _file
	ResolveVarsAndIncludes $t $root vars _file
	return 1
    }

    proc CheckBasicConstraints {t root fv} {
	::variable ourfile
	upvar 1 $fv _file

	# Bottom-up walk through the nodes starting at the current
	# root.

	$t walk $root -type dfs -order pre n {
	    # Ignore the root node itself. Except for one thing: The
	    # path information is remembered for the root as well.

	    set _file($n) $ourfile
	    #puts "_file($n) = $ourfile"
	    if {$n eq $root} continue

	    switch -exact [$t get $n type] {
		Text {
		    # Texts at the top level are irrelevant and
		    # removed. They have to contain only whitespace as
		    # well.
		    if {[$t depth $n] == 1} {
			if {[regexp {[^[:blank:]\n]} [$t get $n text]]} {
			    Error $t $n doctoc/plaintext
			}
			MarkDrop $n
		    }
		}
		Word {
		    # Word nodes we ignore. They are just argument
		    # aggregators. They will be gone later, when
		    # reduce arguments to their text form.
		}
		Command {
		    set cmdname [$t get $n text]
		    set parens  [$t parent $n]

		    if {$parens eq $root} {
			set parentt {}
		    } else {
			set parentt [$t get $parens type]
		    }
		    set nested 0

		    if {($parentt eq "Command") || ($parentt eq "Word")} {
			# Commands can be children/arguments of other
			# commands only in very restricted
			# circumstances => rb, lb, vset/1.
			set nested 1
			if {![Nestable $t $n $cmdname errcmdname] && [Legal $cmdname]} {
			    # Report only legal un-nestable commands.
			    # Illegal commands get their own report,
			    # see below.
			    MakeErrorMsg $t $n doctoc/cmd/nested $errcmdname
			}
		    }

		    if {![Legal $cmdname]} {
			# Deletion is safe because we are walking
			# bottom up. If nested we drop only the
			# children and replace this node with a fake.
			if {$nested} {
			    MakeErrorMsg $t $n doctoc/cmd/illegal $cmdname
			} else {
			    Error $t $n doctoc/cmd/illegal $cmdname
			    MarkDrop $n
			}

			continue
		    }

		    # Check arguments of the legal commands only.
		    ArgInfo $cmdname min max
		    set argc [llength [$t children $n]]

		    if {$argc < $min} {
			MakeErrorMsg $t $n doctoc/cmd/wrongargs $cmdname $min
		    } elseif {$argc > $max} {
			MakeErrorMsg $t $n doctoc/cmd/toomanyargs $cmdname $max
		    }

		    # Convert the quoting commands for bracket into
		    # equivalent text nodes, and remove comments.
		    if {$cmdname eq "lb"} {
			MakeText $t $n "\["
		    } elseif {$cmdname eq "rb"} {
			MakeText $t $n "\]"
		    } elseif {$cmdname eq "comment"} {
			# Remove comments or replace with error node (nested).
			if {$nested} {
			    MakeError $t $n
			} else {
			    MarkDrop $n
			}
		    }
		}
	    }
	}

	# Kill the nodes marked for removal now that the walker is not
	# accessing them any longer.
	PerformDrop $t

	#doctools::parse::tcl::ShowTreeX $t {Basic Constraints}
	return
    }

    proc ResolveVarsAndIncludes {t root vv fv} {
	upvar 1 $vv vars $fv _file

	# Now resolve include and vset uses ... This has to be done at
	# the same time, as each include may (re)define variables.

	# Bottom-up walk. Children before parent, and from the left =>
	# Nested vset uses are resolved in the proper order.

	$t walk $root -type dfs -order post n {
	    # Ignore the root node itself.
	    if {$n eq $root} continue

	    set ntype [$t get $n type]

	    switch -exact -- $ntype {
		Text - Error {
		    # Ignore these nodes.
		}
		Word {
		    # Children have to be fully converted to Text, or,
		    # in case of trouble, Error. Aggregate the
		    # information.
		    CollapseWord $t $n
		}
		Command {
		    set cmdname [$t get $n text]

		    switch -exact -- $cmdname {
			vset {
			    set argv [$t children $n]
			    switch -exact -- [llength $argv] {
				1 {
				    VariableUse $t $n [lindex $argv 0]
				}
				2 {
				    struct::list assign $argv var val
				    VariableDefine $t $n $var $val
				}
			    }
			    # vset commands at the structural toplevel are
			    # irrelevant and removed.
			    if {[$t depth $n] == 1} {
				MarkDrop $n
			    }
			}
			include {
			    # Pulls vars, _file from this scope
			    ProcessInclude $t $n [lindex [$t children $n] 0]
			}
			default {
			    # For all other commands move the argument
			    # information into an attribute. Errors in
			    # the argument cause the command to conert
			    # into an error.
			    CollapseArguments $t $n
			}
		    }
		}
	    }
	}

	# Kill the nodes marked for removal now that the walker is
	# not accessing them any longer.
	PerformDrop $t

	#doctools::parse::tcl::ShowTreeX $t {Vars/Includes Resolved}
	return
    }

    proc ReshapeTree {t} {
	upvar 1 _file _file

	# We are assuming that there are no illegal commands in the
	# tree, and further that all of lb, rb, vset, comment, and
	# include are gone as well, per the operation of the previous
	# phases (-> CheckBasicConstraints, ResolveVarsAndIncludes).
	# The only commands which can occur here are
	#
	#     toc_begin, toc_end, division_start, division_end, item

	# Grammar:
	#     TOC   := toc_begin ITEMS toc_end
	#     ITEMS := { item | DIV }
	#     DIV   := division_start ITEMS division_end

	# Hand coded LL(1) parser with explicit stack and state
	# machine.

	set root     [$t rootname]
	set children [$t children $root]
	lappend children $root

	$t set $root text <EOF>
	$t set $root range {0 0}
	$t set $root line  1
	$t set $root col   0

	set st    [struct::stack %AUTO%]
	set at    {}
	set state TOC

	foreach n $children {
	    #puts ____[$t get $n text]($n)

	    set cmdname [$t get $n text]
	    #puts <$n>|$cmdname|$state|

	    # We store the location of the last node in the root, for
	    # use when an unexpected eof triggers an error.
	    if {$n ne $root} {
		$t set $root range [$t get $n range]
		$t set $root line  [$t get $n line]
		$t set $root col   [$t get $n col]
	    }

	    # LL(1) parser table. State/Nexttoken determine action and
	    # next state.
	    switch -exact -- [list $state $cmdname] {
		{TOC toc_begin} {
		    # Pull arguments of the proper toc_begin up into
		    # the root. Drop the expected node.
		    $t set $root argv [$t get $n argv]
		    $t delete $n
		    #puts \t/drop/$n
		    # Starting series of toplevel items and divisions.
		    # Destination for movement is root, and we remember
		    # the state.
		    $st push $at
		    $st push $state
		    set at    $root
		    #puts \t/p=$at
		    set state ITEMS
		}
		{ITEMS item} {
		    # Move item to proper parent. Nothing needed to be
		    # done for the toplevel items.
		}
		{ITEMS division_start} -
		{DIV division_start} {
		    # Sub division begins, toplevel or deeper. Mark it
		    # as new movement destination, and remember the
		    # state. Also, do not forget to move it as well.
		    if {$at ne $root} {
			$t move $at end $n
			#puts \t/moveto/$at
		    }
		    $st push $at
		    $st push $state
		    set at $n
		    #puts \t/p=$at
		    set state DIV
		}
		{ITEMS toc_end} {
		    # End of the document reached, with proper closing
		    # of sub divisions and all. Drop the node, and go
		    # to end state
		    set state EOF
		    $t delete $n
		    #puts \t/drop/$n
		}
		{DIV item} {
		    # Move item to proper parent.
		    $t move $at end $n
		    #puts \t/moveto/$at
		}
		{DIV division_end} {
		    # Drop the node, pop the state and restore the
		    # previous state/destination.
		    $t delete $n
		    #puts \t/drop/$n
		    set state [$st pop]
		    set at    [$st pop]
		    #puts \t/p=$at
		}
		{EOF <EOF>} {
		    # Good, really reached the end. Nothing to be
		    # done.
		}
		{TOC division_end} -
		{TOC division_start} -
		{TOC item} -
		{TOC toc_end} {
		    Error $t $n doctoc/toc_begin/missing
		    $t delete $n
		    #puts \t/drop/$n
		}
		{EOF division_start} -
		{ITEMS division_end} -
		{EOF division_end} -
		{EOF item} -
		{ITEMS toc_begin} -
		{EOF toc_begin} -
		{DIV toc_begin} -
		{EOF toc_end} -
		{DIV toc_end} {
		    # TODO ?! Split this, and add message which command was expected.
		    # Unexpected and wrong. The node is dropped.
		    Error $t $n doctoc/$cmdname/syntax
		    $t delete $n
		    #puts \t/drop/$n
		}
		{TOC <EOF>} {
		    Error $t $n doctoc/toc_begin/missing
		}
		{ITEMS <EOF>} {
		    Error $t $n doctoc/toc_end/missing
		}
		{DIV <EOF>} {
		    Error $t $n doctoc/division_end/missing
		}
	    }
	}

	$st destroy

	$t unset $root text
	$t unset $root range
	$t unset $root line
	$t unset $root col

	#doctools::parse::tcl::ShowTreeX $t Shaped/Structure
	return
    }

    proc Serialize {t} {
	upvar 1 _file _file
	# We assume here that the tree is already in the correct
	# shape/structure, i.e. root, children for references and
	# divisions, with divisions possibly having children and well.

	# We now extract the basic information about the table from
	# the tree, do some higher level checking on the elements and
	# return the serialization of the table generated from the
	# extracted data.

	set error 0
	set root [$t rootname]

	# Root delivers toc label and title.
	struct::list assign [$t get $root argv] label title

	set prefix ....
	set items [GetDivision $t $root error]

	if {$error} return
	# Caller will handle the errors.

	## ### ### ### ######### ######### #########
	## The part below is identical to the serialization backend of
	## command 'doctools::toc::structure merge'.

	# Now construct the result, from the inside out, with proper
	# sorting at all levels.

	set serial [list doctools::toc \
			[list \
			     items      $items \
			     label      $label \
			     title      $title]]

	# Caller verify, ensure contract
	#::doctools::toc::structure verify-as-canonical $serial
	return $serial
    }

    proc GetDivision {t root ev} {
	upvar 1 $ev error _file _file
	array set l {} ; # Label counters
	set items {}

	# Each element in the tree
	foreach element [$t children $root] {
	    switch -exact -- [$t get $element text] {
		item {
		    struct::list assign [$t get $element argv] file label desc
		    lappend items [list reference [list \
						       desc  $desc \
						       id    $file \
						       label $label]]
		    lappend l($label) .
		}
		division_start {
		    struct::list assign [$t get $element argv] label file
		    set subitems [GetDivision $t $element error]
		    if {$error} return
		    set res {}
		    if {$file ne {}} {
			lappend res id $file
		    }
		    lappend res \
			items $subitems \
			label $label
		    lappend items [list division $res]
		    lappend l($label) .
		}
	    }
	    if {[llength $l($label)] > 1} {
		MakeErrorMsg $t $element doctoc/redef $label
		set error 1
		return
	    }
	}
	return $items
    }

    # # ## ### ##### ######## #############

    proc CollapseArguments {t n} {
	#puts __CA($n)

	set ok 1
	set argv {}
	foreach ch [$t children $n] {
	    lappend argv [$t get $ch text]
	    if {[$t get $ch type] eq "Error"} {
		set ok 0
		break
	    }
	}
	if {$ok} {
	    $t set $n argv $argv
	    DropChildren $t $n
	} else {
	    MakeError $t $n
	}
	return
    }

    proc CollapseWord {t n} {
	#puts __CW($n)

	set ok 1
	set text {}
	foreach ch [$t children $n] {
	    append text [$t get $ch text]
	    if {[$t get $ch type] eq "Error"} {
		set ok 0
		break
	    }
	}
	if {$ok} {
	    MakeText $t $n $text
	} else {
	    MakeError $t $n
	}
	return
    }

    proc VariableUse {t n var} {
	upvar 1 vars vars _file _file

	# vset/1 - the command returns text information to the
	# caller. Extract the argument data.

	set vartype [$t get $var type]
	set varname [$t get $var text]

	# Remove the now superfluous argument nodes.
	DropChildren $t $n

	if {$vartype eq "Error"} {
	    # First we check if the command is in trouble because it
	    # has a bogus argument. If so we convert it into an error
	    # node to signal even higher commands, and ignore it. We
	    # do not report an error, as the actual problem was
	    # reported already.

	    MakeError $t $n
	} elseif {![info exists vars($varname)]} {
	    # Secondly we check if the referenced variable is
	    # known. If not it is trouble, and we report it.

	    MakeErrorMsg $t $n doctoc/vset/varname/unknown $varname
	} elseif {[$t depth $n] == 1} {
	    # Commands at the structural toplevel are irrelevant and
	    # removed (see caller). They have to checked again however
	    # to see if the use introduced non-whitespace where it
	    # should not be.

	    if {[regexp {[^[:blank:]\n]} $vars($varname)]} {
		Error $t $n doctoc/plaintext
	    }
	} else {
	    MakeText $t $n $vars($varname)
	}
    }

    proc VariableDefine {t n var val} {
	upvar 1 vars vars

	# vset/2 - the command links a variable to a value. Extract
	# the argument data.

	set vartype [$t get $var type]
	set valtype [$t get $val type]
	set varname [$t get $var text]
	set value   [$t get $val text]

	# Remove the now superfluous argument nodes.
	DropChildren $t $n

	if {($vartype eq "Error") || ($valtype eq "Error")} {
	    # First we check if the command is in trouble because it
	    # has one or more bogus arguments. If so we convert it
	    # into an error node to signal even higher commands, and
	    # ignore it. We do not report an error, as the actual
	    # problem was reported already.

	    MakeError $t $n
	    return
	}

	# And save the change to the symbol table we are lugging
	# around during the processing.

	set vars($varname) $value
	return
    }

    proc ProcessInclude {t n path} {
	upvar 1 vars vars _file _file
	::variable ourfile

	# include - the command returns file content and inserts it in
	# the place of the command.  First extract the argument data

	set pathtype [$t get $path type]
	set pathname [$t get $path text]

	# Remove the now superfluous argument nodes.
	DropChildren $t $n

	# Check for problems stemming from other trouble.
	if {$pathtype eq "Error"} {
	    # First we check if the command is in trouble because it
	    # has a bogus argument. If so convert it into an error
	    # node to signal even higher commands, and ignore it. We
	    # do not report an error, as the actual problem was
	    # reported already.

	    MakeError $t $n
	    return
	}

	if {![GetFile $ourfile $pathname text fullpath error emsg]} {
	    switch -exact -- $error {
		notfound { Error $t $n doctoc/include/path/notfound $pathname       }
		notread  { Error $t $n doctoc/include/read-failed   $fullpath $emsg }
	    }
	    MarkDrop $n
	    return
	}

	# Parse the file. This also resolves variables further.

	set currenterrors [GetErrors]
	set currentpath $ourfile
	ClearErrors

	# WIBNI :: Remember the path as relative to the current path.
	set ourfile $fullpath
	if {![Process $t $text $n vars _file]} {

	    set newerrors [GetErrors]
	    SetErrors $currenterrors
	    set ourfile $currentpath
	    Error $t $n doctoc/include/syntax $fullpath $newerrors
	    MarkDrop $n
	    return
	}

	if {![$t numchildren $n]} {
	    # Inclusion did not generate additional content, we can
	    # ignore the command completely.
	    MarkDrop $n
	    return
	}

	# Create marker nodes which show the file entry/exit
	# transitions. Disabled, makes shaping tree structure too
	# complex. And checking the syntax as well, if we wish to have
	# only proper complete structures in an include file. Need
	# proper LR parser for that (is not LL(1)), or maybe even
	# something like earley-aycock for full handling of an
	# ambigous grammar.
	if 0 {
	    set fstart [$t insert $n 0]
	    set fstop  [$t insert $n end]

	    $t set $fstart type Command
	    $t set $fstop  type Command

	    $t set $fstart text include_begin
	    $t set $fstop  text include_end

	    $t set $fstart path $fullpath
	    $t set $fstop  path $fullpath
	}
	# Remove the include command itself, merging its children
	# into the place it occupied in its parent.
	$t cut $n
	return
    }

    # # ## ### ##### ######## #############

    ## Note: The import plugin for doctoc rewrites the 'GetFile'
    ##       command below to make use of an alias provided by the
    ##       plugin manager. This re-enables the ability of this class
    ##       to handle include files which would otherwise be gone due
    ##       to the necessary file operations (exists, isfile,
    ##       readable, open, read) be disallowed by the safe
    ##       environment the plugin operates in.
    ##
    ## Any changes to GetFile have to reviewed for their impact on
    ## doctools::toc::import::doctoc, and possibly ported over.

    proc GetFile {currentfile path dv pv ev mv} {
	upvar 1 $dv data $pv fullpath $ev error $mv emessage
	set data     {}
	set error    {}
	set emessage {}

	# Find the file, or not.
	set fullpath [Locate $path]
	if {$fullpath eq {}} {
	    set fullpath $path
	    set error notfound
	    return 0
	}

	# Read contents, or not.
	if {[catch {
	    set data [fileutil::cat $fullpath]
	} msg]} {
	    set error notread
	    set emessage $msg
	    return 0
	}

	return 1
    }

    proc Locate {path} {
	upvar 1 currentfile currentfile

	if {$currentfile ne {}} {
	    set pathstosearch \
		[linsert $ourincpaths 0 \
		     [file dirname [file normalize $currentfile]]]
	} else {
	    set pathstosearch $ourincpaths
	}

	foreach base $pathstosearch {
	    set try [file join $base $path]
	    if {![file exists $try]} continue
	    return $try
	}
	# Nothing found
	return {}
    }

    # # ## ### ##### ######## #############
    ## Management of nodes to kill

    proc MarkDrop {n} {
	::variable ourtokill
	lappend ourtokill $n
	#puts %%mark4kill=$n|[info level -1]
	return
    }

    proc DropChildren {t n} {
	foreach child [$t children $n] {
	    MarkDrop $child
	}
	return
    }

    proc PerformDrop {t} {
	::variable ourtokill
	#puts __PD($t)=<[join $ourtokill ,]>
	foreach n $ourtokill {
	    #puts x($n/[$t exists $n])
	    if {![$t exists $n]} continue
	    #puts ^^DEL($n)
	    $t delete $n
	}
	set ourtokill {}
	return
    }

    # # ## ### ##### ######## #############
    ## Command predicates

    proc Nestable {t n cmdname cv} {
	upvar 1 $cv outname
	set outname $cmdname
	switch -exact -- $cmdname {
	    lb - rb { return 1 }
	    vset {
		if {[$t numchildren $n] == 1} {
		    return 1
		}
		append outname /2
	    }
	}
	return 0
    }

    proc Legal {cmdname} {
	::variable ourcmds
	#parray ourcmds
	return [info exists ourcmds($cmdname)]
    }

    proc ArgInfo {cmdname minv maxv} {
	::variable ourcmds
	upvar 1 $minv min $maxv max
	foreach {min max} $ourcmds($cmdname) break
	return
    }

    # # ## ### ##### ######## #############
    ## Higher level error handling, node conversion.

    proc MakeError {t n} {
	#puts %%error=$n|[info level -1]
	$t set $n type Error
	DropChildren $t $n
	return
    }

    proc MakeErrorMsg {t n msg args} {
	upvar 1 _file _file
	#puts %%error=$n|[info level -1]
	Report $t $n $msg $args
	$t set $n type Error
	DropChildren $t $n
	return
    }

    proc MakeText {t n text} {
	#puts %%text=$n|[info level -1]
	$t set $n type Text
	$t set $n text $text
	DropChildren $t $n
	return
    }

    # # ## ### ##### ######## #############
    ## Error reporting

    proc Error {t n text args} {
	upvar 1 _file _file
	Report $t $n $text $args
    }

    proc Report {t n text details} {
	upvar 1 _file _file
	ReportAt $_file($n) [$t get $n range] [$t get $n line] [$t get $n col] $text $details
	return
    }

    proc ReportAt {file range line col text details} {
	::variable ourerrors
	#puts !![list $file $range $line $col $text $details]/[info level -1]
	lappend ourerrors [list $file $range $line $col $text $details]
	return
    }

    # # ## ### ##### ######## #############
    ## Error Management

    proc ClearErrors {} {
	::variable ourerrors {}
	return
    }

    proc GetErrors {} {
	::variable ourerrors
	return $ourerrors
    }

    proc SetErrors {t} {
	::variable ourerrors $t
	return
    }

    # # ## ### ##### ######## #############
    ## Error Response

    proc StopOnErrors {} {
	::variable ourerrors
	if {![llength $ourerrors]} return

	upvar 1 t t
	$t destroy

	doctools::msgcat::init toc
	set info [SortMessages $ourerrors]
	set msg  [Formatted $info {}]

	return -code error -errorcode $info $msg
    }

    proc Formatted {errors prefix} {
	set lines {}
	foreach err $errors {
	    struct::list assign $err file range line col msg details
	    #8.5: set text [msgcat::mc $msg {*}$details]
	    set text [eval [linsert $details 0 msgcat::mc $msg]]
	    if {![string length $prefix] && [string length $file]} {
		set prefix "\"$file\" "
	    }

	    lappend lines "${prefix}error on line $line.$col: $text"

	    if {$msg eq "doctoc/include/syntax"} {
		struct::list assign $details path moreerrors
		lappend lines [Formatted [SortMessages $moreerrors] "\"$path\": "]
	    }
	}
	return [join $lines \n]
    }

    proc SortMessages {messages} {
	return [lsort -dict -index 0 \
		    [lsort -dict -index 2 \
			 [lsort -dict -index 3 \
			      [lsort -unique $messages]]]]
    }

    # # ## ### ##### ######## #############
    ## Parser state

    # Path to the file currently processed, if known. Empty if not known
    typevariable ourfile {}

    # Array of variables for use by vset. During parsing a local copy
    # is used so that variables set by the document cannot spill back
    # to the parser state.
    typevariable ourvars -array {}

    # List of paths to use when searching for an include file.
    typevariable ourincpaths {}

    # Record of errors found so far. List of 5-tuples containing token
    # range, line, column of firt character after the token, error
    # code, and error arguments, in this order.
    typevariable ourerrors {}

    # List of nodes marked for removal.
    typevariable ourtokill {}

    # Map of legal commands to their min/max number of arguments.
    typevariable ourcmds -array {
	comment        {1 1}
	include        {1 1}
	lb             {0 0}
	rb             {0 0}
	vset           {1 2}

	division_end   {0 0}
	division_start {1 2}
	item           {3 3}
	toc_begin      {2 2}
	toc_end        {0 0}
    }

    # # ## ### ##### ######## #############
    ## Configuration

    pragma -hasinstances   no ; # singleton
    pragma -hastypeinfo    no ; # no introspection
    pragma -hastypedestroy no ; # immortal

    ##
    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
## Ready

package provide doctools::toc::parse 0.1
return
