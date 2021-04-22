
namespace eval ::struct::list::test {}

proc ::struct::list::test::main {} {
	test list-lcs-1.1 {longestCommonSubsequence, no args} {
		catch { lcs } msg
		set msg
	} [tcltest::wrongNumArgs ::struct::list::LlongestCommonSubsequence \
		   {sequence1 sequence2 ?maxOccurs?} 0]

	test list-lcs-1.2 {longestCommonSubsequence, one arg} {
		catch { lcs x } msg
		set msg
	} [tcltest::wrongNumArgs ::struct::list::LlongestCommonSubsequence \
		   {sequence1 sequence2 ?maxOccurs?} 1]

	test list-lcs-2.1 {longestCommonSubsequence, two empty lists} {
		list [catch { lcs {} {} } msg] $msg
	} {0 {{} {}}}

	test list-lcs-2.2 {longestCommonSubsequence, insert 1 into an empty list} {
		list [catch { lcs {} {a} } msg] $msg
	} {0 {{} {}}}

	test list-lcs-2.3 {longestCommonSubsequence, delete 1 from singleton list} {
		list [catch { lcs {a} {} } msg] $msg
	} {0 {{} {}}}

	test list-lcs-2.4 {longestCommonSubsequence, preserve singleton list} {
		list [catch { lcs {a} {a} } msg] $msg
	} {0 {0 0}}

	test list-lcs-2.5 {longestCommonSubsequence, 1-element change in singleton list} {
		list [catch { lcs {a} {b} } msg] $msg
	} {0 {{} {}}}

	test list-lcs-2.6 {longestCommonSubsequence, insert 1 in front of singleton list} {
		list [catch { lcs {a} {b a} } msg] $msg
	} {0 {0 1}}

	test list-lcs-2.7 {longestCommonSubsequence, insert 1 at end of singleton list} {
		list [catch {lcs {a} {a b}} msg] $msg
	} {0 {0 0}}

	test list-lcs-2.8 {longestCommonSubsequence, duplicate element} {
		list [catch {lcs {a} {a a}} msg] $msg
	} {0 {0 0}}

	test list-lcs-2.9 {longestCommonSubsequence, interchange 2} {
		list [catch {lcs {a b} {b a}} msg] $msg
	} {0 {1 0}}

	test list-lcs-2.10 {longestCommonSubsequence, insert before 2} {
		list [catch {lcs {a b} {b a b}} msg] $msg
	} {0 {{0 1} {1 2}}}

	test list-lcs-2.11 {longestCommonSubsequence, insert inside 2} {
		list [catch {lcs {a b} {a a b}} msg] $msg
	} {0 {{0 1} {0 2}}}

	test list-lcs-2.12 {longestCommonSubsequence, insert after 2} {
		list [catch {lcs {a b} {a b a}} msg] $msg
	} {0 {{0 1} {0 1}}}

	test list-lcs-2.13 {longestCommonSubsequence, delete first of 2} {
		list [catch {lcs {a b} b} msg] $msg
	} {0 {1 0}}

	test list-lcs-2.14 {longestCommonSubsequence, delete second of 2} {
		list [catch {lcs {a b} a} msg] $msg
	} {0 {0 0}}

	test list-lcs-2.15 {longestCommonSubsequence, change first of 2} {
		list [catch {lcs {a b} {c b}} msg] $msg
	} {0 {1 1}}

	test list-lcs-2.16 {longestCommonSubsequence, change first of 2 to dupe} {
		list [catch {lcs {a b} {b b}} msg] $msg
	} {0 {1 0}}

	test list-lcs-2.17 {longestCommonSubsequence, change second of 2} {
		list [catch {lcs {a b} {a c}} msg] $msg
	} {0 {0 0}}

	test list-lcs-2.18 {longestCommonSubsequence, change second of 2 to dupe} {
		list [catch {lcs {a b} {a a}} msg] $msg
	} {0 {0 0}}

	test list-lcs-2.19 {longestCommonSubsequence, mixed changes} {
		list [catch {lcs {a b r a c a d a b r a} {b r i c a b r a c}} msg] $msg
	} {0 {{1 2 4 5 8 9 10} {0 1 3 4 5 6 7}}}

	test list-lcs-2.20 {longestCommonSubsequence, mixed changes} {
		list [catch {lcs {b r i c a b r a c} {a b r a c a d a b r a}} msg] $msg
	} {0 {{0 1 3 4 5 6 7} {1 2 4 5 8 9 10}}}

	test list-lcs-3.1 {longestCommonSubsequence, length limit} {
		list [catch {lcs {b r i c a b r a c} {a b r a c a d a b r a} 5} msg] $msg
	} {0 {{0 1 3 4 5 6 7} {1 2 4 5 8 9 10}}}

	test list-lcs-3.2 {longestCommonSubsequence, length limit} {
		list [catch {lcs {b r i c a b r a c} {a b r a c a d a b r a} 4} msg] $msg
	} {0 {{0 1 3 5 6} {1 2 4 8 9}}}

	test list-lcs-3.3 {longestCommonSubsequence, length limit} {
		list [catch {lcs {b r i c a b r a c} {a b r a c a d a b r a} 1} msg] $msg
	} {0 {3 4}}

	test list-lcs-3.4 {longestCommonSubsequence, stupid length limit} {
		list [catch {lcs {b r i c a b r a c} {a b r a c a d a b r a} 0} msg] $msg
	} {0 {{} {}}}


	#----------------------------------------------------------------------

	interp alias {} lcs2 {} ::struct::list::list longestCommonSubsequence2

	test list-lcs2-1.1 {longestCommonSubsequence2, no args} {
		catch { lcs2 } msg
		set msg
	} [tcltest::wrongNumArgs ::struct::list::LlongestCommonSubsequence2 \
		   {sequence1 sequence2 ?maxOccurs?} 0]

	test list-lcs2-1.2 {longestCommonSubsequence2, one arg} {
		catch { lcs2 x } msg
		set msg
	} [tcltest::wrongNumArgs ::struct::list::LlongestCommonSubsequence2 \
		   {sequence1 sequence2 ?maxOccurs?} 1]

	test list-lcs2-2.1 {longestCommonSubsequence2, two empty lists} {
		list [catch { lcs2 {} {} } msg] $msg
	} {0 {{} {}}}

	test list-lcs2-2.2 {longestCommonSubsequence2, insert 1 into an empty list} {
		list [catch { lcs2 {} {a} } msg] $msg
	} {0 {{} {}}}

	test list-lcs2-2.3 {longestCommonSubsequence2, delete 1 from singleton list} {
		list [catch { lcs2 {a} {} } msg] $msg
	} {0 {{} {}}}

	test list-lcs2-2.4 {longestCommonSubsequence2, preserve singleton list} {
		list [catch { lcs2 {a} {a} } msg] $msg
	} {0 {0 0}}

	test list-lcs2-2.5 {longestCommonSubsequence2, 1-element change in singleton list} {
		list [catch { lcs2 {a} {b} } msg] $msg
	} {0 {{} {}}}

	test list-lcs2-2.6 {longestCommonSubsequence2, insert 1 in front of singleton list} {
		list [catch { lcs2 {a} {b a} } msg] $msg
	} {0 {0 1}}

	test list-lcs2-2.7 {longestCommonSubsequence2, insert 1 at end of singleton list} {
		list [catch {lcs2 {a} {a b}} msg] $msg
	} {0 {0 0}}

	test list-lcs2-2.8 {longestCommonSubsequence2, duplicate element} {
		list [catch {lcs2 {a} {a a}} msg] $msg
	} {0 {0 0}}

	test list-lcs2-2.9 {longestCommonSubsequence2, interchange 2} {
		list [catch {lcs2 {a b} {b a}} msg] $msg
	} {0 {1 0}}

	test list-lcs2-2.10 {longestCommonSubsequence2, insert before 2} {
		list [catch {lcs2 {a b} {b a b}} msg] $msg
	} {0 {{0 1} {1 2}}}

	test list-lcs2-2.11 {longestCommonSubsequence2, insert inside 2} {
		list [catch {lcs2 {a b} {a a b}} msg] $msg
	} {0 {{0 1} {0 2}}}

	test list-lcs2-2.12 {longestCommonSubsequence2, insert after 2} {
		list [catch {lcs2 {a b} {a b a}} msg] $msg
	} {0 {{0 1} {0 1}}}

	test list-lcs2-2.13 {longestCommonSubsequence2, delete first of 2} {
		list [catch {lcs2 {a b} a} msg] $msg
	} {0 {0 0}}

	test list-lcs2-2.14 {longestCommonSubsequence2, delete second of 2} {
		list [catch {lcs2 {a b} b} msg] $msg
	} {0 {1 0}}

	test list-lcs2-2.15 {longestCommonSubsequence2, change first of 2} {
		list [catch {lcs2 {a b} {c b}} msg] $msg
	} {0 {1 1}}

	test list-lcs2-2.16 {longestCommonSubsequence2, change first of 2 to dupe} {
		list [catch {lcs2 {a b} {b b}} msg] $msg
	} {0 {1 0}}

	test list-lcs2-2.17 {longestCommonSubsequence2, change second of 2} {
		list [catch {lcs2 {a b} {a c}} msg] $msg
	} {0 {0 0}}

	test list-lcs2-2.18 {longestCommonSubsequence2, change second of 2 to dupe} {
		list [catch {lcs2 {a b} {a a}} msg] $msg
	} {0 {0 0}}

	test list-lcs2-2.19 {longestCommonSubsequence2, mixed changes} {
		list [catch {lcs2 {a b r a c a d a b r a} {b r i c a b r a c}} msg] $msg
	} {0 {{1 2 4 5 8 9 10} {0 1 3 4 5 6 7}}}

	test list-lcs2-2.20 {longestCommonSubsequence2, mixed changes} {
		list [catch {lcs2 {b r i c a b r a c} {a b r a c a d a b r a}} msg] $msg
	} {0 {{0 1 3 4 5 6 7} {1 2 4 5 8 9 10}}}

	test list-lcs2-3.1 {longestCommonSubsequence2, length limit} {
		list [catch {lcs2 {b r i c a b r a c} {a b r a c a d a b r a} 5} msg] $msg
	} {0 {{0 1 3 4 5 6 7} {1 2 4 5 8 9 10}}}

	test list-lcs2-3.2 {longestCommonSubsequence2, length limit} {
		list [catch {lcs2 {b r i c a b r a c} {a b r a c a d a b r a} 4} msg] $msg
	} {0 {{0 1 3 4 5 6 7} {1 2 4 5 8 9 10}}}

	test list-lcs2-3.3 {longestCommonSubsequence2, length limit} {
		list [catch {lcs2 {b r i c a b r a c} {a b r a c a d a b r a} 1} msg] $msg
	} {0 {{0 1 3 4 5 6 7} {1 2 4 5 8 9 10}}}

	test list-lcs2-3.4 {longestCommonSubsequence2, stupid length limit} {
		list [catch {lcs2 {b r i c a b r a c} {a b r a c a d a b r a} 0} msg] $msg
	} {0 {{0 1 3 4 5 6 7} {1 2 4 5 8 9 10}}}


	#----------------------------------------------------------------------

	interp alias {} lcsi  {} ::struct::list::list lcsInvert
	interp alias {} lcsim {} ::struct::list::list lcsInvertMerge

	test list-lcsInv-4.0 {longestCommonSubsequence, mixed changes} {

		# sequence 1 = a b r a c a d a b r a
		# lcs 1      =   1 2   4 5     8 9 10
		# lcs 2      =   0 1   3 4     5 6 7
		# sequence 2 =   b r i c a     b r a c
		#
		# Inversion  = deleted  {0  0} {-1 0}
		#              changed  {3  3}  {2 2}
		#              deleted  {6  7}  {4 5}
		#              added   {10 11}  {8 8}

		list [catch {lcsi [lcs {a b r a c a d a b r a} {b r i c a b r a c}] 11 9} msg] $msg
	} {0 {{deleted {0 0} {-1 0}} {changed {3 3} {2 2}} {deleted {6 7} {4 5}} {added {10 11} {8 8}}}}

	test list-lcsInv-4.1 {longestCommonSubsequence, mixed changes} {

		# sequence 1 = a b r a c a d a b r a
		# lcs 1      =   1 2   4 5     8 9 10
		# lcs 2      =   0 1   3 4     5 6 7
		# sequence 2 =   b r i c a     b r a c
		#
		# Inversion/Merge  = deleted   {0  0} {-1 0}
		#                    unchanged {1  2}  {0 1}
		#                    changed   {3  3}  {2 2}
		#                    unchanged {4  5}  {3 4}
		#                    deleted   {6  7}  {4 5}
		#                    unchanged {8 10}  {5 7}
		#                    added    {10 11}  {8 8}

		list [catch {lcsim [lcs {a b r a c a d a b r a} {b r i c a b r a c}] 11 9} msg] $msg
	} {0 {{deleted {0 0} {-1 0}} {unchanged {1 2} {0 1}} {changed {3 3} {2 2}} {unchanged {4 5} {3 4}} {deleted {6 7} {4 5}} {unchanged {8 10} {5 7}} {added {10 11} {8 8}}}}


	proc diff2 {s1 s2} {
		set l1 [split $s1 {}]
		set l2 [split $s2 {}]
		set x [lcs $l1 $l2]
		lcsim $x [llength $l1] [llength $l2]
	}
	test list-lcsInv-4.2 {lcsInvertMerge} {
		# Handling of 'unchanged' chunks at the beginning of the result
		# (when result actually empty).

		diff2 ab "a b" 
	} {{unchanged {0 0} {0 0}} {added {0 1} {1 1}} {unchanged {1 1} {2 2}}}

	test list-lcsInv-4.3 {lcsInvertMerge} {
		diff2 abcde afcge
	} {{unchanged {0 0} {0 0}} {changed {1 1} {1 1}} {unchanged {2 2} {2 2}} {changed {3 3} {3 3}} {unchanged {4 4} {4 4}}}

	#----------------------------------------------------------------------

	interp alias {} reverse {} ::struct::list::list reverse

	test reverse-1.1 {reverse method} {
		reverse {a b c}
	} {c b a}

	test reverse-1.2 {reverse method} {
		reverse a
	} {a}

	test reverse-1.3 {reverse method} {
		reverse {}
	} {}

	test reverse-2.1 {reverse errors} {
		list [catch {reverse} msg] $msg
	} [list 1 [tcltest::wrongNumArgs ::struct::list::Lreverse {sequence} 0]]

	#----------------------------------------------------------------------

	interp alias {} assign {} ::struct::list::list assign

	test assign-4.1 {assign method} {
		catch {unset ::x ::y}
		list [assign {foo bar} x y] $x $y
	} {{} foo bar}

	test assign-4.2 {assign method} {
		catch {unset x y}
		list [assign {foo bar baz} x y] $x $y
	} {baz foo bar}

	test assign-4.3 {assign method} {
		catch {unset x y z}
		list [assign {foo bar} x y z] $x $y $z
	} {{} foo bar {}}

	if {[package vcompare [package provide Tcl] 8.5] < 0} {
		# 8.4
		set err [tcltest::wrongNumArgs {::struct::list::Lassign} {sequence v args} 1]
	} else {
		# 8.5+
		#set err [tcltest::wrongNumArgs {lassign}                 {list varName ?varName ...?} 1]
		set err [tcltest::wrongNumArgs {::struct::list::Lassign} {list varName ?varName ...?} 1]
	}

	# In 8.6+ assign is the native lassign and it does nothing gracefully,
	# per TIP 323, making assign-4.4 not an error anymore.
	test assign-4.4 {assign method} {!tcl8.6plus} {
		catch {assign {foo bar}} msg ; set msg
	} $err

	test assign-4.5 {assign method} {
		list [assign {foo bar} x] $x
	} {bar foo}

	catch {unset x y z}

	#----------------------------------------------------------------------

	interp alias {} flatten {} ::struct::list::list flatten

	test flatten-1.1 {flatten command} {
		flatten {1 2 3 {4 5} {6 7} {{8 9}} 10}
	} {1 2 3 4 5 6 7 {8 9} 10}

	test flatten-1.2 {flatten command} {
		flatten -full {1 2 3 {4 5} {6 7} {{8 9}} 10}
	} {1 2 3 4 5 6 7 8 9 10}

	test flatten-1.3 {flatten command} {
		flatten {a b}
	} {a b}

	test flatten-1.4 {flatten command} {
		flatten [list "\[a\]" "\[b\]"]
	} {{[a]} {[b]}}

	test flatten-1.5 {flatten command} {
		flatten [list "'" "\""]
	} {' {"}} ; # " help emacs highlighting

	test flatten-1.6 {flatten command} {
		flatten [list "{" "}"]
	} "\\\{ \\\}"

	test flatten-1.7 {check -- argument termination} {
		flatten -full -- {1 2 3 {4 5} {6 7} {{8 9}} 10}
	} {1 2 3 4 5 6 7 8 9 10}

	test flatten-2.1 {flatten errors} {
		list [catch {flatten} msg] $msg
	} {1 {wrong#args: should be "::struct::list::Lflatten ?-full? ?--? sequence"}}

	test flatten-2.2 {flatten errors} {
		list [catch {flatten -all {a {b c d} {e {f g}}}} msg] $msg
	} {1 {Unknown option "-all", should be either -full, or --}}


	#----------------------------------------------------------------------

	interp alias {} map {} ::struct::list::list map

	proc cc {a} {return $a$a}
	proc +  {a} {expr {$a + $a}}
	proc *  {a} {expr {$a * $a}}
	proc projection {n list} {::lindex $list $n}

	test map-4.1 {map command} {
		map {a b c d} cc
	} {aa bb cc dd}

	test map-4.2 {map command} {
		map {1 2 3 4 5} +
	} {2 4 6 8 10}

	test map-4.3 {map command} {
		map {1 2 3 4 5} *
	} {1 4 9 16 25}

	test map-4.4 {map command} {
		map {} *
	} {}

	test map-4.5 {map command} {
		map {{a b c} {1 2 3} {d f g}} {projection 1}
	} {b 2 f}


	#----------------------------------------------------------------------

	interp alias {} mapfor {} ::struct::list::list mapfor

	test mapfor-4.1 {mapfor command} {
		mapfor x {a b c d} { set x $x$x }
	} {aa bb cc dd}

	test mapfor-4.2 {mapfor command} {
		mapfor x {1 2 3 4 5} {expr {$x + $x}}
	} {2 4 6 8 10}

	test mapfor-4.3 {mapfor command} {
		mapfor x {1 2 3 4 5} {expr {$x * $x}}
	} {1 4 9 16 25}

	test mapfor-4.4 {mapfor command} {
		mapfor x {} {expr {$x * $x}}
	} {}

	test mapfor-4.5 {mapfor command} {
		mapfor x {{a b c} {1 2 3} {d f g}} {lindex $x 1}
	} {b 2 f}

	#----------------------------------------------------------------------

	interp alias {} fold {} ::struct::list::list fold

	proc cc {a b} {return $a$b}
	proc +  {a b} {expr {$a + $b}}
	proc *  {a b} {expr {$a * $b}}

	test fold-4.1 {fold command} {
		fold {a b c d} {} cc
	} {abcd}

	test fold-4.2 {fold command} {
		fold {1 2 3 4 5} 0 +
	} {15}

	test fold-4.3 {fold command} {
		fold {1 2 3 4 5} 1 *
	} {120}

	test fold-4.4 {fold command} {
		fold {} 1 *
	} {1}

	#----------------------------------------------------------------------

	interp alias {} filter {} ::struct::list::list filter

	proc even {i} {expr {($i % 2) == 0}}

	test filter-4.1 {filter command} {
		filter {1 2 3 4 5 6 7 8} even
	} {2 4 6 8}

	test filter-4.2 {filter command} {
		filter {} even
	} {}

	test filter-4.3 {filter command} {
		filter {3 5 7} even
	} {}

	test filter-4.4 {filter command} {
		filter {2 4 6} even
	} {2 4 6}

	# Alternate which elements are filtered by using a global variable
	# flag. Used to test that the `cmdprefix' is evaluated in the caller's
	# scope.
	#
	# The flag variable should be set on the -setup phase.

	proc alternating {_} {
		upvar 1 flag flag;
		set flag [expr {!($flag)}];
		return $flag;
	}

	test filter-4.5 {filter evaluates cmdprefix on outer scope} -setup {
		set flag 1
	} -body {
		filter {1 2 3 4 5 6} alternating
	} -cleanup {
		unset flag
	} -result {2 4 6}

	#----------------------------------------------------------------------

	interp alias {} filterfor {} ::struct::list::list filterfor

	test filterfor-4.1 {filterfor command} {
		filterfor i {1 2 3 4 5 6 7 8} {($i % 2) == 0}
	} {2 4 6 8}

	test filterfor-4.2 {filterfor command} {
		filterfor i {} {($i % 2) == 0}
	} {}

	test filterfor-4.3 {filterfor command} {
		filterfor i {3 5 7} {($i % 2) == 0}
	} {}

	test filterfor-4.4 {filterfor command} {
		filterfor i {2 4 6} {($i % 2) == 0}
	} {2 4 6}

	#----------------------------------------------------------------------

	interp alias {} lsplit {} ::struct::list::list split

	proc even {i} {expr {($i % 2) == 0}}

	test split-4.1 {split command} {
		lsplit {1 2 3 4 5 6 7 8} even
	} {{2 4 6 8} {1 3 5 7}}

	test split-4.2 {split command} {
		lsplit {} even
	} {{} {}}

	test split-4.3 {split command} {
		lsplit {3 5 7} even
	} {{} {3 5 7}}

	test split-4.4 {split command} {
		lsplit {2 4 6} even
	} {{2 4 6} {}}

	test split-4.5 {split command} {
		list [lsplit {1 2 3 4 5 6 7 8} even pass fail] $pass $fail
	} {{4 4} {2 4 6 8} {1 3 5 7}}

	test split-4.6 {split command} {
		list [lsplit {} even pass fail] $pass $fail
	} {{0 0} {} {}}

	test split-4.7 {split command} {
		list [lsplit {3 5 7} even pass fail] $pass $fail
	} {{0 3} {} {3 5 7}}

	test split-4.8 {split command} {
		list [lsplit {2 4 6} even pass fail] $pass $fail
	} {{3 0} {2 4 6} {}}


	# See test filter-4.5 for explanations.

	test split-4.9 {split evaluates cmdprefix on outer scope} -setup {
		set flag 1
	} -body {
		list [lsplit {1 2 3 4 5 6 7 8} alternating pass fail] $pass $fail
	} -cleanup {
		unset flag
	} -result {{4 4} {2 4 6 8} {1 3 5 7}}

	#----------------------------------------------------------------------

	interp alias {} shift {} ::struct::list::list shift

	test shift-4.1 {shift command} {
		set v {1 2 3 4 5 6 7 8}
		list [shift v] $v
	} {1 {2 3 4 5 6 7 8}}

	test shift-4.2 {shift command} {
		set v {1}
		list [shift v] $v
	} {1 {}}

	test shift-4.3 {shift command} {
		set v {}
		list [shift v] $v
	} {{} {}}

	#----------------------------------------------------------------------

	interp alias {} iota {} ::struct::list::list iota

	test iota-4.1 {iota command} {
		iota 0
	} {}

	test iota-4.2 {iota command} {
		iota 1
	} {0}

	test iota-4.3 {iota command} {
		iota 11
	} {0 1 2 3 4 5 6 7 8 9 10}


	#----------------------------------------------------------------------

	interp alias {} repeatn {} ::struct::list::list repeatn

	test repeatn-4.1 {repeatn command} {
		repeatn 0
	} {}

	test repeatn-4.2 {repeatn command} {
		repeatn 0 3
	} {0 0 0}

	test repeatn-4.3 {repeatn command} {
		repeatn 0 3 4
	} {{0 0 0} {0 0 0} {0 0 0} {0 0 0}}

	test repeatn-4.4 {repeatn command} {
		repeatn 0 {3 4}
	} {{0 0 0} {0 0 0} {0 0 0} {0 0 0}}

	#----------------------------------------------------------------------

	interp alias {} repeat {} ::struct::list::list repeat

	if {[package vcompare [package provide Tcl] 8.5] < 0} {
		# 8.4
		set err [tcltest::wrongNumArgs {::struct::list::Lrepeat} {positiveCount value args} 0]
	} elseif {![package vsatisfies [package provide Tcl] 8.6]} {
		# 8.5+
		#set err [tcltest::wrongNumArgs {lrepeat} {positiveCount value ?value ...?} 0]
		set err [tcltest::wrongNumArgs {::struct::list::Lrepeat} {positiveCount value ?value ...?} 0]
	} else {
		# 8.6+
		set err [tcltest::wrongNumArgs {::struct::list::Lrepeat} {count ?value ...?} 1]
	}
	test repeat-4.1 {repeat command} {
		catch {repeat} msg
		set msg
	} $err


	if {[package vcompare [package provide Tcl] 8.5] < 0} {
		# 8.4
		set err [tcltest::wrongNumArgs {::struct::list::Lrepeat} {positiveCount value args} 1]
	} elseif {![package vsatisfies [package provide Tcl] 8.6]} {
		# 8.5+
		#set err [tcltest::wrongNumArgs {lrepeat} {positiveCount value ?value ...?} 1]
		set err [tcltest::wrongNumArgs {::struct::list::Lrepeat} {positiveCount value ?value ...?} 1]
	} else {
		# 8.6+
		set err [tcltest::wrongNumArgs {::struct::list::Lrepeat} {count ?value ...?} 1]
	}
	# In 8.6+ repeat is the native lrepeat and it does nothing gracefully,
	# per TIP 323, making repeat-4.2 not an error anymore.
	test repeat-4.2 {repeat command} {!tcl8.6plus} {
		catch {repeat a} msg
		set msg
	} $err

	test repeat-4.3 {repeat command} {
		catch {repeat a b} msg
		set msg
	} {expected integer but got "a"}

	# In 8.6+ repeat is the native lrepeat and it does nothing gracefully,
	# per TIP 323, making repeat-4.2 not an error anymore.
	test repeat-4.4 {repeat command} {!tcl8.6plus} {
		catch {repeat 0 b} msg
		set msg
	} {must have a count of at least 1}

	if {![package vsatisfies [package provide Tcl] 8.6]} {
		# before 8.6
		set err {must have a count of at least 1}
	} else {
		# 8.6+, native lrepeat changed error message.
		set err {bad count "-1": must be integer >= 0}
	}
	test repeat-4.5 {repeat command} {
		catch {repeat -1 b} msg
		set msg
	} $err

	test repeat-4.6 {repeat command} {
		repeat 1 b c
	} {b c}

	test repeat-4.7 {repeat command} {
		repeat 3 a
	} {a a a}

	test repeat-4.8 {repeat command} {
		repeat 3 [repeat 3 0]
	} {{0 0 0} {0 0 0} {0 0 0}}

	test repeat-4.9 {repeat command} {
		repeat 3 a b c
	} {a b c a b c a b c}

	test repeat-4.10 {repeat command} {
		repeat 3 [repeat 2 a] b c
	} {{a a} b c {a a} b c {a a} b c}

	#----------------------------------------------------------------------

	interp alias {} equal {} ::struct::list::list equal

	test equal-4.1 {equal command} {
		equal 0 0
	} 1

	test equal-4.2 {equal command} {
		equal 0 1
	} 0

	test equal-4.3 {equal command} {
		equal {0 0 0} {0 0}
	} 0

	test equal-4.4 {equal command} {
		equal {{0 2 3} 1} {{0 2 3} 1}
	} 1

	test equal-4.5 {equal command} {
		equal [list [list a]] {{a}}
	} 1

	test equal-4.6 {equal command} {
		equal {{a}} [list [list a]]
	} 1

	test equal-4.7 {equal command} {
		set a {{a}}
		set b [list [list a]]
		expr {[equal $a $b] == [equal $b $a]}
	} 1

	test equal-4.8 {equal command} {
		set a {{a b}}
		set b [list [list a b]]
		expr {[equal $a $b] == [equal $b $a]}
	} 1

	test equal-4.9 {equal command} {
		set a {{a} {b}}
		set b [list [list a] [list b]]
		expr {[equal $a $b] == [equal $b $a]}
	} 1

	#----------------------------------------------------------------------

	interp alias {} delete {} ::struct::list::list delete

	test delete-1.0 {delete command} {
		catch {delete} msg
		set msg
	} {wrong # args: should be "::struct::list::Ldelete var item"}

	test delete-1.1 {delete command} {
		catch {delete x} msg
		set msg
	} {wrong # args: should be "::struct::list::Ldelete var item"}

	test delete-1.2 {delete command} {
		set l {}
		delete l x
		set l
	} {}

	test delete-1.3 {delete command} {
		set l {a x b}
		delete l x
		set l
	} {a b}

	test delete-1.4 {delete command} {
		set l {x a b}
		delete l x
		set l
	} {a b}

	test delete-1.5 {delete command} {
		set l {a b x}
		delete l x
		set l
	} {a b}

	test delete-1.6 {delete command} {
		set l {a b}
		delete l x
		set l
	} {a b}

	catch { unset l }
	#----------------------------------------------------------------------

	interp alias {} dbjoin  {} ::struct::list::list dbJoin
	interp alias {} dbjoink {} ::struct::list::list dbJoinKeyed

	#----------------------------------------------------------------------
	# Input data sets ...

	set empty {}
	set table_as [list \
		{0 foo} \
		{1 snarf} \
		{2 blue} \
		]
	set table_am [list \
		{0 foo} \
		{0 bar} \
		{1 snarf} \
		{1 rim} \
		{2 blue} \
		{2 dog} \
		]
	set table_bs [list \
		{0 bagel} \
		{1 snatz} \
		{3 driver} \
		]
	set table_bm [list \
		{0 bagel} \
		{0 loaf} \
		{1 snatz} \
		{1 grid} \
		{3 driver} \
		{3 tcl} \
		]
	set table_cs [list \
		{0 smurf} \
		{3 bird} \
		{4 galapagos} \
		]
	set table_cm [list \
		{0 smurf} \
		{0 blt} \
		{3 bird} \
		{3 itcl} \
		{4 galapagos} \
		{4 tk} \
		]

	#----------------------------------------------------------------------
	# Result data sets ...

	set nyi __not_yet_written__

	set ijss [list \
		[list 0 foo   0 bagel] \
		[list 1 snarf 1 snatz] \
		]
	set ijsm [list \
		[list 0 foo   0 bagel] \
		[list 0 foo   0 loaf] \
		[list 1 snarf 1 snatz] \
		[list 1 snarf 1 grid] \
		]
	set ijms [list \
		[list 0 foo   0 bagel] \
		[list 0 bar   0 bagel] \
		[list 1 snarf 1 snatz] \
		[list 1 rim   1 snatz] \
		]
	set ijmm [list \
		[list 0 foo   0 bagel] \
		[list 0 foo   0 loaf] \
		[list 0 bar   0 bagel] \
		[list 0 bar   0 loaf] \
		[list 1 snarf 1 snatz] \
		[list 1 snarf 1 grid] \
		[list 1 rim   1 snatz] \
		[list 1 rim   1 grid] \
		]

	set ljss [list \
		[list 0 foo   0 bagel] \
		[list 1 snarf 1 snatz] \
		[list 2 blue {} {}] \
		]
	set ljsm [list \
		[list 0 foo   0 bagel] \
		[list 0 foo   0 loaf] \
		[list 1 snarf 1 snatz] \
		[list 1 snarf 1 grid] \
		[list 2 blue {} {}] \
		]
	set ljms [list \
		[list 0 foo   0 bagel] \
		[list 0 bar   0 bagel] \
		[list 1 snarf 1 snatz] \
		[list 1 rim   1 snatz] \
		[list 2 blue {} {}] \
		[list 2 dog  {} {}] \
		]
	set ljmm [list \
		[list 0 foo   0 bagel] \
		[list 0 foo   0 loaf] \
		[list 0 bar   0 bagel] \
		[list 0 bar   0 loaf] \
		[list 1 snarf 1 snatz] \
		[list 1 snarf 1 grid] \
		[list 1 rim   1 snatz] \
		[list 1 rim   1 grid] \
		[list 2 blue {} {}] \
		[list 2 dog  {} {}] \
		]

	set rjss [list \
		[list 0 foo   0 bagel] \
		[list 1 snarf 1 snatz] \
		[list {} {}   3 driver] \
		]
	set rjsm [list \
		[list 0 foo   0 bagel] \
		[list 0 foo   0 loaf] \
		[list 1 snarf 1 snatz] \
		[list 1 snarf 1 grid] \
		[list {} {}   3 driver] \
		[list {} {}   3 tcl] \
		]
	set rjms [list \
		[list 0 foo   0 bagel] \
		[list 0 bar   0 bagel] \
		[list 1 snarf 1 snatz] \
		[list 1 rim   1 snatz] \
		[list {} {}   3 driver] \
		]
	set rjmm [list \
		[list 0 foo   0 bagel] \
		[list 0 foo   0 loaf] \
		[list 0 bar   0 bagel] \
		[list 0 bar   0 loaf] \
		[list 1 snarf 1 snatz] \
		[list 1 snarf 1 grid] \
		[list 1 rim   1 snatz] \
		[list 1 rim   1 grid] \
		[list {} {}   3 driver] \
		[list {} {}   3 tcl] \
		]

	set fjss [list \
		[list 0 foo   0 bagel] \
		[list 1 snarf 1 snatz] \
		[list 2 blue {} {}] \
		[list {} {}   3 driver] \
		]
	set fjsm [list \
		[list 0 foo   0 bagel] \
		[list 0 foo   0 loaf] \
		[list 1 snarf 1 snatz] \
		[list 1 snarf 1 grid] \
		[list 2 blue {} {}] \
		[list {} {}   3 driver] \
		[list {} {}   3 tcl] \
		]
	set fjms [list \
		[list 0 foo   0 bagel] \
		[list 0 bar   0 bagel] \
		[list 1 snarf 1 snatz] \
		[list 1 rim   1 snatz] \
		[list 2 blue {} {}] \
		[list 2 dog  {} {}] \
		[list {} {}   3 driver] \
		]
	set fjmm [list \
		[list 0 foo   0 bagel] \
		[list 0 foo   0 loaf] \
		[list 0 bar   0 bagel] \
		[list 0 bar   0 loaf] \
		[list 1 snarf 1 snatz] \
		[list 1 snarf 1 grid] \
		[list 1 rim   1 snatz] \
		[list 1 rim   1 grid] \
		[list 2 blue {} {}] \
		[list 2 dog  {} {}] \
		[list {} {}   3 driver] \
		[list {} {}   3 tcl] \
		]

	set ijmmm {
		{0 bar 0 bagel 0 blt}
		{0 bar 0 bagel 0 smurf}
		{0 bar 0 loaf 0 blt}
		{0 bar 0 loaf 0 smurf}
		{0 foo 0 bagel 0 blt}
		{0 foo 0 bagel 0 smurf}
		{0 foo 0 loaf 0 blt}
		{0 foo 0 loaf 0 smurf}
	}
	set ljmmm {
		{0 bar 0 bagel 0 blt}
		{0 bar 0 bagel 0 smurf}
		{0 bar 0 loaf 0 blt}
		{0 bar 0 loaf 0 smurf}
		{0 foo 0 bagel 0 blt}
		{0 foo 0 bagel 0 smurf}
		{0 foo 0 loaf 0 blt}
		{0 foo 0 loaf 0 smurf}
		{1 rim 1 grid {} {}}
		{1 rim 1 snatz {} {}}
		{1 snarf 1 grid {} {}}
		{1 snarf 1 snatz {} {}}
		{2 blue {} {} {} {}}
		{2 dog {} {} {} {}}
	}
	set rjmmm {
		{0 bar 0 bagel 0 blt}
		{0 bar 0 bagel 0 smurf}
		{0 bar 0 loaf 0 blt}
		{0 bar 0 loaf 0 smurf} 
		{0 foo 0 bagel 0 blt}
		{0 foo 0 bagel 0 smurf}
		{0 foo 0 loaf 0 blt}
		{0 foo 0 loaf 0 smurf}
		{{} {} 3 driver 3 bird}
		{{} {} 3 driver 3 itcl}
		{{} {} 3 tcl 3 bird}
		{{} {} 3 tcl 3 itcl}
		{{} {} {} {} 4 galapagos}
		{{} {} {} {} 4 tk}
	}
	set fjmmm {
		{0 bar 0 bagel 0 blt}
		{0 bar 0 bagel 0 smurf}
		{0 bar 0 loaf 0 blt}
		{0 bar 0 loaf 0 smurf} 
		{0 foo 0 bagel 0 blt}
		{0 foo 0 bagel 0 smurf}
		{0 foo 0 loaf 0 blt}
		{0 foo 0 loaf 0 smurf}
		{1 rim 1 grid {} {}}
		{1 rim 1 snatz {} {}}
		{1 snarf 1 grid {} {}}
		{1 snarf 1 snatz {} {}}
		{2 blue {} {} {} {}}
		{2 dog {} {} {} {}}
		{{} {} 3 driver 3 bird}
		{{} {} 3 driver 3 itcl}
		{{} {} 3 tcl 3 bird}
		{{} {} 3 tcl 3 itcl}
		{{} {} {} {} 4 galapagos}
		{{} {} {} {} 4 tk}
	}

	#----------------------------------------------------------------------
	# Helper, translation to keyed format.

	proc keyed {table} {
		# Get the key out of the row, hardwired to column 0
		set res [list]
		foreach row $table {lappend res [list [lindex $row 0] $row]}
		return $res
	}

	#----------------------------------------------------------------------
	# I.	One table joins

	set n 0 ; # Counter for test cases
	foreach {jtype inout} {
		-inner empty    -inner table_as    -inner table_am
		-left  empty    -left  table_as    -left  table_am
		-right empty    -right table_as    -right table_am
		-full  empty    -full  table_as    -full  table_am
	} {
		test dbjoin-1.$n "1-table join $jtype $inout" {
		dbjoin $jtype 0 [set $inout]
		} [set $inout] ; # {}

		test dbjoinKeyed-1.$n "1-table join $jtype $inout" {
		dbjoink $jtype [keyed [set $inout]]
		} [set $inout] ; # {}

		incr n
	}

	#----------------------------------------------------------------------
	# II.	Two table joins

	set n 0 ; # Counter for test cases
	foreach {jtype left right result} {
		-inner empty    empty    empty
		-inner empty    table_bs empty
		-inner table_as empty    empty
		-inner table_as table_bs ijss
		-inner table_as table_bm ijsm
		-inner table_am table_bs ijms
		-inner table_am table_bm ijmm

		-left  empty    empty    empty
		-left  empty    table_bs empty
		-left  table_as empty    table_as
		-left  table_as table_bs ljss
		-left  table_as table_bm ljsm
		-left  table_am table_bs ljms
		-left  table_am table_bm ljmm

		-right empty    empty    empty
		-right empty    table_bs table_bs
		-right table_as empty    empty
		-right table_as table_bs rjss
		-right table_as table_bm rjsm
		-right table_am table_bs rjms
		-right table_am table_bm rjmm

		-full  empty    empty    empty
		-full  empty    table_bs table_bs
		-full  table_as empty    table_as
		-full  table_as table_bs fjss
		-full  table_as table_bm fjsm
		-full  table_am table_bs fjms
		-full  table_am table_bm fjmm
	} {
		test dbjoin-2.$n "2-table join $jtype ($left $right) = $result" {
		lsort [dbjoin $jtype 0 [set $left] 0 [set $right]]
		} [lsort [set $result]]

		test dbjoinKeyed-2.$n "2-table join $jtype ($left $right) = $result" {
		lsort [dbjoink $jtype [keyed [set $left]] [keyed [set $right]]]
		} [lsort [set $result]]

		incr n
	}

	#----------------------------------------------------------------------
	# III.	Three table joins

	set n 0 ; # Counter for test cases
	foreach {jtype left middle right result} {
		-inner table_am table_bm table_cm ijmmm
		-left  table_am table_bm table_cm ljmmm
		-right table_am table_bm table_cm rjmmm
		-full  table_am table_bm table_cm fjmmm
	} {
		test dbjoin-3.$n "3-table join $jtype ($left $middle $right) = $result" {
		lsort [dbjoin $jtype 0 [set $left] 0 [set $middle] 0 [set $right]]
		} [lsort [set $result]]

		test dbjoinKeyed-3.$n "3-table join $jtype ($left $middle $right) = $result" {
		lsort [dbjoink $jtype [keyed [set $left]] [keyed [set $middle]] [keyed [set $right]]]
		} [lsort [set $result]]

		incr n
	}

	#----------------------------------------------------------------------

	interp alias {} swap {} ::struct::list::list swap

	foreach {n list i j err res} {
		0  {}           0  0   1 {list index out of range}
		1  {}           3  4   1 {list index out of range}
		2  {a b c d e} -1  0   1 {list index out of range}
		3  {a b c d e}  0 -1   1 {list index out of range}
		4  {a b c d e}  6  0   1 {list index out of range}
		5  {a b c d e}  0  6   1 {list index out of range}
		6  {a b c d e}  0  0   0 {a b c d e}
		7  {a b c d e}  0  1   0 {b a c d e}
		8  {a b c d e}  1  0   0 {b a c d e}
		9  {a b c d e}  0  4   0 {e b c d a}
		10 {a b c d e}  4  0   0 {e b c d a}
		11 {a b c d e}  2  4   0 {a b e d c}
		12 {a b c d e}  4  2   0 {a b e d c}
		13 {a b c d e}  1  3   0 {a d c b e}
		14 {a b c d e}  3  1   0 {a d c b e}
	} {
		if {$err} {
		test swap-1.$n {swap command error} {
			set l $list
			catch {swap l $i $j} msg
			set msg
		} $res ; # {}
		} else {
		test swap-1.$n {swap command} {
			set l $list
			swap l $i $j
		} $res ; # {}
		}
	}


	#----------------------------------------------------------------------

	interp alias {} firstperm    {} ::struct::list::list firstperm
	interp alias {} nextperm     {} ::struct::list::list nextperm
	interp alias {} foreachperm  {} ::struct::list::list foreachperm
	interp alias {} permutations {} ::struct::list::list permutations

	test permutations-0.0 {permutations command, single element list} {
		permutations a
	} a


	array set ps {
		{Tom Dick Harry Bob} {
		0	{Bob Dick Harry Tom}	{Tom Harry Bob Dick}
		{
			{Bob Dick Harry Tom}    {Bob Dick Tom Harry}
			{Bob Harry Dick Tom}    {Bob Harry Tom Dick}
			{Bob Tom Dick Harry}    {Bob Tom Harry Dick}
			{Dick Bob Harry Tom}    {Dick Bob Tom Harry}
			{Dick Harry Bob Tom}    {Dick Harry Tom Bob}
			{Dick Tom Bob Harry}    {Dick Tom Harry Bob}
			{Harry Bob Dick Tom}    {Harry Bob Tom Dick}
			{Harry Dick Bob Tom}    {Harry Dick Tom Bob}
			{Harry Tom Bob Dick}    {Harry Tom Dick Bob}
			{Tom Bob Dick Harry}    {Tom Bob Harry Dick}
			{Tom Dick Bob Harry}    {Tom Dick Harry Bob}
			{Tom Harry Bob Dick}    {Tom Harry Dick Bob}
		}
		}
		{3 2 1 4} {
		1	{1 2 3 4}	{3 2 4 1}
		{
			{1 2 3 4} {1 2 4 3} {1 3 2 4} {1 3 4 2}
			{1 4 2 3} {1 4 3 2} {2 1 3 4} {2 1 4 3}
			{2 3 1 4} {2 3 4 1} {2 4 1 3} {2 4 3 1}
			{3 1 2 4} {3 1 4 2} {3 2 1 4} {3 2 4 1}
			{3 4 1 2} {3 4 2 1} {4 1 2 3} {4 1 3 2}
			{4 2 1 3} {4 2 3 1} {4 3 1 2} {4 3 2 1}
		}
		}
	}

	foreach k [array names ps] {
		foreach {n firstp nextp allp} $ps($k) break

		test firstperm-1.$n {firstperm command} {
		firstperm $k
		} $firstp ; # {}

		test nextperm-1.$n {nextperm command} {
		nextperm $k
		} $nextp ; # {}

		# Note: The lrange below is necessary a trick/hack to kill the
		# existing string representation of allp, and get a pure list out
		# of it. Otherwise the string based comparison of test will fail,
		# seeing different string reps of the same list.

		test permutations-1.$n {permutations command} {
		permutations $k
		} [lrange $allp 0 end] ; # {}

		test foreachperm-1.$n {foreachperm command} {
		set res {}
		foreachperm x $k {lappend res $x}
		set res
		} [lrange $allp 0 end] ; # {}
	}

	test nextperm-2.0 {bug 3593689, busyloop} {
		nextperm {1 10 9 8 7 6 5 4 3 2}
	} {1 2 10 3 4 5 6 7 8 9}

	#----------------------------------------------------------------------

	interp alias {} shuffle {} ::struct::list::list shuffle

	test shuffle-1.0 {} -body {
		shuffle
	} -returnCodes error -result {wrong # args: should be "::struct::list::Lshuffle list"}

	test shuffle-2.0 {shuffle nothing} -body {
		shuffle {}
	} -result {}

	test shuffle-2.1 {shuffle single} -body {
		shuffle {a}
	} -result {a}

	foreach {k n data} {
		1 2  {a b}
		2 4  {c d b a}
		3 9  {0 1 2 3 4 5 6 7 8}
		4 15 {a b c d e f 8 6 4 2 0 1 3 5 7}
	} {
		test shuffle-2.2.$k "shuffle $n" -body {
		lsort [shuffle $data]
		} -result [lsort $data]
	}
}

package provide struct::list::test 1.8.4 
