# -*- tcl -*-
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>

# Support package. Container for the default CSS style used by the
# html export plugins when the user does not specify its own style.

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.4 ; # Required Core

namespace eval ::doctools::html::cssdefaults {
    # Contents of the file we carry
    variable c {}
}

proc ::doctools::html::cssdefaults::contents {} {
    variable c
    return  $c
}

set ::doctools::html::cssdefaults::c {
HTML {
    background: 	#FFFFFF;
    color: 		black;
}
BODY {
    background: 	#FFFFFF;
    color:	 	black;
}
DIV.doctools {
    margin-left:	10%;
    margin-right:	10%;
}
DIV.doctools H1,DIV.doctools H2 {
    margin-left:	-5%;
}
H1, H2, H3, H4 {
    margin-top: 	1em;
    font-family:	sans-serif;
    font-size:	large;
    color:		#005A9C;
    background: 	transparent;
    text-align:		left;
}
H1.title, H1.idx-title {
    text-align: center;
}
UL,OL {
    margin-right: 0em;
    margin-top: 3pt;
    margin-bottom: 3pt;
}
UL LI {
    list-style: disc;
}
OL LI {
    list-style: decimal;
}
DT {
    padding-top: 	1ex;
}
UL.toc,UL.toc UL, UL.toc UL UL {
    font:		normal 12pt/14pt sans-serif;
    list-style:	none;
}
LI.section, LI.subsection {
    list-style: 	none;
    margin-left: 	0em;
    text-indent:	0em;
    padding: 	0em;
}
PRE {
    display: 	block;
    font-family:	monospace;
    white-space:	pre;
    margin:		0%;
    padding-top:	0.5ex;
    padding-bottom:	0.5ex;
    padding-left:	1ex;
    padding-right:	1ex;
    width:		100%;
}
PRE.example {
    color: 		black;
    background: 	#f5dcb3;
    border:		1px solid black;
}
UL.requirements LI, UL.syntax LI {
    list-style: 	none;
    margin-left: 	0em;
    text-indent:	0em;
    padding:	0em;
}
DIV.synopsis {
    color: 		black;
    background: 	#80ffff;
    border:		1px solid black;
    font-family:	serif;
    margin-top: 	1em;
    margin-bottom: 	1em;
}
UL.syntax {
    margin-top: 	1em;
    border-top:		1px solid black;
}
UL.requirements {
    margin-bottom: 	1em;
    border-bottom:	1px solid black;
}

DIV.idx-kwnav {
    width:		100%;
    margin-top:		5pt;
    margin-bottom:	5pt;
    margin-left:	0%;
    margin-right:	0%;
    padding-top:  	5pt;
    padding-bottom:	5pt;
    background:		#DDDDDD;
    color:		black;
    border: 		1px solid black;
    text-align:		center;
    font-size:		small;
    font-family:	sans-serif;
}

/* TR.even/odd are used to get alternately colored table rows. 
 * Could probably choose better colors here...
 */

TR.idx-even {
    color: 		black;
    background:		#efffef;
}

TR.idx-odd {
    color: 		black;
    background:		#efefff;
}

DIV.idx-header, DIV.idx-footer, DIV.idx-leader {
    width:		100%;
    margin-left:	0%;
    margin-right:	0%;
}

TH {
    color:		#005A9C;
    background:		#DDDDDD;
    text-align:	 	center;
    font-family:	sans-serif;
    font-weight:	bold;
}
}

package provide doctools::html::cssdefaults 0.1
return
