
[//000000001]: # (huddle \- HUDDLE)
[//000000002]: # (Generated from file 'huddle\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2008\-2011 KATO Kanryu <kanryu6@users\.sourceforge\.net>)
[//000000004]: # (Copyright &copy; 2015 Miguel Martínez López <aplicacionamedida@gmail\.com>)
[//000000005]: # (huddle\(n\) 0\.4 tcllib "HUDDLE")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

huddle \- Create and manipulate huddle object

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [TYPE CALLBACK](#section3)

  - [How to add type](#section4)

  - [WORKING SAMPLE](#section5)

  - [LIMITATIONS](#section6)

  - [Bugs, Ideas, Feedback](#section7)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require huddle ?0\.4?  

[__huddle create__ *key* *value* ?*key value \.\.\.*?](#1)  
[__huddle list__ ?*value value \.\.\.*?](#2)  
[__huddle number__ *number*](#3)  
[__huddle string__ *string*](#4)  
[__huddle boolean__ *expression to evaluate as true or false*](#5)  
[__huddle true__](#6)  
[__huddle false__](#7)  
[__huddle null__](#8)  
[__huddle get__ *object* *key* ?*key \.\.\.*?](#9)  
[__huddle gets__ *object* *key* ?*key \.\.\.*?](#10)  
[__huddle set__ *objectVar* *key* ?*key \.\.\.*? *value*](#11)  
[__huddle remove__ *object* *key* ?*key \.\.\.*?](#12)  
[__huddle combine__ *object1* *object2* ?*object3 \.\.\.*?](#13)  
[__huddle equal__ *object1* *object2*](#14)  
[__huddle append__ *objectVar* *key* *value* ?*key value \.\.\.*?](#15)  
[__huddle append__ *objectVar* *value* ?*value \.\.\.*?](#16)  
[__huddle keys__ *object*](#17)  
[__huddle llength__ *object*](#18)  
[__huddle type__ *object* ?*key key\.\.\.*?](#19)  
[__huddle strip__ *object*](#20)  
[__huddle jsondump__ *object* ?*offset*? ?*newline*? ?*begin\_offset*?](#21)  
[__huddle compile__ *spec* *data*](#22)  
[__huddle isHuddle__ *object*](#23)  
[__huddle checkHuddle__ *object*](#24)  
[__huddle to\_node__ *object* ?*tag*?](#25)  
[__huddle wrap__ *tag* *src*](#26)  
[__huddle call__ *tag* *command* *args*](#27)  
[__huddle addType__ *callback*](#28)  
[__[callback](\.\./\.\./\.\./\.\./index\.md\#callback)__ *command* ?*args*?](#29)  
[__setting__](#30)  
[__get\_sub__ *src* *key*](#31)  
[__strip__ *src*](#32)  
[__[set](\.\./\.\./\.\./\.\./index\.md\#set)__ *src* *key* *value*](#33)  
[__[remove](\.\./\.\./\.\./\.\./index\.md\#remove)__ *src* *key* *value*](#34)  

# <a name='description'></a>DESCRIPTION

Huddle provides a generic Tcl\-based serialization/intermediary format\.
Currently, each node is wrapped in a tag with simple type information\.

When converting huddle\-notation to other serialization formats like JSON or YAML
this type information is used to select the proper notation\. And when going from
JSON/YAML/\.\.\. to huddle their notation can be used to select the proper huddle
type\.

In that manner huddle can serve as a common intermediary format\.

    huddle-format: >
      {HUDDLE {huddle-node}}
    huddle-node: >
      {tag content}
    each content of tag means:
      s: (content is a) string
      L: list, each sub node is a huddle-node
      D: dict, each sub node is a huddle-node
    confirmed:
      - JSON
      - YAML(generally, but cannot discribe YAML-tags)
    limitation:
      - cannot discribe aliases from a node to other node.

The __huddle__ package returns data as a Tcl
__[dict](\.\./\.\./\.\./\.\./index\.md\#dict)__\. Either the
__[dict](\.\./\.\./\.\./\.\./index\.md\#dict)__ package or Tcl 8\.5 is required for
use\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__huddle create__ *key* *value* ?*key value \.\.\.*?

    Create a huddle object as a dict\. It can contain other huddle objects\.

  - <a name='2'></a>__huddle list__ ?*value value \.\.\.*?

    Create a huddle object as a list\. It can contain other huddle objects\.

  - <a name='3'></a>__huddle number__ *number*

    Create a huddle object as a number\.

  - <a name='4'></a>__huddle string__ *string*

    Create a huddle object as a string\.

  - <a name='5'></a>__huddle boolean__ *expression to evaluate as true or false*

    Create a huddle object as a boolean evaluating an expression as true or
    false\-

  - <a name='6'></a>__huddle true__

    Create a huddle object as a boolean true\.

  - <a name='7'></a>__huddle false__

    Create a huddle object as a boolean false\.

  - <a name='8'></a>__huddle null__

    Create a huddle object as a null\.

  - <a name='9'></a>__huddle get__ *object* *key* ?*key \.\.\.*?

    Almost the same as __dict get__\. Get a sub\-object from the huddle
    object\. *key* can be used to huddle\-list's index\.

  - <a name='10'></a>__huddle gets__ *object* *key* ?*key \.\.\.*?

    Get a sub\-object from the huddle object, stripped\.

  - <a name='11'></a>__huddle set__ *objectVar* *key* ?*key \.\.\.*? *value*

    Almost the same as __dict set__\. Set a sub\-object from the huddle
    object\. *key* can be used to huddle\-list's index\.

  - <a name='12'></a>__huddle remove__ *object* *key* ?*key \.\.\.*?

    Almost the same as __dict remove__\. Remove a sub\-object from the huddle
    object\. *key* can be used to huddle\-list's index\.

  - <a name='13'></a>__huddle combine__ *object1* *object2* ?*object3 \.\.\.*?

    Merging huddle objects given\.

    % set aa [huddle create a b c d]
    HUDDLE {D {a {s b} c {s d}}}
    % set bb [huddle create a k l m]
    HUDDLE {D {a {s k} l {s m}}}
    % huddle combine $aa $bb
    HUDDLE {D {a {s k} c {s d} l {s m}}}

  - <a name='14'></a>__huddle equal__ *object1* *object2*

    Comparing two huddle objects recursively\. When to equal, returns 1,
    otherwise 0\.

    % set aa [huddle create a b c d]
    HUDDLE {D {a {s b} c {s d}}}
    % set bb [huddle create c d a b]
    HUDDLE {D {c {s d} a {s b}}}
    % huddle equal $aa $bb
    1

  - <a name='15'></a>__huddle append__ *objectVar* *key* *value* ?*key value \.\.\.*?

  - <a name='16'></a>__huddle append__ *objectVar* *value* ?*value \.\.\.*?

    Appending child elements\. When for dicts, giving key/value\. When for lists,
    giving values\.

    % set aa [huddle create a b c d]
    HUDDLE {D {a {s b} c {s d}}}
    % huddle append aa a k l m
    HUDDLE {D {a {s k} c {s d} l {s m}}}
    % set bb [huddle list i j k l]
    HUDDLE {L {{s i} {s j} {s k} {s l}}}
    % huddle append bb g h i
    HUDDLE {L {{s i} {s j} {s k} {s l} {s g} {s h} {s i}}}

  - <a name='17'></a>__huddle keys__ *object*

    The same as __dict keys__\.

  - <a name='18'></a>__huddle llength__ *object*

    The same as __llength__\.

  - <a name='19'></a>__huddle type__ *object* ?*key key\.\.\.*?

    Return the element type of specified by keys\. if ?key? is not given, returns
    the type of root node\.

      * ____string____

        the node is a tcl's string\.

      * ____dict____

        the node is a dict\.

      * ____list____

        the node is a list\.

      * ____number____

        the node is a number\.

      * ____boolean____

        the node is a boolean\.

      * ____null____

        the node is a null\.

    % huddle type {HUDDLE {s str}}
    string
    % huddle type {HUDDLE {L {{s a} {s b} {s c}}}}
    list
    % huddle type {HUDDLE {D {aa {s b} cc {s d}}}} cc
    string

  - <a name='20'></a>__huddle strip__ *object*

    Stripped all tags\. Converted to normal Tcl's list/dict\.

  - <a name='21'></a>__huddle jsondump__ *object* ?*offset*? ?*newline*? ?*begin\_offset*?

    dump a json\-stream from the huddle\-object\.

      * ____offset__ ""__

        begin offset as spaces " "\.

    # normal output has some indents. some strings are escaped.
    % huddle jsondump {HUDDLE {L {{L {{s i} {s baa} {s \\k} {L {{s 1.0} {s true} {s /g} {s h}}} {L {{s g}}}}} {s t}}}}
    [
      [
        "i",
        "baa",
        "\\k",
        [
          1.0,
          true,
          "\/g",
          "h"
        ],
        ["g"]
      ],
      "t"
    ]
    # stripped output
    % huddle jsondump {HUDDLE {D {dd {D {bb {D {a {s baa} c {s {d
    a}}}} cc {D {g {s h}}}}} ee {D {i {s j} k {s 1} j {s { m\a}}}}}}} "" ""
    {"dd": {"bb": {"a": "baa","c": "d\na"},"cc": {"g": "h"}},"ee": {"i": "j","k": 1,"j": " m\\a"}}

  - <a name='22'></a>__huddle compile__ *spec* *data*

    construct a huddle object from plain old tcl values\. *spec* is defined as
    follows:

      * __string__

        data is simply a string

      * __list__

        data is a tcl list of strings

      * __dict__

        data is a tcl dict of strings

      * list list

        data is a tcl list of lists

      * list dict

        data is a tcl list of dicts

      * dict xx list

        data is a tcl dict where the value of key xx is a tcl list

      * dict \* list

        data is a tcl dict of lists *data* is plain old tcl values

    % huddle compile {dict * list} {a {1 2 3} b {4 5}}
    HUDDLE {D {a {L {{s 1} {s 2} {s 3}}} b {L {{s 4} {s 5}}}}}
    % huddle compile {dict * {list {dict d list}}} {a {{c 1} {d {2 2 2} e 3}} b {{f 4 g 5}}}
    HUDDLE {D {a {L {{D {c {s 1}}} {D {d {L {{s 2} {s 2} {s 2}}} e {s 3}}}}} b {L {{D {f {s 4} g {s 5}}}}}}}

  - <a name='23'></a>__huddle isHuddle__ *object*

    if *object* is a huddle, returns 1\. the other, returns 0\.

  - <a name='24'></a>__huddle checkHuddle__ *object*

    if *object* is not a huddle, rises an error\.

  - <a name='25'></a>__huddle to\_node__ *object* ?*tag*?

    for type\-callbacks\.

    if *object* is a huddle, returns root\-node\. the other, returns __\[list s
    $object\]__\.

    % huddle to_node str
    s str
    % huddle to_node str !!str
    !!str str
    % huddle to_node {HUDDLE {s str}}
    s str
    % huddle to_node {HUDDLE {l {a b c}}}
    l {a b c}

  - <a name='26'></a>__huddle wrap__ *tag* *src*

    for type\-callbacks\.

    Create a huddle object from *src* with specified *tag*\.

    % huddle wrap "" str
    HUDDLE str
    % huddle wrap s str
    HUDDLE {s str}

  - <a name='27'></a>__huddle call__ *tag* *command* *args*

    for type\-callbacks\.

    devolving *command* to default *tag*\-callback

  - <a name='28'></a>__huddle addType__ *callback*

    add a user\-specified\-type/tag to the huddle library\. To see "Additional
    Type"\.

      * __callback__

        callback function name for additional type\.

# <a name='section3'></a>TYPE CALLBACK

The definition of callback for user\-type\.

  - <a name='29'></a>__[callback](\.\./\.\./\.\./\.\./index\.md\#callback)__ *command* ?*args*?

      * __command__

        huddle subcomand which is needed to reply by the callback\.

      * __args__

        arguments of subcommand\. The number of list of arguments is different
        for each subcommand\.

The callback procedure shuould reply the following subcommands\.

  - <a name='30'></a>__setting__

    only returns a fixed dict of the type infomation for setting the user\-tag\.

      * __type__ typename

        typename of the type

      * __method__ \{method1 method2 method3 \.\.\.\}

        method list as huddle subcommand\. Then, you can call __\[huddle method1
        \.\.\.\]__

      * __tag__ \{tag1 child/parent tag2 child/parent \.\.\.\}

        tag list for huddle\-node as a dict\. if the type has child\-nodes, use
        "parent", otherwise use "child"\.

  - <a name='31'></a>__get\_sub__ *src* *key*

    returns a sub node specified by *key*\.

      * __src__

        a node content in huddle object\.

  - <a name='32'></a>__strip__ *src*

    returns stripped node contents\. if the type has child nodes, every node must
    be stripped\.

  - <a name='33'></a>__[set](\.\./\.\./\.\./\.\./index\.md\#set)__ *src* *key* *value*

    sets a sub\-node from the tagged\-content, and returns self\.

  - <a name='34'></a>__[remove](\.\./\.\./\.\./\.\./index\.md\#remove)__ *src* *key* *value*

    removes a sub\-node from the tagged\-content, and returns self\.

__strip__ must be defined at all types\. __get\_sub__ must be defined at
container types\. __set/remove__ shuould be defined, if you call them\.

    # callback sample for my-dict
    proc my_dict_setting {command args} {
        switch -- $command {
            setting { ; # type definition
                return {
                    type dict
                    method {create keys}
                    tag {d child D parent}
                    constructor create
                    str s
                }
                # type:   the type-name
                # method: add methods to huddle's subcommand.
                #          "get_sub/strip/set/remove/equal/append" called by huddle module.
                #          "strip" must be defined at all types.
                #          "get_sub" must be defined at container types.
                #          "set/remove/equal/append" shuould be defined, if you call them.
                # tag:    tag definition("child/parent" word is maybe obsoleted)
            }
            get_sub { ; # get a sub-node specified by "key" from the tagged-content
                foreach {src key} $args break
                return [dict get $src $key]
            }
            strip { ; # strip from the tagged-content
                foreach {src nop} $args break
                foreach {key val} $src {
                    lappend result $key [huddle strip $val]
                }
                return $result
            }
            set { ; # set a sub-node from the tagged-content
                foreach {src key value} $args break
                dict set src $key $value
                return $src
            }
            remove { ; # remove a sub-node from the tagged-content
                foreach {src key value} $args break
                return [dict remove $src $key]
            }
            equal { ; # check equal for each node
                foreach {src1 src2} $args break
                if {[llength $src1] != [llength $src2]} {return 0}
                foreach {key1 val1} $src1 {
                    if {![dict exists $src2 $key1]} {return 0}
                    if {![huddle _equal_subs $val1 [dict get $src2 $key1]]} {return 0}
                }
                return 1
            }
            append { ; # append nodes
                foreach {str src list} $args break
                if {[llength $list] % 2} {error {wrong # args: should be "huddle append objvar ?key value ...?"}}
                set resultL $src
                foreach {key value} $list {
                    if {$str ne ""} {
                        lappend resultL $key [huddle to_node $value $str]
                    } else {
                        lappend resultL $key $value
                    }
                }
                return [eval dict create $resultL]
            }
            create { ; # $args: all arguments after "huddle create"
                if {[llength $args] % 2} {error {wrong # args: should be "huddle create ?key value ...?"}}
                set resultL {}
                foreach {key value} $args {
                    lappend resultL $key [huddle to_node $value]
                }
                return [huddle wrap D $resultL]
            }
            keys {
                foreach {src nop} $args break
                return [dict keys [lindex [lindex $src 1] 1]]
            }
            default {
                error "$command is not callback for dict"
            }
        }
    }

    # inheritance sample from default dict-callback
    proc ::yaml::_huddle_mapping {command args} {
        switch -- $command {
            setting { ; # type definition
                return {
                    type dict
                    method {mapping}
                    tag {!!map parent}
                    constructor mapping
                    str !!str
                }
            }
            mapping { ; # $args: all arguments after "huddle mapping"
                if {[llength $args] % 2} {error {wrong # args: should be "huddle mapping ?key value ...?"}}
                set resultL {}
                foreach {key value} $args {
                    lappend resultL $key [huddle to_node $value !!str]
                }
                return [huddle wrap !!map $resultL]
            }
            default { ; # devolving to default dict-callback
                return [huddle call D $command $args]
            }
        }
    }

# <a name='section4'></a>How to add type

You can add huddle\-node types e\.g\. ::struct::tree\. To do so, first, define a
callback\-procedure for additional tagged\-type\. The proc get argments as
*command* and ?*args*?\. It has some switch\-sections\.

And, addType subcommand will called\.

    huddle addType my_dict_setting

# <a name='section5'></a>WORKING SAMPLE

    # create as a dict
    % set bb [huddle create a b c d]
    HUDDLE {D {a {s b} c {s d}}}

    # create as a list
    % set cc [huddle list e f g h]
    HUDDLE {L {{s e} {s f} {s g} {s h}}}
    % set bbcc [huddle create bb $bb cc $cc]
    HUDDLE {D {bb {D {a {s b} c {s d}}} cc {L {{s e} {s f} {s g} {s h}}}}}
    % set folding [huddle list $bbcc p [huddle list q r] s]
    HUDDLE {L {{D {bb {D {a {s b} c {s d}}} cc {L {{s e} {s f} {s g} {s h}}}}} {s p} {L {{s q} {s r}}} {s s}}}

    # normal Tcl's notation
    % huddle strip $folding
    {bb {a b c d} cc {e f g h}} p {q r} s

    # get a sub node
    % huddle get $folding 0 bb
    HUDDLE {D {a {s b} c {s d}}}
    % huddle gets $folding 0 bb
    a b c d

    # overwrite a node
    % huddle set folding 0 bb c kkk
    HUDDLE {L {{D {bb {D {a {s b} c {s kkk}}} cc {L {{s e} {s f} {s g} {s h}}}}} {s p} {L {{s q} {s r}}} {s s}}}

    # remove a node
    % huddle remove $folding 2 1
    HUDDLE {L {{D {bb {D {a {s b} c {s kkk}}} cc {L {{s e} {s f} {s g} {s h}}}}} {s p} {L {{s q}}} {s s}}}
    % huddle strip $folding
    {bb {a b c kkk} cc {e f g h}} p {q r} s

    # dump as a JSON stream
    % huddle jsondump $folding
    [
      {
        "bb": {
          "a": "b",
          "c": "kkk"
        },
        "cc": [
          "e",
          "f",
          "g",
          "h"
        ]
      },
      "p",
      [
        "q",
        "r"
      ],
      "s"
    ]

# <a name='section6'></a>LIMITATIONS

now printing\.

# <a name='section7'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *huddle* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[yaml](yaml\.md)

# <a name='keywords'></a>KEYWORDS

[data exchange](\.\./\.\./\.\./\.\./index\.md\#data\_exchange), [exchange
format](\.\./\.\./\.\./\.\./index\.md\#exchange\_format),
[huddle](\.\./\.\./\.\./\.\./index\.md\#huddle),
[json](\.\./\.\./\.\./\.\./index\.md\#json),
[parsing](\.\./\.\./\.\./\.\./index\.md\#parsing), [text
processing](\.\./\.\./\.\./\.\./index\.md\#text\_processing),
[yaml](\.\./\.\./\.\./\.\./index\.md\#yaml)

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2008\-2011 KATO Kanryu <kanryu6@users\.sourceforge\.net>  
Copyright &copy; 2015 Miguel Martínez López <aplicacionamedida@gmail\.com>
