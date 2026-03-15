###
# Test script build functions
###

set result {}
putb result {# clay.test - Copyright (c) 2018 Sean Woods
# -------------------------------------------------------------------------

set MODDIR [file dirname [file dirname [file join [pwd] [info script]]]]
if {[file exists [file join $MODDIR devtools testutilities.tcl]]} {
  # Running inside tcllib
  set TCLLIBMOD $MODDIR
} else {
  set TCLLIBMOD [file join $MODDIR .. .. tcllib modules]
}
source [file join $TCLLIBMOD devtools testutilities.tcl]

testsNeedTcl     8.6
testsNeedTcltest 2
testsNeed        TclOO 1

support {}
testing {
    useLocal clay.tcl clay
}
}

putb result {
set ::clay::trace 0
}

###
# UUID test
###
putb result {

# -------------------------------------------------------------------------
# Handle multiple implementation testing
#

array set preserve [array get ::clay::uuid::accel]

proc implementations {} {
    variable ::clay::uuid::accel
    foreach {a v} [array get accel] {if {$v} {lappend r $a}}
    lappend r tcl; set r
}

proc select_implementation {impl} {
    variable ::clay::uuid::accel
    foreach e [array names accel] { set accel($e) 0 }
    if {[string compare "tcl" $impl] != 0} {
        set accel($impl) 1
    }
}

proc reset_implementation {} {
    variable ::clay::uuid::accel
    array set accel [array get ::preserve]
}

# -------------------------------------------------------------------------
# Setup any constraints
#

# -------------------------------------------------------------------------
# Now the package specific tests....
# -------------------------------------------------------------------------

# -------------------------------------------------------------------------

foreach impl [implementations] {
    select_implementation $impl

    test uuid-1.0-$impl "uuid requires args" {
        list [catch {clay::uuid} msg]
    } {1}

    test uuid-1.1-$impl "uuid generate should create a 36 char string uuid" {
        list [catch {string length [clay::uuid generate]} msg] $msg
    } {0 36}

    test uuid-1.2-$impl "uuid comparison of uuid with self should be true" {
        list [catch {
            set a [clay::uuid generate]
            clay::uuid equal $a $a
        } msg] $msg
    } {0 1}

    test uuid-1.3-$impl "uuid comparison of two different\
        uuids should be false" {
        list [catch {
            set a [clay::uuid generate]
            set b [clay::uuid generate]
            clay::uuid equal $a $b
        } msg] $msg
    } {0 0}

    reset_implementation
}
}


putb result {
# Modification History:
###
# Modification 2018-10-30
# Fixed an error in our ancestry mapping and developed tests to
# ensure we are actually following in the order TclOO follows methods
###
# Modification 2018-10-21
# The clay metaclass no longer exports the clay method
# to oo::class and oo::object, and clay::ancestors no
# longer returns any class that lacks the clay method
###
# Modification 2018-10-10
# clay::ancestors now rigged to descend into all classes depth-first
# and then place metaclasses at the end of the search
###
# -------------------------------------------------------------------------

# -------------------------------------------------------------------------
# Test Helpers
###
proc dict_compare {a b} {
  set result {}
  set A {}
  dict for {f v} $a {
    set f [string trim $f :/]
    if {$f eq {.}} continue
    dict set A $f $v
  }
  set B {}
  dict for {f v} $b {
    set f [string trim $f :/]
    if {$f eq {.}} continue
    dict set B $f $v
  }
  dict for {f v} $A {
    if {[dict exists $B $f]} {
      if {[dict get $B $f] ne $v} {
        lappend result [list B $f [dict get $B $f] [list != $v]]
      }
    } else {
      lappend result [list B $f $v missing]
    }
  }
  dict for {f v} $B {
    if {![dict exists $A $f]} {
      lappend result [list A $f $v missing]
    }
  }
  return $result
}

test dict-compare-001 {Test our testing method} {
  dict_compare {} {}
} {}

test dict-compare-002 {Test our testing method} {
  dict_compare {a 1} {}
} {{B a 1 missing}}

test dict-compare-003 {Test our testing method} {
  dict_compare {a 1 b 2} {a 1 b 2}
} {}

test dict-compare-003.a {Test our testing method} {
  dict_compare {a 1 b 2} {b 2 a 1 }
} {}

test dict-compare-003.b {Test our testing method} {
  dict_compare {b 2 a 1} {a 1 b 2}
} {}


test dict-compare-004 {Test our testing method} {
  dict_compare {a: 1 b: 2} {a 1 b 2}
} {}

test dict-compare-005 {Test our testing method} {
  dict_compare {a 1 b 3} {a 1 b 2}
} {{B b 2 {!= 3}}}
}


###
# Tests for clay::tree
###

putb result {
###
# Test canonical mapping
###
}
set test 0
  foreach {pattern canonical storage} {
    {foo bar baz}       {foo/ bar/ baz}         {foo bar baz}
    {foo bar baz/}      {foo/ bar/ baz/}        {foo bar baz}
    {foo bar .}         {foo/ bar}              {foo bar .}
    {foo/ bar/ .}       {foo/ bar}              {foo bar .}
    {foo . bar . baz .} {foo/ bar/ baz}         {foo . bar . baz .}
    {foo bar baz bat:}  {foo/ bar/ baz/ bat:}   {foo bar baz bat:}
    {foo:}              {foo:}                  {foo:}
    {foo/bar/baz/bat:}  {foo/ bar/ baz/ bat:}   {foo bar baz bat:}
} {
    dict set map %pattern% $pattern
    dict set map %canonical% $canonical
    dict set map %storage% $storage
    incr test

    dict set map %test% [format "test-storage-%04d" $test]
    putb result $map {
test {%test%} {Test ::clay::tree::storage with %pattern%} {
  clay::tree::storage {%pattern%}
} {%storage%}
}
}

putb result {
dict set r foo/ bar/ baz 1
dict set s foo/ bar/ baz 0
set t [clay::tree::merge $r $s]

test rmerge-0001 {Test that the root is marked as a branch} {
  dict get $t foo bar baz
} 0

set r [dict create]
clay::tree::dictmerge r {
  foo/ {
    bar/ {
      baz 1
      bing: 2
      bang { bim 3 boom 4 }
      womp: {a 1 b 2}
    }
  }
}

test dictmerge-0001 {Test that the root is marked as a branch} {
  dict exists $r .
} 1
test dictmerge-0002 {Test that branch foo is marked correctly} {
  dict exists $r foo .
} 1
test dictmerge-0003 {Test that branch bar is marked correctly} {
  dict exists $r foo bar .
} 1
test dictmerge-0004 {Test that leaf foo/bar/bang is not marked as branch despite being a dict} {
  dict exists $r foo bar bang .
} 0
test dictmerge-0004 {Test that leaf foo/bar/bang/bim exists} {
  dict exists $r foo bar bang bim
} 1
test dictmerge-0005 {Test that leaf foo/bar/bang/boom exists} {
  dict exists $r foo bar bang boom
} 1

###
# Replace bang with bang/
###
clay::tree::dictmerge r {
  foo/ {
    bar/ {
      bang/ {
        whoop 1
      }
    }
  }
}

test dictmerge-0006 {Test that leaf foo/bar/bang/bim ceases to exist} {
  dict exists $r foo bar bang bim
} 0
test dictmerge-0007 {Test that leaf foo/bar/bang/boom exists} {
  dict exists $r foo bar bang boom
} 0

test dictmerge-0008 {Test that leaf foo/bar/bang is now a branch} {
  dict exists $r foo bar bang .
} 1

test branch-0001 {Test that foo/ is a branch} {
  clay::tree::is_branch $r foo/
} 1
test branch-0002 {Test that foo is a branch} {
  clay::tree::is_branch $r foo
} 1
test branch-0003 {Test that foo/bar/ is a branch} {
  clay::tree::is_branch $r {foo/ bar/}
} 1
test branch-0004 {Test that foo bar is not branch} {
  clay::tree::is_branch $r {foo bar}
} 1
test branch-0004 {Test that foo/ bar is not branch} {
  clay::tree::is_branch $r {foo/ bar}
} 0
}

set test 0
foreach {path isbranch} {
  foo 1
  {foo bar} 1
  {foo bar baz} 0
  {foo bar bing} 0
  {foo bar bang} 1
  {foo bar bang whoop} 0
} {
  set mpath [lrange $path 0 end-1]
  set item  [lindex $path end]
  set tests [list {} {} $isbranch {} : 0 {} / 1 . {} 0]
  dict set map %mpath% $mpath
  dict set map %item% $item
  foreach {head tail isbranch} $tests {
    dict set map %head% $head
    dict set map %tail% $tail
    dict set map %isbranch% $isbranch
    dict set map %test% [format "test-branch-%04d" [incr test]]
    putb result $map {
test {%test%} {Test that %mpath% %head%%item%%tail% is_branch = %isbranch%} {
  clay::tree::is_branch $r {%mpath% %head%%item%%tail%}
} %isbranch%
}
  }
}

putb result {
# -------------------------------------------------------------------------
# dictmerge Testing - oometa
unset -nocomplain foo
clay::tree::dictmerge foo {
  option/ {
    color/ {
      label Color
      default green
    }
  }
}
clay::tree::dictmerge foo {
  option/ {
    color/ {
      default purple
    }
  }
}

test oometa-0001 {Invoking dictmerge with empty args on a non existent variable create an empty variable} {
  dict get $foo option color default
} purple
test oometa-0002 {Invoking dictmerge with empty args on a non existent variable create an empty variable} {
  dict get $foo option color label
} Color

unset -nocomplain foo
set foo {. {}}
::clay::tree::dictmerge foo {. {} color {. {} default green label Color}}
::clay::tree::dictmerge foo {. {} color {. {} default purple}}
test oometa-0003 {Recursive merge problem from oometa/clay find} {
  dict get $foo color default
} purple
test oometa-0004 {Recursive merge problem from oometa/clay find} {
  dict get $foo color label
} Color

unset -nocomplain foo
set foo {. {}}
::clay::tree::dictmerge foo {. {} color {. {} default purple}}
::clay::tree::dictmerge foo {. {} color {. {} default green label Color}}
test oometa-0005 {Recursive merge problem from oometa/clay find} {
  dict get $foo color default
} green
test oometa-0006 {Recursive merge problem from oometa/clay find} {
  dict get $foo color label
} Color

test oometa-0008 {Un-Sanitized output} {
  set foo
} {. {} color {. {} default green label Color}}

test oometa-0009 {Sanitize} {
  clay::tree::sanitize $foo
} {color {default green label Color}}
}


putb result {
# -------------------------------------------------------------------------
# dictmerge Testing - clay
unset -nocomplain foo
test clay-0001 {Invoking dictmerge with empty args on a non existent variable create an empty variable} {
  ::clay::tree::dictmerge foo
  set foo
} {. {}}

unset -nocomplain foo
::clay::tree::dictset foo bar/ baz/ bell bang

test clay-0002 {For new entries dictmerge is essentially a set} {
  dict get $foo bar baz bell
} {bang}
::clay::tree::dictset foo bar/ baz/ boom/ bang
test clay-0003 {For entries that do exist a zipper merge is performed} {
  dict get $foo bar baz bell
} {bang}
test clay-0004 {For entries that do exist a zipper merge is performed} {
  dict get $foo bar baz boom
} {bang}

::clay::tree::dictset foo bar/ baz/ bop {color green flavor strawberry}

test clay-0005 {Leaves are replaced even if they look like a dict} {
  dict get $foo bar baz bop
} {color green flavor strawberry}

::clay::tree::dictset foo bar/ baz/ bop {color yellow}
test clay-0006 {Leaves are replaced even if they look like a dict} {
  dict get $foo bar baz bop
} {color yellow}

::clay::tree::dictset foo bar/ baz/ bang/ {color green flavor strawberry}
test clay-0007a {Branches are merged} {
  dict get $foo bar baz bang
} {. {} color green flavor strawberry}

::clay::tree::dictset foo bar/ baz/ bang/ color yellow
test clay-0007b {Branches are merged}  {
  dict get $foo bar baz bang
} {. {} color yellow flavor strawberry}

::clay::tree::dictset foo bar/ baz/ bang/ {color blue}
test clay-0007c {Branches are merged}  {
  dict get $foo bar baz bang
} {. {} color blue flavor strawberry}

::clay::tree::dictset foo bar/ baz/ bang/ shape: {Sort of round}
test clay-0007d {Branches are merged} {
  dict get $foo bar baz bang
} {. {} color blue flavor strawberry shape: {Sort of round}}

::clay::tree::dictset foo bar/ baz/ bang/ color yellow
test clay-0007e {Branches are merged}  {
  dict get $foo bar baz bang
} {. {} color yellow flavor strawberry shape: {Sort of round}}

::clay::tree::dictset foo bar/ baz/ bang/ {color blue}
test clay-0007f {Branches are merged}  {
  dict get $foo bar baz bang
} {. {} color blue flavor strawberry shape: {Sort of round}}

::clay::tree::dictset foo dict my_var 10
::clay::tree::dictset foo dict my_other_var 9

test clay-0007g {Branches are merged}  {
  dict get $foo dict
} {. {} my_var 10 my_other_var 9}

::clay::tree::dictset foo dict/ my_other_other_var 8
test clay-0007h {Branches are merged}  {
  dict get $foo dict
} {. {} my_var 10 my_other_var 9 my_other_other_var 8}


::clay::tree::dictmerge foo {option/ {color {type color} flavor {sense taste}}}
::clay::tree::dictmerge foo {option/ {format {default ascii}}}

test clay-0008 {Whole dicts are merged}  {
  dict get $foo option color
} {type color}
test clay-0009 {Whole dicts are merged}  {
  dict get $foo option flavor
} {sense taste}
test clay-0010 {Whole dicts are merged}  {
  dict get $foo option format
} {default ascii}

###
# Tests for the httpd module
###
test clay-0010 {Test that leaves are merged properly}
set bar {}
::clay::tree::dictmerge bar {
   proxy/ {port 10101 host myhost.localhost}
}
::clay::tree::dictmerge bar {
   mimetxt {Host: localhost
Content_Type: text/plain
Content-Length: 15
}
   http {HTTP_HOST {} CONTENT_LENGTH 15 HOST localhost CONTENT_TYPE text/plain UUID 3a7b4cdc-28d7-49b7-b18d-9d7d18382b9e REMOTE_ADDR 127.0.0.1 REMOTE_HOST 127.0.0.1 REQUEST_METHOD POST REQUEST_URI /echo REQUEST_PATH echo REQUEST_VERSION 1.0 DOCUMENT_ROOT {} QUERY_STRING {} REQUEST_RAW {POST /echo HTTP/1.0} SERVER_PORT 10001 SERVER_NAME 127.0.0.1 SERVER_PROTOCOL HTTP/1.1 SERVER_SOFTWARE {TclHttpd 4.2.0} LOCALHOST 0} UUID 3a7b4cdc-28d7-49b7-b18d-9d7d18382b9e uriinfo {fragment {} port {} path echo scheme http host {} query {} pbare 0 pwd {} user {}}
   mixin {reply ::test::content.echo}
   prefix /echo
   proxy_port 10010
   proxy/ {host localhost}
}

test clay-0011 {Whole dicts are merged}  {
  dict get $bar proxy_port
} {10010}

test clay-0012 {Whole dicts are merged}  {
  dict get $bar http CONTENT_LENGTH
} 15
test clay-0013 {Whole dicts are merged}  {
  dict get $bar proxy host
} localhost
test clay-0014 {Whole dicts are merged}  {
  dict get $bar proxy port
} 10101
}

putb result {
###
# Dialect Testing
###
::clay::dialect::create ::alpha

proc ::alpha::define::is_alpha {} {
  dict set ::testinfo([current_class]) is_alpha 1
}

::alpha::define ::alpha::object {
  is_alpha
}

::clay::dialect::create ::bravo ::alpha

proc ::bravo::define::is_bravo {} {
  dict set ::testinfo([current_class]) is_bravo 1
}

::bravo::define ::bravo::object {
  is_bravo
}

::clay::dialect::create ::charlie ::bravo

proc ::charlie::define::is_charlie {} {
  dict set ::testinfo([current_class]) is_charlie 1
}

::charlie::define ::charlie::object {
  is_charlie
}

::clay::dialect::create ::delta ::charlie

proc ::delta::define::is_delta {} {
  dict set ::testinfo([current_class]) is_delta 1
}

::delta::define ::delta::object {
  is_delta
}

::delta::class create adam {
  is_alpha
  is_bravo
  is_charlie
  is_delta
}

test oodialect-keyword-001 {Testing keyword application} {
  set ::testinfo(::adam)
} {is_alpha 1 is_bravo 1 is_charlie 1 is_delta 1}

test oodialect-keyword-002 {Testing keyword application} {
  set ::testinfo(::alpha::object)
} {is_alpha 1}

test oodialect-keyword-003 {Testing keyword application} {
  set ::testinfo(::bravo::object)
} {is_bravo 1}

test oodialect-keyword-004 {Testing keyword application} {
  set ::testinfo(::charlie::object)
} {is_charlie 1}

test oodialect-keyword-005 {Testing keyword application} {
  set ::testinfo(::delta::object)
} {is_delta 1}

###
# Declare an object from a namespace
###
namespace eval ::test1 {
  ::alpha::class create a {
    aliases A
    is_alpha
  }
  ::alpha::define b {
    aliases B BEE
    is_alpha
  }
  ::alpha::class create ::c {
    aliases C
    is_alpha
  }
  ::alpha::define ::d {
    aliases D
    is_alpha
  }
}

test oodialect-naming-001 {Testing keyword application} {
  set ::testinfo(::test1::a)
} {is_alpha 1}

test oodialect-naming-002 {Testing keyword application} {
  set ::testinfo(::test1::b)
} {is_alpha 1}

test oodialect-naming-003 {Testing keyword application} {
  set ::testinfo(::c)
} {is_alpha 1}

test oodialect-naming-004 {Testing keyword application} {
  set ::testinfo(::d)
} {is_alpha 1}

test oodialect-aliasing-001 {Testing keyword application} {
namespace eval ::test1 {
    ::alpha::define e {
       superclass A
    }
}
} ::test1::e

test oodialect-aliasing-002 {Testing keyword application} {
namespace eval ::test1 {
    ::bravo::define f {
       superclass A
    }
}
} ::test1::f


test oodialect-aliasing-003 {Testing aliase method on class} {
  ::test1::a aliases
} {::test1::A}

###
# Test modified 2018-10-21
###
test oodialect-ancestry-003 {Testing heritage} {
  ::clay::ancestors ::test1::f
} {}

###
# Test modified 2018-10-21
###
test oodialect-ancestry-004 {Testing heritage} {
  ::clay::ancestors ::alpha::object
} {}

###
# Test modified 2018-10-21
###
test oodialect-ancestry-005 {Testing heritage} {
  ::clay::ancestors ::delta::object
} {}

}

putb result {
# -------------------------------------------------------------------------
# clay submodule testing
# -------------------------------------------------------------------------

}
putb result {
# Test canonical path building
set path {const/ foo/ bar/ baz/}
}
set testnum 0
foreach {pattern} {
  {const foo bar baz}
  {const/ foo/ bar/ baz}
  {const/foo/bar/baz}
  {const/foo bar/baz}
  {const/foo/bar baz}
  {const foo/bar/baz}
  {const foo bar/baz}
  {const/foo bar baz}
} {
  putb result [list %pattern% $pattern %testnum% [format %04d [incr testnum]]] {
test oo-clay-path-%testnum% "Test path: %pattern%" {
  ::clay::path %pattern%
} $path
}
}
putb result {set path {const/ foo/ bar/ baz/ bing}}
set testnum 0
foreach {pattern} {
  {const foo bar baz bing}
  {const/ foo/ bar/ baz/ bing}
  {const/foo/bar/baz/bing}
  {const/foo bar/baz/bing:}
  {const/foo/bar baz bing}
  {const/foo/bar baz bing:}
  {const foo/bar/baz/bing}
  {const foo bar/baz/bing}
  {const/foo bar baz bing}
} {
  putb result [list %pattern% $pattern %testnum% [format %04d [incr testnum]]] {
test oo-clay-leaf-%testnum% "Test leaf: %pattern%" {
  ::clay::leaf %pattern%
} $path
}
}

putb result {namespace eval ::foo {}}

set class-a ::foo::classa
set commands-a {
  clay set const color  blue
  clay set const/flavor strawberry
  clay set {const/ sound} zoink
  clay set info/ {
    animal no
    building no
    subelement {pedantic yes}
  }

  # Provide a method that returns a constant so we can compare clay's inheritance to
  # TclOO
  method color {} {
    return blue
  }
  method flavor {} {
    return strawberry
  }
  method sound {} {
    return zoink
  }
}
set claydict-a {
  const/ {color blue flavor strawberry sound zoink}
  info/  {
    animal no
    building no
    subelement {pedantic yes}
  }
}

putb result [list %class% ${class-a} %commands% ${commands-a}] {
clay::define %class% {
%commands%
}
}

set testnum 0
foreach {top children} ${claydict-a} {
  foreach {child value} $children {
    set map {}
    dict set map %class% ${class-a}
    dict set map %top% $top
    dict set map %child% $child
    dict set map %value% $value
    dict set map %testnum% [format %04d [incr testnum]]
    putb result $map {
test oo-class-clay-method-%testnum% "Test %class% %top% %child% exists" {
  %class% clay exists %top% %child%
} 1
}
    dict set map %test% [format %04d [incr testnum]]
    putb result $map {
test oo-class-clay-method-%testnum% "Test %class% %top% %child% value" {
  %class% clay get %top% %child%
} {%value%}
}
  }
}


set class-b ::foo::classb
set claydict-b {
  const/ {color black flavor vanilla feeling dread}
  info/  {subelement {spoon yes}}
}
set commands-b {}
foreach {top children} ${claydict-b} {
  foreach {child value} $children {
    putb commands-b "  [list clay set $top $child $value]"
    putb commands-b "  [list method $child {} [list return $value]]"
  }
}
putb result [list %class% ${class-b} %commands% ${commands-b}] {
clay::define %class% {
%commands%
}
}

foreach {top children} ${claydict-b} {
  foreach {child value} $children {
    set map {}
    dict set map %class% ${class-b}
    dict set map %top% $top
    dict set map %child% $child
    dict set map %value% $value
    dict set map %testnum% [format %04d [incr testnum]]
    putb result $map {
test oo-class-clay-method-%testnum% "Test %class% %top% %child% exists" {
  %class% clay exists %top% %child%
} 1
}
    dict set map %test% [format %04d [incr testnum]]
    putb result $map {
test oo-class-clay-method-%testnum% "Test %class% %top% %child% value" {
  %class% clay get %top% %child%
} {%value%}
}
  }
}

set commands-c {superclass ::foo::classb ::foo::classa}
set class-c ::foo::class.ab
putb result [list %class% ${class-c} %commands% ${commands-c}] {
clay::define %class% {
%commands%
}
}
set commands-d {superclass ::foo::classa ::foo::classb}
set class-d ::foo::class.ba
putb result [list %class% ${class-d} %commands% ${commands-d}] {
clay::define %class% {
%commands%
}
}

###
# Tests for objects
###

putb result {# -------------------------------------------------------------------------
# Singleton
::clay::define ::test::singletonbehavior {
  method bar {} {
    return CLASS
  }
  method booze {} {
    return CLASS
  }
  Ensemble foo::bang {} {
    return CLASS
  }
  Ensemble foo::both {} {
    return CLASS
  }
  Ensemble foo::mixin {} {
    return CLASS
  }
  Ensemble foo::sloppy {} {
    return CLASS
  }
}
::clay::define ::test::flavor.strawberry {
  clay define property flavor strawbery
  method bar {} {
    return STRAWBERRY
  }
  Ensemble foo::bing {} {
    return STRAWBERRY
  }
  Ensemble foo::both {} {
    return STRAWBERRY
  }
  Ensemble foo::mixin {} {
    return STRAWBERRY
  }
  Ensemble foo::sloppy {} {
    return STRAWBERRY
  }
}
::clay::singleton ::TEST {
  class ::test::singletonbehavior
  clay mixinmap flavor ::test::flavor.strawberry
  clay set property color green
  method bar {} {
    return OBJECT
  }
  method booze {} {
    return OBJECT
  }
  method baz {} {
    return OBJECT
  }
  Ensemble foo::bar {} {
    return OBJECT
  }
  Ensemble foo::both {} {
    return OBJECT
  }
}

test oo-object-singleton-001 {Test singleton superclass keyword} {
  ::TEST clay delegate class
} {::test::singletonbehavior}

test oo-object-singleton-002 {Test singleton ensemble 1} {
  ::TEST foo <list>
} {bang bar bing both mixin sloppy}

test oo-object-singleton-003 {Test singleton ensemble from script} {
  ::TEST foo bar
} {OBJECT}
test oo-object-singleton-004 {Test singleton ensemble from mixin} {
  ::TEST foo bing
} {STRAWBERRY}
test oo-object-singleton-005 {Test singleton ensemble from class} {
  ::TEST foo bang
} {CLASS}
# Test note: the behavior from TclOO is unexpected
# Intuitively, a local method should override a mixin
# but this is not the case
test oo-object-singleton-006 {Test singleton ensemble from conflict, should resolve to object} {
  ::TEST foo both
} {STRAWBERRY}
test oo-object-singleton-007 {Test singleton ensemble from conflict, should resolve to mixin} {
  ::TEST foo sloppy
} {STRAWBERRY}
###
# Test note:
# This should work but does not
###
#test oo-object-singleton-009 {Test property from mixin/class} {
#  ::TEST clay get property flavor
#} {strawberry}
test oo-object-singleton-008 {Test property from script} {
  ::TEST clay get property color
} {green}


# Test note: the behavior from TclOO is unexpected
# Intuitively, a local method should override a mixin
# but this is not the case
test oo-object-singleton-010 {Test method declared in script} {
  ::TEST bar
} {STRAWBERRY}

test oo-object-singleton-011 {Test method declared in script} {
  ::TEST booze
} {OBJECT}
TEST destroy

# OBJECT of ::foo::classa
set OBJECTA [::foo::classa new]

###
# Test object degation
###
proc ::foo::fakeobject {a b} {
  return [expr {$a + $b}]
}

::clay::object create TEST
TEST clay delegate funct ::foo::fakeobject
test oo-object-delegate-001 {Test object delegation} {
  ::TEST clay delegate
} {<class> ::clay::object <funct> ::foo::fakeobject}

test oo-object-delegate-002 {Test object delegation} {
  ::TEST clay delegate funct
} {::foo::fakeobject}

test oo-object-delegate-002a {Test object delegation} {
  ::TEST clay delegate <funct>
} {::foo::fakeobject}

test oo-object-delegate-003 {Test object delegation} {
  ::TEST <funct> 1 1
} {2}
test oo-object-delegate-004 {Test object delegation} {
  ::TEST <funct> 10 -7
} {3}

# Replace the function out from under
proc ::foo::fakeobject {a b} {
  return [expr {$a * $b}]
}
test oo-object-delegate-005 {Test object delegation} {
  ::TEST <funct> 10 -7
} {-70}

# Object with ::foo::classa mixed in
set MIXINA  [::oo::object new]
oo::objdefine $MIXINA mixin ::foo::classa
}
set matrix ${claydict-a}
set testnum 0
foreach {top children} $matrix {
  foreach {child value} $children {
    set map {}
    dict set map %object1% OBJECTA
    dict set map %object2% MIXINA

    dict set map %top% $top
    dict set map %child% $child
    dict set map %value% $value
    dict set map %testnum% [format %04d [incr testnum]]
    putb result $map {
test oo-object-clay-method-native-%testnum% {Test native object gets the property %top%/%child%} {
  $%object1% clay get %top% %child%
} {%value%}
test oo-object-clay-method-mixin-%testnum% {Test mixin object gets the property %top%/%child%} {
  $%object2% clay get %top% %child%
} {%value%}
}
    if {$top eq "const/"} {
      putb result $map {
test oo-object-clay-method-native-methodcheck-%testnum% {Test that %top%/%child% would mimic method interheritance for a native class} {
  $%object1% %child%
} {%value%}
test oo-object-clay-method-mixin-%testnum% {Test that %top%/%child% would mimic method interheritance for a mixed in class} {
  $%object2% %child%
} {%value%}
    }
    }
  }
}

putb result {# -------------------------------------------------------------------------
# OBJECT of ::foo::classb
set OBJECTB [::foo::classb new]
# Object with ::foo::classb mixed in
set MIXINB  [::oo::object new]
oo::objdefine $MIXINB mixin ::foo::classb
}
set matrix ${claydict-b}
#set testnum 0
foreach {top children} $matrix {
  foreach {child value} $children {
    set map {}
    dict set map %object1% OBJECTB
    dict set map %object2% MIXINB

    dict set map %top% $top
    dict set map %child% $child
    dict set map %value% $value
    dict set map %testnum% [format %04d [incr testnum]]
    putb result $map {
test oo-object-clay-method-native-%testnum% {Test native object gets the property %top%/%child%} {
  $%object1% clay get %top% %child%
} {%value%}
test oo-object-clay-method-mixin-%testnum% {Test mixin object gets the property %top%/%child%} {
  $%object2% clay get %top% %child%
} {%value%}
}
    if {$top eq "const/"} {
      putb result $map {
test oo-object-clay-method-native-methodcheck-%testnum% {Test that %top%/%child% would mimic method interheritance for a native class} {
  $%object1% %child%
} {%value%}
test oo-object-clay-method-mixin-%testnum% {Test that %top%/%child% would mimic method interheritance for a mixed in class} {
  $%object2% %child%
} {%value%}
    }
    }
  }
}

putb result {# -------------------------------------------------------------------------
# OBJECT descended from ::foo::classa ::foo::classb
set OBJECTAB [::foo::class.ab new]
# Object where classes were mixed in ::foo::classa ::foo::classb
set MIXINAB  [::oo::object new]
# Test modified 2018-10-30, mixin order was wrong before
oo::objdefine $MIXINAB mixin ::foo::classb ::foo::classa
}
set matrix ${claydict-b}
foreach {top children} ${claydict-a} {
  foreach {child value} $children {
    if {![dict exists $matrix $top $child]} {
      dict set matrix $top $child $value
    }
  }
}
#set testnum 0
foreach {top children} $matrix {
  foreach {child value} $children {
    set map {}
    dict set map %object1% OBJECTAB
    dict set map %object2% MIXINAB

    dict set map %top% $top
    dict set map %child% $child
    dict set map %value% $value
    dict set map %testnum% [format %04d [incr testnum]]
    putb result $map {
test oo-object-clay-method-native-%testnum% {Test native object gets the property %top%/%child%} {
  $%object1% clay get %top% %child%
} {%value%}
test oo-object-clay-method-mixin-%testnum% {Test mixin object gets the property %top%/%child%} {
  $%object2% clay get %top% %child%
} {%value%}
}
    if {$top eq "const/"} {
      putb result $map {
test oo-object-clay-method-native-methodcheck-%testnum% {Test that %top%/%child% would mimic method interheritance for a native class} {
  $%object1% %child%
} {%value%}
test oo-object-clay-method-mixin-%testnum% {Test that %top%/%child% would mimic method interheritance for a mixed in class} {
  $%object2% %child%
} {%value%}
    }
    }
  }
}

putb result {# -------------------------------------------------------------------------
# OBJECT descended from ::foo::classb ::foo::classa
set OBJECTBA [::foo::class.ba new]
# Object where classes were mixed in ::foo::classb ::foo::classa
set MIXINBA  [::oo::object new]
# Test modified 2018-10-30, mixin order was wrong before
oo::objdefine $MIXINBA mixin ::foo::classa ::foo::classb
}
set matrix ${claydict-a}
foreach {top children} ${claydict-b} {
  foreach {child value} $children {
    if {![dict exists $matrix $top $child]} {
      dict set matrix $top $child $value
    }
  }
}
#set testnum 0
foreach {top children} $matrix {
  foreach {child value} $children {
    set map {}
    dict set map %object1% OBJECTBA
    dict set map %object2% MIXINBA

    dict set map %top% $top
    dict set map %child% $child
    dict set map %value% $value
    dict set map %testnum% [format %04d [incr testnum]]
    putb result $map {
test oo-object-clay-method-native-%testnum% {Test native object gets the property} {
  $%object1% clay get %top% %child%
} {%value%}
test oo-object-clay-method-mixin-%testnum% {Test mixin object gets the property} {
  $%object2% clay get %top% %child%
} {%value%}
}

    if {$top eq "const/"} {
      putb result $map {
test oo-object-clay-method-native-methodcheck-%testnum% {Test that %top%/%child% would mimic method interheritance for a native class} {
  $%object1% %child%
} {%value%}
test oo-object-clay-method-mixin-%testnum% {Test that %top%/%child% would mimic method interheritance for a mixed in class} {
  $%object2% %child%
} {%value%}
    }
    }
  }
}

putb resut {
###
# Test local setting if clay data in an object
###
set OBJECT [::foo::classa new]
test oo-object-clay-method-local-0001 {Test native object gets the property} {
  $OBJECT clay get const/ color
} {blue}
test oo-object-clay-method-local-0002 {Test that local settings override the inherited properties} {
  $OBJECT clay set const/ color black
  $OBJECT clay set const/
} {black}

test oo-object-clay-method-local-0003 {Test native object gets an empty property} {
  $OBJECT clay get color
} {}
test oo-object-clay-method-local-0004 {Test that local settings override the empty property} {
  $OBJECT clay set color orange
  $OBJECT clay get color
} {orange}

}

putb result {
###
# put a do-nothing constructor on the books
###
::clay::define ::clay::object {
  constructor args {}
}

oo::objdefine ::clay::object method foo args { return bar }

test clay-core-method-0001 {Test that adding methods to the core ::clay::object class works} {
  ::clay::object foo
} {bar}

namespace eval ::TEST {}
::clay::define ::TEST::myclass {
  clay color red
  clay flavor strawberry

}

###
# Test adding a clay property
###
test clay-class-clay-0001 {Test that a clay statement is recorded in the object of the class} {
  ::TEST::myclass clay get color
} red
test clay-class-clay-0002 {Test that a clay statement is recorded in the object of the class} {
  ::TEST::myclass clay get flavor
} strawberry

###
# Test that objects of the class get the same properties
###
set OBJ [::clay::object new {}]
set OBJ2 [::TEST::myclass new {}]

test clay-object-clay-a-0001 {Test that objects not thee class do not get properties} {
  $OBJ clay get color
} {}
test clay-object-clay-a-0002 {Test that objects not thee class do not get properties} {
  $OBJ clay get flavor
} {}
test clay-object-clay-a-0003 {Test that objects of the class get properties} {
  $OBJ2 clay get color
} red
test clay-object-clay-a-0004 {Test that objects of the class get properties} {
  $OBJ2 clay get flavor
} strawberry

###
# Test modified 2018-10-21
###
test clay-object-clay-a-0005 {Test the clay ancestors function} {
  $OBJ clay ancestors
} {::clay::object}

###
# Test modified 2018-10-21
###
test clay-object-clay-a-0006 {Test the clay ancestors function} {
  $OBJ2 clay ancestors
} {::TEST::myclass ::clay::object}

test clay-object-clay-a-0007 {Test the clay provenance  function} {
  $OBJ2 clay provenance  flavor
} ::TEST::myclass

###
# Test that object local setting override the class
###
test clay-object-clay-a-0008 {Test that object local setting override the class} {
  $OBJ2 clay set color purple
  $OBJ2 clay get color
} purple
test clay-object-clay-a-0009 {Test that object local setting override the class} {
  $OBJ2 clay provenance  color
} self

::clay::define ::TEST::myclasse {
  superclass ::TEST::myclass

  clay color blue
  method do args {
    return "I did $args"
  }

  Ensemble which::color {} {
    return [my clay get color]
  }
  clay set method_ensemble which farbe: {tailcall my Which_color {*}$args}
}

###
# Test clay information is passed town to subclasses
###
test clay-class-clay-0003 {Test that a clay statement is recorded in the object of the class} {
  ::TEST::myclasse clay get color
} blue
test clay-class-clay-0004 {Test that clay statements from the ancestors of this class are not present (we handle them seperately in objects)} {
  ::TEST::myclasse clay get flavor
} {}
test clay-class-clay-0005 {Test that clay statements from the ancestors of this class are found with the FIND method} {
  ::TEST::myclasse clay find flavor
} {strawberry}

###
# Test that properties reach objects
###
set OBJ3 [::TEST::myclasse new {}]
test clay-object-clay-b-0001 {Test that objects of the class get properties} {
  $OBJ3 clay get color
} blue
test clay-object-clay-b-0002 {Test the clay provenance  function} {
  $OBJ3 clay provenance  color
} ::TEST::myclasse
test clay-object-clay-b-0003 {Test that objects of the class get properties} {
  $OBJ3 clay get flavor
} strawberry
test clay-object-clay-b-0004 {Test the clay provenance  function} {
  $OBJ3 clay provenance  flavor
} ::TEST::myclass

###
# Test modified 2018-10-21
###
test clay-object-clay-b-0005 {Test the clay provenance  function} {
  $OBJ3 clay ancestors
} {::TEST::myclasse ::TEST::myclass ::clay::object}

###
# Test defining a standard method
###
test clay-object-method-0001 {Test and standard method} {
  $OBJ3 do this really cool thing
} {I did this really cool thing}

test clay-object-method-0003 {Test an ensemble} {
  $OBJ3 which color
} blue
# Test setting properties
test clay-object-method-0004 {Test an ensemble} {
  $OBJ3 clay set color black
  $OBJ3 which color
} black

# Test setting properties
test clay-object-method-0004 {Test an ensemble alias} {
  $OBJ3 which farbe
} black


###
# Added 2019-06-24
# Test that grabbing a leaf does not pollute the cache
###
::clay::define ::TEST::class_with_deep_tree {
  clay set tree deep has depth 1
  clay set tree shallow has depth 0
}

$OBJ3 clay mixinmap deep ::TEST::class_with_deep_tree

test clay-deep-nested-0001 {Test that a leaf query does not pollute the cache} {
  $OBJ3 clay get tree shallow has depth
} 0
test clay-deep-nested-0001 {Test that a leaf query does not pollute the cache} {
  $OBJ3 clay get tree
} {deep {has {depth 1}} shallow {has {depth 0}}}



###
# Test that if you try to replace a global command you get an error
###
test clay-nspace-0001 {Test that if you try to replace a global command you get an error} -body {
::clay::define open {
  method bar {} { return foo }

}
}  -returnCodes {error} -result "::open does not refer to an object"

::clay::define fubar {
  method bar {} { return foo }
}
test clay-nspace-0002 {Test a non qualified class ends up in the current namespace} {
  info commands ::fubar
} {::fubar}

namespace eval ::cluster {
::clay::define fubar {
  method bar {} { return foo }
}

::clay::define ::clay::pot {
  method bar {} { return foo }
}

}
test clay-nspace-0003 {Test a non qualified class ends up in the current namespace} {
  info commands ::cluster::fubar
} {::cluster::fubar}
test clay-nspace-0003 {Test a fully qualified class ends up in the proper namespace} {
  info commands ::clay::pot
} {::clay::pot}

#set ::clay::trace 3

###
# New test - Added 2019-09-15
# Test that the "method" variable is exposed to a default method
###

::clay::define ::ensembleWithDefault {
  Ensemble foo::bar {} { return A }
  Ensemble foo::baz {} { return B }
  Ensemble foo::bang {} { return C }

  Ensemble foo::default {} { return $method }
}


set OBJ [::ensembleWithDefault new]
test clay-ensemble-default-0001 {Test a normal ensemble method} {
  $OBJ foo bar
} {A}
test clay-ensemble-default-0002 {Test a normal ensemble method} {
  $OBJ foo baz
} {B}
test clay-ensemble-default-0003 {Test a normal ensemble method} {
  $OBJ foo <list>
} [lsort -dictionary {bar baz bang}]

test clay-ensemble-default-0004 {Test a normal ensemble method} {
  $OBJ foo bing
} {bing}
test clay-ensemble-default-0005 {Test a normal ensemble method} {
  $OBJ foo bong
} {bong}
###
# Mixin tests
###

###
# Define a core class
###
::clay::define ::TEST::thing {

  method do args {
    return "I did $args"
  }
}


::clay::define ::TEST::vegetable {

  clay color unknown
  clay flavor unknown

  Ensemble which::flavor {} {
    return [my clay get flavor]
  }
  Ensemble which::color {} {
    return [my clay get color]
  }

}

::clay::define ::TEST::animal {

  clay color unknown
  clay sound unknown

  Ensemble which::sound {} {
    return [my clay get sound]
  }
  Ensemble which::color {} {
    return [my clay get color]
  }
  method sound {} {
    return unknown
  }
}

::clay::define ::TEST::species.cat {
  superclass ::TEST::animal
  clay sound meow
  method sound {} {
    return meow
  }
}

::clay::define ::TEST::coloring.calico {
  clay color calico

}

::clay::define ::TEST::condition.dark {
  Ensemble which::color {} {
    return grey
  }
}

::clay::define ::TEST::mood.happy {
  Ensemble which::sound {} {
    return purr
  }
  method sound {} {
    return purr
  }
}
test clay-object-0001 {Test than an object is created when clay::define is invoked} {
  info commands ::TEST::mood.happy
} ::TEST::mood.happy

set OBJ [::TEST::thing new]
test clay-mixin-a-0001 {Test that prior to a mixin an ensemble doesn't exist} -body {
  $OBJ which color
} -returnCodes error -result {unknown method "which": must be clay, destroy or do}

test clay-mixin-a-0002 {Test and standard method from an ancestor} {
  $OBJ do this really cool thing
} {I did this really cool thing}

$OBJ clay mixinmap species ::TEST::animal
test clay-mixin-b-0001 {Test that an ensemble is created during a mixin} {
  $OBJ which color
} {unknown}

test clay-mixin-b-0002 {Test that an ensemble is created during a mixin} {
  $OBJ which sound
} {unknown}

test clay-mixin-b-0003 {Test that an ensemble is created during a mixin} \
  -body {$OBJ which flavor} -returnCodes {error} \
  -result {unknown method which flavor. Valid: color sound}

###
# Test Modified: 2018-10-21
###
test clay-mixin-b-0004 {Test that mixins resolve in the correct order} {
  $OBJ clay ancestors
} {::TEST::animal ::TEST::thing ::clay::object}

###
# Replacing a mixin replaces the behaviors
###
$OBJ clay mixinmap species ::TEST::vegetable
test clay-mixin-c-0001 {Test that an ensemble is created during a mixin} {
  $OBJ which color
} {unknown}
test clay-mixin-c-0002 {Test that an ensemble is created during a mixin} \
  -body {$OBJ which sound} \
  -returnCodes {error} \
  -result {unknown method which sound. Valid: color flavor}
test clay-mixin-c-0003 {Test that an ensemble is created during a mixin} {
  $OBJ which flavor
} {unknown}
###
# Test Modified: 2018-10-21
###
test clay-mixin-c-0004 {Test that mixins resolve in the correct order} {
  $OBJ clay ancestors
} {::TEST::vegetable ::TEST::thing ::clay::object}

###
# Replacing a mixin
$OBJ clay mixinmap species ::TEST::species.cat
test clay-mixin-e-0001 {Test that an ensemble is created during a mixin} {
  $OBJ which color
} {unknown}
test clay-mixin-e-0002a {Test that an ensemble is created during a mixin} {
  $OBJ sound
} {meow}
test clay-mixin-e-0002b {Test that an ensemble is created during a mixin} {
  $OBJ clay get sound
} {meow}
test clay-mixin-e-0002 {Test that an ensemble is created during a mixin} {
  $OBJ which sound
} {meow}
test clay-mixin-e-0003 {Test that an ensemble is created during a mixin} \
  -body {$OBJ which flavor} -returnCodes {error} \
  -result {unknown method which flavor. Valid: color sound}
###
# Test Modified: 2018-10-30, 2018-10-21, 2018-10-10
###
test clay-mixin-e-0004 {Test that clay data follows the rules of inheritence and order of mixin} {
  $OBJ clay ancestors
} {::TEST::species.cat ::TEST::animal ::TEST::thing ::clay::object}

$OBJ clay mixinmap coloring ::TEST::coloring.calico
test clay-mixin-f-0001 {Test that an ensemble is created during a mixin} {
  $OBJ which color
} {calico}
test clay-mixin-f-0002 {Test that an ensemble is created during a mixin} {
  $OBJ which sound
} {meow}
test clay-mixin-f-0003 {Test that an ensemble is created during a mixin} \
  -body {$OBJ which flavor} -returnCodes {error} \
  -result {unknown method which flavor. Valid: color sound}

###
# Test modified 2018-10-30, 2018-10-21, 2018-10-10
###
test clay-mixin-f-0004 {Test that clay data follows the rules of inheritence and order of mixin} {
  $OBJ clay ancestors
} {::TEST::coloring.calico ::TEST::species.cat ::TEST::animal ::TEST::thing ::clay::object}

test clay-mixin-f-0005 {Test that clay data from a mixin works} {
  $OBJ clay provenance  color
} {::TEST::coloring.calico}

###
# Test variable initialization
###
::clay::define ::TEST::has_var {
  Variable my_variable 10

  method get_my_variable {} {
    my variable my_variable
    return $my_variable
  }
}

set OBJ [::TEST::has_var new]
test clay-class-variable-0001 {Test that the parser injected the right value in the right place for clay to catch it} {
  $OBJ clay get variable/ my_variable
} {10}

# Modified 2018-10-30 (order is different)
test clay-class-variable-0002 {Test that the parser injected the right value in the right place for clay to catch it} {
  $OBJ clay get variable
} {my_variable 10 DestroyEvent 0}

# Modified 2018-10-30 (order is different)
test clay-class-variable-0003 {Test that the parser injected the right value in the right place for clay to catch it} {
  $OBJ clay dget variable
} {. {} my_variable 10 DestroyEvent 0}

test clay-class-variable-0004 {Test that variables declared in the class definition are initialized} {
  $OBJ get_my_variable
} 10

###
# Test array initialization
###
::clay::define ::TEST::has_array {
  Array my_array {timeout 10}

  method get_my_array {field} {
    my variable my_array
    return $my_array($field)
  }
}

set OBJ [::TEST::has_array new]
test clay-class-array-0001 {Test that the parser injected the right value in the right place for clay to catch it} {
  $OBJ clay get array
} {my_array {timeout 10}}

test clay-class-array-0002 {Test that the parser injected the right value in the right place for clay to catch it} {
  $OBJ clay dget array
} {. {} my_array {. {} timeout 10}}

test clay-class-array-0003 {Test that variables declared in the class definition are initialized} {
  $OBJ get_my_array timeout
} 10

::clay::define ::TEST::has_more_array {
  superclass ::TEST::has_array
  Array my_array {color blue}
}
test clay-class-array-0008 {Test that the parser injected the right value in the right place for clay to catch it} {
  ::TEST::has_more_array clay get array
} {my_array {color blue}}

test clay-class-array-0009 {Test that the parser injected the right value in the right place for clay to catch it} {
  ::TEST::has_more_array clay find array
} {my_array {timeout 10 color blue}}

# Modified 2018-10-30 (order is different)
set BOBJ [::TEST::has_more_array new]
test clay-class-array-0004 {Test that the parser injected the right value in the right place for clay to catch it} {
  $BOBJ clay get array
} {my_array {color blue timeout 10}}

# Modified 2018-10-30 (order is different)
test clay-class-array-0005 {Test that the parser injected the right value in the right place for clay to catch it} {
  $BOBJ clay dget array
} {. {} my_array {. {} color blue timeout 10}}

test clay-class-arrau-0006 {Test that variables declared in the class definition are initialized} {
  $BOBJ get_my_array timeout
} 10
test clay-class-arrau-0007 {Test that variables declared in the class definition are initialized} {
  $BOBJ get_my_array color
} blue

::clay::define ::TEST::has_empty_array {
  Array my_array {}

  method my_array_exists {} {
    my variable my_array
    return [info exists my_array]
  }
  method get {field} {
    my variable my_array
    return $my_array($field)
  }
  method set {field value} {
    my variable my_array
    set my_array($field) $value
  }
}

test clay-class-array-0008 {Test that an declaration of an array with no values produces and empty array} {
  set COBJ [::TEST::has_empty_array new]
  $COBJ my_array_exists
} 1

test clay-class-array-0009 {Test that an declaration of an array with no values produces and empty array} {
  $COBJ set test "A random value"
  $COBJ get test
} {A random value}
###
# Test dict initialization
###
::clay::define ::TEST::has_dict {
  Dict my_dict {timeout 10}

  method get_my_dict {args} {
    my variable my_dict
    if {[llength $args]==0} {
      return $my_dict
    }
    return [dict get $my_dict {*}$args]
  }

}

set OBJ [::TEST::has_dict new]
test clay-class-dict-0001 {Test that the parser injected the right value in the right place for clay to catch it} {
  $OBJ clay get dict
} {my_dict {timeout 10}}

test clay-class-dict-0002 {Test that the parser injected the right value in the right place for clay to catch it} {
  $OBJ clay dget dict
} {. {} my_dict {. {} timeout 10}}

test clay-class-dict-0003 {Test that variables declared in the class definition are initialized} {
  $OBJ get_my_dict timeout
} 10

test clay-class-dict-0004 {Test that an empty dict is annotated} {
  $OBJ clay get dict
} {my_dict {timeout 10}}


::clay::define ::TEST::has_more_dict {
  superclass ::TEST::has_dict
  Dict my_dict {color blue}
}
set BOBJ [::TEST::has_more_dict new]

# Modified 2018-10-30
test clay-class-dict-0004 {Test that the parser injected the right value in the right place for clay to catch it} {
  $BOBJ clay get dict
} {my_dict {color blue timeout 10}}

# Modified 2018-10-30
test clay-class-dict-0005 {Test that the parser injected the right value in the right place for clay to catch it} {
  $BOBJ clay dget dict
} {. {} my_dict {. {} color blue timeout 10}}

test clay-class-dict-0006 {Test that variables declared in the class definition are initialized} {
  $BOBJ get_my_dict timeout
} 10

test clay-class-dict-0007 {Test that variables declared in the class definition are initialized} {
  $BOBJ get_my_dict color
} blue

::clay::define ::TEST::has_empty_dict {
  Dict my_empty_dict {}

  method get_my_empty_dict {args} {
    my variable my_empty_dict
    if {[llength $args]==0} {
      return $my_empty_dict
    }
    return [dict get $my_empty_dict {*}$args]
  }
}

set COBJ [::TEST::has_empty_dict new]

test clay-class-dict-0008 {Test that the parser injected the right value in the right place for clay to catch it} {
  $COBJ clay dget dict
} {my_empty_dict {. {}}}

test clay-class-dict-0009 {Test that an empty dict is initialized} {
  $COBJ get_my_empty_dict
} {}

###
# Test object delegation
###
::clay::define ::TEST::organelle {
  method add args {
    set total 0
    foreach item $args {
      set total [expr {$total+$item}]
    }
    return $total
  }
}
::clay::define ::TEST::master {
  constructor {} {
    set mysub [namespace current]::sub
    ::TEST::organelle create $mysub
    my clay delegate sub $mysub
  }
}

set OBJ [::TEST::master new]
###
# Test that delegation is working
###
test clay-delegation-0001 {Test an array driven ensemble} {
  $OBJ <sub> add 5 5
} 10


###
# Test the Ensemble keyword
###
::clay::define ::TEST::with_ensemble {

  Ensemble myensemble {pattern args} {
    set ensemble [self method]
    set emap [my clay ensemble_map $ensemble]
    set mlist [dict keys $emap [string tolower $pattern]]
    if {[llength $mlist] != 1} {
      error "Couldn't figure out what to do with $pattern"
    }
    set method [lindex $mlist 0]
    set argspec [dict get $emap $method argspec]
    set body    [dict get $emap $method body]
    if {$argspec ni {args {}}} {
      ::clay::dynamic_arguments $ensemble $method [list $argspec] {*}$args
    }
    eval $body
  }

  Ensemble myensemble::go args {
    return 1
  }
}

::clay::define ::TEST::with_ensemble.dance {
  Ensemble myensemble::dance args {
    return 1
  }
}
::clay::define ::TEST::with_ensemble.cannot_dance {
  Ensemble myensemble::dance args {
    return 0
  }
}

set OBJA [::clay::object new]
set OBJB [::clay::object new]

$OBJA clay mixinmap \
  core ::TEST::with_ensemble \
  friends ::TEST::with_ensemble.dance

$OBJB clay mixinmap \
  core ::TEST::with_ensemble \
  friends ::TEST::with_ensemble.cannot_dance
}

set testnum 0

set matrix {
  go {
    OBJA 1
    OBJB 1
  }
  dance {
    OBJA 1
    OBJB 0
  }
}
foreach {action output} $matrix {
  putb result "# Test $action"
  foreach {object value} $output {
    set map [dict create %object% $object %action% $action %value% $value]
    dict set map %testnum% [format %04d [incr testnum]]
    putb result $map {test clay-dynamic-ensemble-%testnum% {Test ensemble with static method} {
  $%object% myensemble %action%
} {%value%}}
  }
}

putb result {

###
# Class method testing
###

clay::class create WidgetClass {
  Class_Method working {} {
    return {Works}
  }

  Class_Method unknown args {
    set tkpath [lindex $args 0]
    if {[string index $tkpath 0] eq "."} {
      set obj [my new $tkpath {*}[lrange $args 1 end]]
      $obj tkalias $tkpath
      return $tkpath
    }
    next {*}$args
  }

  constructor {TkPath args} {
    my variable hull
    set hull $TkPath
    my clay delegate hull $TkPath
  }

  method tkalias tkname {
    set oldname $tkname
    my variable tkalias
    set tkalias $tkname
    set self [self]
    set hullwidget [::info object namespace $self]::tkwidget
    my clay delegate tkwidget $hullwidget
    #rename ::$tkalias $hullwidget
    my clay delegate hullwidget $hullwidget
    #::tool::object_rename [self] ::$tkalias
    rename [self] ::$tkalias
    #my Hull_Bind $tkname
    return $hullwidget
  }
}

test tool-class-method-000 {Test that class methods actually work...} {
  WidgetClass working
} {Works}

test tool-class-method-001 {Test Tk style creator} {
  WidgetClass .foo
  .foo clay delegate hull
} {.foo}

::clay::define WidgetNewClass {
  superclass WidgetClass
}

test tool-class-method-002 {Test Tk style creator inherited by morph} {
  WidgetNewClass .bar
  .bar clay delegate hull
} {.bar}



###
# Test ensemble inheritence
###
clay::define NestedClassA {
  Ensemble do::family {} {
    return NestedClassA
  }
  Ensemble do::something {} {
    return A
  }
  Ensemble do::whop {} {
    return A
  }
}
clay::define NestedClassB {
  superclass NestedClassA
  Ensemble do::family {} {
    set r [next family]
    lappend r NestedClassB
    return $r
  }
  Ensemble do::whop {} {
    return B
  }
}
clay::define NestedClassC {
  superclass NestedClassB

  Ensemble do::somethingelse {} {
    return C
  }
}
clay::define NestedClassD {
  superclass NestedClassB

  Ensemble do::somethingelse {} {
    return D
  }
}

clay::define NestedClassE {
  superclass NestedClassD NestedClassC
}

clay::define NestedClassF {
  superclass NestedClassC NestedClassD
}

NestedClassC create NestedObjectC

###
# These tests no longer work because method ensembles are now dynamically
# generated by object, that are not attached to the class anymore
#
####
#test tool-ensemble-001 {Test that an ensemble can access [next] even if no object of the ancestor class have been instantiated} {
#  NestedObjectC do family
#} {::NestedClassA ::NestedClassB ::NestedClassC}

test tool-ensemble-002 {Test that a later ensemble definition trumps a more primitive one} {
  NestedObjectC do whop
} {B}
test tool-ensemble-003 {Test that an ensemble definitions in an ancestor carry over} {
  NestedObjectC do something
} {A}

NestedClassE create NestedObjectE
NestedClassF create NestedObjectF


test tool-ensemble-004 {Test that ensembles follow the same rules for inheritance as methods} {
  NestedObjectE do somethingelse
} {D}

test tool-ensemble-005 {Test that ensembles follow the same rules for inheritance as methods} {
  NestedObjectF do somethingelse
} {C}

###
# Set of tests to exercise the mixinmap system
###
clay::define MixinMainClass {
  Variable mainvar unchanged

  Ensemble test::which {} {
    my variable mainvar
    return $mainvar
  }

  Ensemble test::main args {
    puts [list this is main $method $args]
  }

}

set mixoutscript {my test untool $class}
set mixinscript {my test tool $class}
clay::define MixinTool {
  Variable toolvar unchanged.mixin
  clay set mixin/ unmap-script $mixoutscript
  clay set mixin/ map-script $mixinscript
  clay set mixin/ name {Generic Tool}

  Ensemble test::untool class {
    my variable toolvar mainvar
    set mainvar {}
    set toolvar {}
  }

  Ensemble test::tool class {
    my variable toolvar mainvar
    set mainvar [$class clay get mixin name]
    set toolvar [$class clay get mixin name]
  }
}

clay::define MixinToolA {
  superclass MixinTool

  clay set mixin/ name {Tool A}
}

clay::define MixinToolB {
  superclass MixinTool

  clay set mixin/ name {Tool B}

  method test_newfunc {} {
    return "B"
  }
}

test tool-mixinspec-001 {Test application of mixin specs} {
  MixinTool clay get mixin map-script
} $mixinscript

test tool-mixinspec-002 {Test application of mixin specs} {
  MixinToolA clay get mixin map-script
} {}

test tool-mixinspec-003 {Test application of mixin specs} {
  MixinToolA clay find mixin map-script
} $mixinscript

test tool-mixinspec-004 {Test application of mixin specs} {
  MixinToolB clay find mixin map-script
} $mixinscript


MixinMainClass create mixintest

test tool-mixinmap-001 {Test object prior to mixins} {
  mixintest test which
} {unchanged}

mixintest clay mixinmap tool MixinToolA
test tool-mixinmap-002 {Test mixin map script ran} {
  mixintest test which
} {Tool A}

mixintest clay mixinmap tool MixinToolB

test tool-mixinmap-003 {Test mixin map script ran} {
  mixintest test which
} {Tool B}

test tool-mixinmap-003 {Test mixin map script ran} {
  mixintest test_newfunc
} {B}

mixintest clay mixinmap tool {}
test tool-mixinmap-004 {Test object prior to mixins} {
  mixintest test which
} {}
}

###
# Test clay mixinslots
###
putb result {

clay::define ::clay::object {
  method path {} {
    return [self class]
  }
}


clay::define ::MixinRoot {
  clay set opts core   root
  clay set opts option unset
  clay set opts color  unset

  Ensemble info::root {} {
    return MixinRoot
  }
  Ensemble info::shade {} {
    return avacodo
  }
  Ensemble info::default {} {
    return Undefined
  }

  method did {} {
    return MixinRoot
  }

  method path {} {
    return [list [self class] {*}[next]]
  }
}

clay::define ::MixinOption1 {
  clay set opts option option1

  Ensemble info::option {} {
    return MixinOption1
  }
  Ensemble info::other {} {
    return MixinOption1
  }

  method did {} {
    return MixinOption1
  }

  method path {} {
    return [list [self class] {*}[next]]
  }
}

clay::define ::MixinOption2 {
  superclass ::MixinOption1

  clay set opts option option2

  Ensemble info::option {} {
    return MixinOption2
  }

  method did {} {
    return MixinOption2
  }

  method path {} {
    return [list [self class] {*}[next]]
  }
}


clay::define ::MixinColor1 {
  clay set opts color blue

  Ensemble info::color {} {
    return MixinColor1
  }
  Ensemble info::shade {} {
    return blue
  }

  method did {} {
    return MixinColor1
  }

  method path {} {
    return [list [self class] {*}[next]]
  }
}

clay::define ::MixinColor2 {
  clay set opts color green

  Ensemble info::color {} {
    return MixinColor2
  }
  Ensemble info::shade {} {
    return green
  }

  method did {} {
    return MixinColor2
  }

  method path {} {
    return [list [self class] {*}[next]]
  }
}

set obj [clay::object new]

$obj clay mixinmap root ::MixinRoot
}
set testnum 0
set batnum  0

set obj {$obj}
set template {
test tool-prototype-%battery%-%test% {%comment%} {
  %obj% %method%
} {%answer%}
}
set map {}

dict set map %obj% {$obj}
dict set map %battery% [format %04d [incr batnum]]
dict set map %comment% {Mixin core}

foreach {method answer} {
  {info root} {MixinRoot}
  {info option} {Undefined}
  {info color} {Undefined}
  {info other} {Undefined}
  {info shade} {avacodo}
  {did} {MixinRoot}
  {path} {::MixinRoot ::clay::object}
  {clay get opts} {core root option unset color unset}
  {clay get opts core} root
  {clay get opts option} unset
  {clay get opts color} unset
  {clay ancestors} {::MixinRoot ::clay::object}
} {
  set testid [format %04d [incr testnum]]
  dict set map %test% $testid
  dict set map %method% $method
  dict set map %answer% $answer
  putb result $map $template
}

set testnum 0
putb result {$obj clay mixinmap option ::MixinOption1}
dict set map %battery% [format %04d [incr batnum]]
dict set map %comment% {Mixin option1}
foreach {method answer} {
  {info root} {MixinRoot}
  {info option} {MixinOption1}
  {info color} {Undefined}
  {info other} {MixinOption1}
  {info shade} {avacodo}
  {did} {MixinOption1}
  {path} {::MixinOption1 ::MixinRoot ::clay::object}
  {clay get opts} {option option1 core root color unset}
  {clay get opts core} root
  {clay get opts option} option1
  {clay get opts color} unset
  {clay ancestors} {::MixinOption1 ::MixinRoot ::clay::object}
} {
  set testid [format %04d [incr testnum]]
  dict set map %test% $testid
  dict set map %method% $method
  dict set map %answer% $answer
  putb result $map $template
}

set testnum 0
putb result {
set obj2 [clay::object new]
$obj2 clay mixinmap root ::MixinRoot option ::MixinOption1
}
putb result {$obj clay mixinmap option ::MixinOption1}
dict set map %obj% {$obj2}
dict set map %battery% [format %04d [incr batnum]]
dict set map %comment% {Mixin option1 - clean object}
foreach {method answer} {
  {info root} {MixinRoot}
  {info option} {MixinOption1}
  {info color} {Undefined}
  {info other} {MixinOption1}
  {info shade} {avacodo}
  {did} {MixinOption1}
  {path} {::MixinOption1 ::MixinRoot ::clay::object}
  {clay get opts} {option option1 core root color unset}
  {clay get opts core} root
  {clay get opts option} option1
  {clay get opts color} unset
  {clay ancestors} {::MixinOption1 ::MixinRoot ::clay::object}
} {
  set testid [format %04d [incr testnum]]
  dict set map %test% $testid
  dict set map %method% $method
  dict set map %answer% $answer
  putb result $map $template
}

set testnum 0
putb result {$obj clay mixinmap option ::MixinOption2}
dict set map %battery% [format %04d [incr batnum]]
dict set map %comment% {Mixin option2}
dict set map %obj% {$obj}
foreach {method answer} {
  {info root} {MixinRoot}
  {info option} {MixinOption2}
  {info color} {Undefined}
  {info other} {MixinOption1}
  {info shade} {avacodo}
  {did} {MixinOption2}
  {path} {::MixinOption2 ::MixinOption1 ::MixinRoot ::clay::object}
  {clay get opts} {option option2 core root color unset}
  {clay get opts core} root
  {clay get opts option} option2
  {clay get opts color} unset
  {clay ancestors} {::MixinOption2 ::MixinOption1 ::MixinRoot ::clay::object}
} {
  set testid [format %04d [incr testnum]]
  dict set map %test% $testid
  dict set map %method% $method
  dict set map %answer% $answer
  putb result $map $template
}

set testnum 0
putb result {$obj clay mixinmap color MixinColor1}
dict set map %battery% [format %04d [incr batnum]]
dict set map %comment% {Mixin color1}
foreach {method answer} {
  {info root} {MixinRoot}
  {info option} {MixinOption2}
  {info color} {MixinColor1}
  {info other} {MixinOption1}
  {info shade} {blue}
  {did} {MixinColor1}
  {path} {::MixinColor1 ::MixinOption2 ::MixinOption1 ::MixinRoot ::clay::object}
  {clay get opts} {color blue option option2 core root}
  {clay get opts core} root
  {clay get opts option} option2
  {clay get opts color} blue
  {clay ancestors} {::MixinColor1 ::MixinOption2 ::MixinOption1 ::MixinRoot ::clay::object}
} {
  set testid [format %04d [incr testnum]]
  dict set map %test% $testid
  dict set map %method% $method
  dict set map %answer% $answer
  putb result $map $template
}
set testnum 0
putb result {$obj clay mixinmap color MixinColor2}
dict set map %battery% [format %04d [incr batnum]]
dict set map %comment% {Mixin color2}
foreach {method answer} {
  {info root} {MixinRoot}
  {info option} {MixinOption2}
  {info color} {MixinColor2}
  {info other} {MixinOption1}
  {info shade} {green}
  {clay get opts} {color green option option2 core root}
  {clay get opts core} root
  {clay get opts option} option2
  {clay get opts color} green
  {clay ancestors} {::MixinColor2 ::MixinOption2 ::MixinOption1 ::MixinRoot ::clay::object}
} {
  set testid [format %04d [incr testnum]]
  dict set map %test% $testid
  dict set map %method% $method
  dict set map %answer% $answer
  putb result $map $template
}

set testnum 0
putb result {$obj clay mixinmap option MixinOption1}
dict set map %battery% [format %04d [incr batnum]]
dict set map %comment% {Mixin color2 + Option1}
foreach {method answer} {
  {info root} {MixinRoot}
  {info option} {MixinOption1}
  {info color} {MixinColor2}
  {info other} {MixinOption1}
  {info shade} {green}
  {clay get opts} {color green option option1 core root}
  {clay get opts core} root
  {clay get opts option} option1
  {clay get opts color} green
  {clay ancestors} {::MixinColor2 ::MixinOption1 ::MixinRoot ::clay::object}
} {
  set testid [format %04d [incr testnum]]
  dict set map %test% $testid
  dict set map %method% $method
  dict set map %answer% $answer
  putb result $map $template
}

set testnum 0
putb result {$obj clay mixinmap option {}}
dict set map %battery% [format %04d [incr batnum]]
dict set map %comment% {Mixin color2 + no option}
foreach {method answer} {
  {info root} {MixinRoot}
  {info option} {Undefined}
  {info color} {MixinColor2}
  {info other} {Undefined}
  {info shade} {green}
  {clay get opts} {color green core root option unset}
  {clay get opts core} root
  {clay get opts option} unset
  {clay get opts color} green
  {clay ancestors} {::MixinColor2 ::MixinRoot ::clay::object}
} {
  set testid [format %04d [incr testnum]]
  dict set map %test% $testid
  dict set map %method% $method
  dict set map %answer% $answer
  putb result $map $template
}

set testnum 0
putb result {$obj clay mixinmap color {}}
dict set map %battery% [format %04d [incr batnum]]
dict set map %comment% {Mixin core (return to normal)}
foreach {method answer} {
  {info root} {MixinRoot}
  {info option} {Undefined}
  {info color} {Undefined}
  {info other} {Undefined}
  {info shade} {avacodo}
  {clay get opts} {core root option unset color unset}
  {clay get opts core} root
  {clay get opts option} unset
  {clay get opts color} unset
  {clay ancestors} {::MixinRoot ::clay::object}
} {
  set testid [format %04d [incr testnum]]
  dict set map %test% $testid
  dict set map %method% $method
  dict set map %answer% $answer
  putb result $map $template
}

putb result {
###
# Tip479 Tests
###
clay::define tip479class {

  Method newitem dictargs {
    id {type: number}
    color {default: green}
    shape {options: {round square}}
    flavor {default: grape}
  } {
    my variable items
    foreach {f v} $args {
      dict set items $id $f $v
    }
    if {"color" ni [dict keys $args]} {
      dict set items $id color $color
    }
    return [dict get $items $id]
  }

  method itemget {id field} {
    my variable items
    return [dict get $id $field]
  }
}

set obj [tip479class new]
test tip479-001 {Test that a later ensemble definition trumps a more primitive one} {
  $obj newitem id 1 color orange shape round
} {id 1 color orange shape round}

# Fail because we left off a mandatory argument
test tip479-002 {Test that a later ensemble definition trumps a more primitive one} \
  -errorCode NONE -body {
  $obj newitem id 2
} -result {shape is required}

###
# Leave off a value that has a default
# note: Method had special handling for color, but not flavor
###
test tip479-003 {Test that a later ensemble definition trumps a more primitive one} {
  $obj newitem id 3 shape round
} {id 3 shape round color green}

###
# Add extra arguments
###
test tip479-004 {Test that a later ensemble definition trumps a more primitive one} {
  $obj newitem id 4 shape round trim leather
} {id 4 shape round trim leather color green}

clay::define tip479classE {

  Ensemble item::new dictargs {
    id {type: number}
    color {default: green}
    shape {options: {round square}}
    flavor {default: grape}
  } {
    my variable items
    foreach {f v} $args {
      dict set items $id $f $v
    }
    if {"color" ni [dict keys $args]} {
      dict set items $id color $color
    }
    return [dict get $items $id]
  }

  Ensemble item::get {id field} {
    my variable items
    return [dict get $id $field]
  }
}


set obj [tip479classE new]
test tip479-001 {Test that a later ensemble definition trumps a more primitive one} {
  $obj item new id 1 color orange shape round
} {id 1 color orange shape round}

# Fail because we left off a mandatory argument
test tip479-002 {Test that a later ensemble definition trumps a more primitive one} \
  -errorCode NONE -body {
  $obj item new id 2
} -result {shape is required}

###
# Leave off a value that has a default
# note: Method had special handling for color, but not flavor
###
test tip479-003 {Test that a later ensemble definition trumps a more primitive one} {
  $obj item new id 3 shape round
} {id 3 shape round color green}

###
# Add extra arguments
###
test tip479-004 {Test that a later ensemble definition trumps a more primitive one} {
  $obj item new id 4 shape round trim leather
} {id 4 shape round trim leather color green}

}

###
# TESTS NEEDED:
# destructor
###

putb result {
testsuiteCleanup

# Local variables:
# mode: tcl
# indent-tabs-mode: nil
# End:
}
return $result
