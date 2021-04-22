# -*- tcl -*-
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>

# Parser for docidx formatted input. The result is a struct::tree
# repesenting the contents of the document in a structured form.

# - root = index, attributes for title and label.
# - children of the root = keys of the index, attribute for keyword.
# - children of the keys = manpage and url references for the key,
#                          attributes for reference and label.
#
# The order of the keywords under root, and of the references under
# their keyword reflects the order of the information in the parsed
# document.

# Attributes in the nodes, except root provide location information,
# i.e. referring from there in the input the information is coming from
# (human-readable output: line/col for end of token, offset start/end
# for range covered by token.

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.4                  ; # Required runtime.
package require doctools::idx::structure ; # Parse Tcl script, like subst.
package require doctools::msgcat         ; # Error message L10N
package require doctools::tcl::parse     ; # Parse Tcl script, like subst.
package require fileutil                 ; # Easy loading of files.
package require logger                   ; # User feedback.
package require snit                     ; # OO system.
package require struct::list             ; # Assign
package require struct::tree             ; # Internal syntax tree

# # ## ### ##### ######## ############# #####################
##

logger::initNamespace ::doctools::idx::parse
snit::type            ::doctools::idx::parse {
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
	    ReportAt $_file($root) [list $pos $pos] $line $col docidx/$msg/syntax {}
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
			    Error $t $n docidx/plaintext
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
			    MakeErrorMsg $t $n docidx/cmd/nested $errcmdname
			}
		    }

		    if {![Legal $cmdname]} {
			# Deletion is safe because we are walking
			# bottom up. If nested we drop only the
			# children and replace this node with a fake.
			if {$nested} {
			    MakeErrorMsg $t $n docidx/cmd/illegal $cmdname
			} else {
			    Error $t $n docidx/cmd/illegal $cmdname
			    MarkDrop $n
			}

			continue
		    }

		    # Check arguments of the legal commands only.
		    ArgInfo $cmdname min max
		    set argc [llength [$t children $n]]

		    if {$argc < $min} {
			MakeErrorMsg $t $n docidx/cmd/wrongargs $cmdname $min
		    } elseif {$argc > $max} {
			MakeErrorMsg $t $n docidx/cmd/toomanyargs $cmdname $max
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
	#     index_begin, index_end, key, manpage, url

	# Grammar:
	#     INDEX := index_begin KEYS index_end
	#     KEYS  := { key ITEMS }
	#     ITEMS := { manpage | url }

	# Hand coded LL(1) parser with explicit state machine. No
	# stack required for this grammar.

	set root     [$t rootname]
	set children [$t children $root]
	lappend children $root

	$t set $root text <EOF>
	$t set $root range {0 0}
	$t set $root line  1
	$t set $root col   0

	set at    {}
	set state INDEX

	foreach n $children {
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
		{INDEX index_begin} {
		    # Pull arguments of the proper index_begin up into
		    # the root. Drop the expected node.
		    $t set $root argv [$t get $n argv]
		    $t delete $n
		    # Starting series of keywwords and their
		    # references. Destination is root, not that it
		    # matters, and we remember the state.
		    set at    $root
		    set state KEYS
		}
		{KEYS key} {
		    # Starting series of references in a keyword.
		    # Destination for movement is this keyword, and we
		    # remember the state.
		    set at    $n
		    set state ITEMS
		}
		{ITEMS index_end} -
		{KEYS index_end} {
		    # End of the document reached, with proper closing
		    # of keys and references. Drop the node, and jump to
		    # the end state
		    set state EOF
		    $t delete $n
		}
		{ITEMS manpage} -
		{ITEMS url} {
		    # Move references to their keyword.
		    $t move $at end $n
		}
		{ITEMS key} {
		    # Move destination of references forward.
		    set at $n
		}
		{EOF <EOF>} {
		    # Good, really reached the end. Nothing to be
		    # done.
		}
		{INDEX index_end} -
		{INDEX key} -
		{INDEX manpage} -
		{INDEX url} -
		{INDEX <EOF>} {
		    Error $t $n docidx/index_begin/missing
		    if {$n ne $root} {
			$t delete $n
		    }
		}
		{KEYS index_begin} -
		{KEYS manpage} -
		{KEYS url} {
		    Error $t $n docidx/key/missing
		    if {$n ne $root} {
			$t delete $n
		    }
		}
		{EOF index_begin} -
		{EOF index_end} -
		{EOF key} -
		{EOF manpage} -
		{EOF url} -
		{ITEMS index_begin} {
		    # TODO ?! Split this, and add message which command was expected.
		    # Unexpected and wrong. The node is dropped.
		    Error $t $n docidx/$cmdname/syntax
		    $t delete $n
		}
		{KEYS <EOF>} -
		{ITEMS <EOF>} {
		    Error $t $n docidx/index_end/missing
		}
	    }
	}

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
	# shape/structure, i.e. of at most depth 2, a root, optionally
	# a series of children for the keywords, and each keyword with
	# an optional series of children for the items, i.e. manpage
	# and url references.

	# We now extract the basic information about the index from
	# the tree, do some higher level checking on the references,
	# and return the serialization of the index generated from the
	# extracted data.

	set error 0
	set root [$t rootname]

	# Root delivers index label and title.
	struct::list assign [$t get $root argv] label title

	array set k {}
	array set r {}

	# Each keyword in the tree
	foreach key [$t children $root] {
	    set kw [lindex [$t get $key argv] 0]
	    set k($kw) {}

	    # Each reference in a key.
	    foreach item [$t children $key] {
		struct::list assign [$t get $item argv] id rlabel
		set rtype [$t get $item text]
		set decl  [list $rtype $rlabel]

		lappend k($kw) $id

		# Checking that all uses of a reference use the same
		# type and label.
		if {[info exists r($id)]} {
		    if {$r($id) ne $decl} {
			struct::list assign $r($id) otype olabel
			MakeErrorMsg $t $item docidx/ref/redef \
			    $id $otype $olabel $rtype $rlabel
			set error 1
		    }
		    continue
		}
		set r($id) $decl
	    }
	}

	if {$error} return
	# Caller will handle the errors.

	## ### ### ### ######### ######### #########
	## The part below is identical to the serialization backend of
	## command 'doctools::idx::structure merge'.

	# Now construct the result, from the inside out, with proper
	# sorting at all levels.

	set keywords {}
	foreach kw [lsort -dict [array names k]] {
	    # Sort references in a keyword by their _labels_.
	    set tmp {}
	    foreach rid $k($kw) { lappend tmp [list $rid [lindex $r($rid) 1]] }
	    set refs {}
	    foreach item [lsort -dict -index 1 $tmp] {
		lappend refs [lindex $item 0]
	    }
	    lappend keywords $kw $refs
	}

	set references {}
	foreach rid [lsort -dict [array names r]] {
	    lappend references $rid $r($rid)
	}

	set serial [list doctools::idx \
			[list \
			     label      $label \
			     keywords   $keywords \
			     references $references \
			     title      $title]]


	# Caller verify, ensure contract
	#::doctools::idx::structure verify-as-canonical $serial
	return $serial
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

	    MakeErrorMsg $t $n docidx/vset/varname/unknown $varname
	} elseif {[$t depth $n] == 1} {
	    # Commands at the structural toplevel are irrelevant and
	    # removed (see caller). They have to checked again however
	    # to see if the use introduced non-whitespace where it
	    # should not be.

	    if {[regexp {[^[:blank:]\n]} $vars($varname)]} {
		Error $t $n docidx/plaintext
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
		notfound { Error $t $n docidx/include/path/notfound $pathname       }
		notread  { Error $t $n docidx/include/read-failed   $fullpath $emsg }
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
	    Error $t $n docidx/include/syntax $fullpath $newerrors
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

    ## Note: The import plugin for docidx rewrites the 'GetFile'
    ##       command below to make use of an alias provided by the
    ##       plugin manager. This re-enables the ability of this class
    ##       to handle include files which would otherwise be gone due
    ##       to the necessary file operations (exists, isfile,
    ##       readable, open, read) be disallowed by the safe
    ##       environment the plugin operates in.
    ##
    ## Any changes to GetFile have to reviewed for their impact on
    ## doctools::idx::import::docidx, and possibly ported over.

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

	doctools::msgcat::init idx
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

	    if {$msg eq "docidx/include/syntax"} {
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
	comment     {1 1}
	include     {1 1}
	lb          {0 0}
	rb          {0 0}
	vset        {1 2}

	index_begin {2 2}
	index_end   {0 0}
	key         {1 1}
	manpage     {2 2}
	url         {2 2}
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

package provide doctools::idx::parse 0.1
return
