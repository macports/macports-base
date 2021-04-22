# # ## ### ##### ######## ############# ######################
## Validation of IBAN numbers.
#
# Reference:
#    http://en.wikipedia.org/wiki/International_Bank_Account_Number
#
# # ## ### ##### ######## ############# ######################

# The code below implements the interface of a snit validation type,
# making it directly usable with snit's -type option in option
# specifications.

# # ## ### ##### ######## ############# ######################
## Requisites

package require Tcl 8.5
package require snit
package require valtype::common

# # ## ### ##### ######## ############# ######################
## Implementation

namespace eval ::valtype::iban {
    namespace import ::valtype::common::*
}

snit::type ::valtype::iban {
    #-------------------------------------------------------------------
    # Type Methods

    typevariable cclen -array {
	AL 28 AD 24 AT 20 BH 22 BE 16 BA 20 BG 22 BR 29 CR 21 HR 21 CY 28 CZ 24 DK 18 FO 18 GL 18 DO 28 EE 20 FI 18
	FR 27 GF 27 GP 27 MQ 27 RE 27 PF 27 TF 27 YT 27 NC 27 PM 27 WF 27 GE 22 DE 22 GI 23 GR 27 HU 28 SV 28
	IS 26 IE 22 IL 23 IT 27 KZ 20 KW 30 LV 21 LB 28 LI 21 LT 20 LU 20 MK 19 MT 31 MR 27 MU 30 MC 27
	ME 22 NL 18 NO 15 PL 28 PS 29 PT 25 RO 24 SM 27 SA 24 RS 22 SK 24 SI 19 ST 25 ES 24 SE 24 CH 21 TN 24 TR 26
	AE 23 GB 22 AZ 28 MD 24 PK 24 VG 24 GT 28 QA 29 JO 30 TL 23 XK 20 UA 29 SC 31 LC 32 BY 28 IQ 23
    }

    typevariable charmap {
	A 10 B 11 C 12 D 13 E 14 F 15 G 16 H 17 I 18 J 19 K 20 L 21 M 22
	N 23 O 24 P 25 Q 26 R 27 S 28 T 29 U 30 V 31 W 32 X 33 Y 34 Z 35
    }

    typemethod cclen {cc} {
	return $cclen($cc)
    }

    typemethod validate {value} {
        set value [string toupper $value]

	if {![regexp {^[A-Z]{2}[0-9A-Z]+$} $value]} {
	    badchar IBAN "IBAN number, expected country code followed by alphanumerics"
	}

	set country [string range $value 0 1]

	if {![info exists cclen($country)]} {
	    badprefix IBAN "" "IBAN number, unknown country code"
	}
	if {[string length $value] != $cclen($country)} {
	    badlength IBAN $cclen($country) "IBAN number"
	}

	set number [string range $value 4 end][string range $value 0 3]
	set number [string map $charmap $number]
	set number [string trimleft $number 0]

	if {($number % 97) != 1} {
	    badcheck IBAN "IBAN number"
	}

	return $value
    }

    #-------------------------------------------------------------------
    # Constructor

    # None needed; no options

    #-------------------------------------------------------------------
    # Public Methods

    method validate {value} {
        $type validate $value
    }
}

# # ## ### ##### ######## ############# ######################
## Ready

package provide valtype::iban 1.7
