# $Id$
# Test file for registry::item
# Syntax:
# tclsh item.tcl <Pextlib name>

proc main {pextlibname} {
    load $pextlibname

    set aesc [registry::item create]
    set wynn [registry::item create]
    set eth [registry::item create]
    set thorn [registry::item create]

    test {[registry::item exists $aesc]}
    test {![registry::item exists kumquat]}
    test {![registry::item exists string]}

    $aesc key name aesc
    $wynn key name wynn
    $eth key name eth
    $thorn key name thorn

    test_equal {[$aesc key name]} "aesc"
    test_equal {[$thorn key name]} "thorn"

    $aesc key variants {}
    $wynn key variants {}
    $eth key variants {{big +} {small -}}
    $thorn key variants {{big +} {small -}}

	test_equal {[registry::item search {name aesc}]} "$aesc"
    test_equal {[registry::item search {variants {}}]} "$aesc $wynn"
    test_equal {[registry::item search {variants {{big +}}}]} ""
    test_equal {[registry::item search {variants {{big +} {small -}}}]} "$eth $thorn"
	test_equal {[registry::item search {name wynn} {variants {}}]} "$wynn"

	$aesc release
	$wynn retain
	$wynn release

	test {![registry::item exists $aesc]}
	test {[registry::item exists $wynn]}

	$wynn release

	test {![registry::item exists $wynn]}

	file delete -force test.db
}

source tests/common.tcl
main $argv
