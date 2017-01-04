#-----------------------------------------------------------------------------
#   Copyright (C) 1999-2004 Jochen C. Loewer (loewerj@web.de)
#   Copyright (C) 2004-2011 Michael Schlenker (mic42@users.sourceforge.net)
#-----------------------------------------------------------------------------
#   
#   A partial ASN decoder/encoder implementation in plain Tcl. 
#
#   See ASN.1 (X.680) and BER (X.690).
#   See 'asn_ber_intro.txt' in this directory.
#
#   This software is copyrighted by Jochen C. Loewer (loewerj@web.de). The 
#   following terms apply to all files associated with the software unless 
#   explicitly disclaimed in individual files.
#
#   The authors hereby grant permission to use, copy, modify, distribute,
#   and license this software and its documentation for any purpose, provided
#   that existing copyright notices are retained in all copies and that this
#   notice is included verbatim in any distributions. No written agreement,
#   license, or royalty fee is required for any of the authorized uses.
#   Modifications to this software may be copyrighted by their authors
#   and need not follow the licensing terms described here, provided that
#   the new terms are clearly indicated on the first page of each file where
#   they apply.
#  
#   IN NO EVENT SHALL THE AUTHORS OR DISTRIBUTORS BE LIABLE TO ANY PARTY
#   FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
#   ARISING OUT OF THE USE OF THIS SOFTWARE, ITS DOCUMENTATION, OR ANY
#   DERIVATIVES THEREOF, EVEN IF THE AUTHORS HAVE BEEN ADVISED OF THE
#   POSSIBILITY OF SUCH DAMAGE.
#
#   THE AUTHORS AND DISTRIBUTORS SPECIFICALLY DISCLAIM ANY WARRANTIES,
#   INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY,
#   FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.  THIS SOFTWARE
#   IS PROVIDED ON AN "AS IS" BASIS, AND THE AUTHORS AND DISTRIBUTORS HAVE
#   NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
#   MODIFICATIONS.
#
#   written by Jochen Loewer
#   3 June, 1999
#
#   $Id: asn.tcl,v 1.20 2011/01/05 22:33:33 mic42 Exp $
#
#-----------------------------------------------------------------------------

# needed for using wide()
package require Tcl 8.4

namespace eval asn {
    # Encoder commands
    namespace export \
        asnSequence \
	asnSequenceFromList \
        asnSet \
	asnSetFromList \
        asnApplicationConstr \
        asnApplication \
	asnContext\
	asnContextConstr\
        asnChoice \
        asnChoiceConstr \
        asnInteger \
        asnEnumeration \
        asnBoolean \
        asnOctetString \
        asnNull	   \
	asnUTCTime \
	asnNumericString \
        asnPrintableString \
        asnIA5String\
	asnBMPString\
	asnUTF8String\
        asnBitString \
        asnObjectIdentifer 
        
    # Decoder commands
    namespace export \
        asnGetResponse \
        asnGetInteger \
        asnGetEnumeration \
        asnGetOctetString \
        asnGetSequence \
        asnGetSet \
        asnGetApplication \
	asnGetNumericString \
        asnGetPrintableString \
        asnGetIA5String \
	asnGetBMPString \
	asnGetUTF8String \
        asnGetObjectIdentifier \
        asnGetBoolean \
        asnGetUTCTime \
        asnGetBitString \
        asnGetContext 
    
    # general BER utility commands    
    namespace export \
        asnPeekByte  \
        asnGetLength \
        asnRetag     \
	asnPeekTag   \
	asnTag	     
        
}

#-----------------------------------------------------------------------------
# Implementation notes:
#
# See the 'asn_ber_intro.txt' in this directory for an introduction
# into BER/DER encoding of ASN.1 information. Bibliography information
#
#   A Layman's Guide to a Subset of ASN.1, BER, and DER
#
#   An RSA Laboratories Technical Note
#   Burton S. Kaliski Jr.
#   Revised November 1, 1993
#
#   Supersedes June 3, 1991 version, which was also published as
#   NIST/OSI Implementors' Workshop document SEC-SIG-91-17.
#   PKCS documents are available by electronic mail to
#   <pkcs@rsa.com>.
#
#   Copyright (C) 1991-1993 RSA Laboratories, a division of RSA
#   Data Security, Inc. License to copy this document is granted
#   provided that it is identified as "RSA Data Security, Inc.
#   Public-Key Cryptography Standards (PKCS)" in all material
#   mentioning or referencing this document.
#   003-903015-110-000-000
#
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# asnLength : Encode some length data. Helper command.
#-----------------------------------------------------------------------------

proc ::asn::asnLength {len} {
    
    if {$len < 0} {
        return -code error "Negative length octet requested"
    }
    if {$len < 128} {
        # short form: ISO X.690 8.1.3.4 
        return [binary format c $len]
    }
    # long form: ISO X.690 8.1.3.5
    # try to use a minimal encoding, 
    # even if not required by BER, but it is required by DER
    # take care for signed vs. unsigned issues
    if {$len < 256  } {
        return [binary format H2c 81 [expr {$len - 256}]]
    }
    if {$len < 32769} {
        # two octet signed value
        return [binary format H2S 82 $len]
    }
    if {$len < 65536} {
        return [binary format H2S 82 [expr {$len - 65536}]]
    }
    if {$len < 8388608} {
        # three octet signed value    
        return [binary format H2cS 83 [expr {$len >> 16}] [expr {($len & 0xFFFF) - 65536}]] 
    }    
    if {$len < 16777216} {
        # three octet signed value    
        return [binary format H2cS 83 [expr {($len >> 16) -256}] [expr {($len & 0xFFFF) -65536}]] 
    }
    if {$len < 2147483649} { 
        # four octet signed value
        return [binary format H2I 84 $len]
    }
    if {$len < 4294967296} {
        # four octet unsigned value
        return [binary format H2I 84 [expr {$len - 4294967296}]]
    }
    if {$len < 1099511627776} {
        # five octet unsigned value
        return [binary format H2 85][string range [binary format W $len] 3 end]  
    }
    if {$len < 281474976710656} {
        # six octet unsigned value
        return [binary format H2 86][string range [binary format W $len] 2 end]
    }
    if {$len < 72057594037927936} {
        # seven octet value
        return [binary format H2 87][string range [binary format W $len] 1 end]
    }
    
    # must be a 64-bit wide signed value
    return [binary format H2W 88 $len] 
}

#-----------------------------------------------------------------------------
# asnSequence : Assumes that the arguments are already ASN encoded.
#-----------------------------------------------------------------------------

proc ::asn::asnSequence {args} {
    asnSequenceFromList $args
}

proc ::asn::asnSequenceFromList {lst} {
    # The sequence tag is 0x30. The length is arbitrary and thus full
    # length coding is required. The arguments have to be BER encoded
    # already. Constructed value, definite-length encoding.

    set out ""
    foreach part $lst {
        append out $part
    }
    set len [string length $out]
    return [binary format H2a*a$len 30 [asnLength $len] $out]
}


#-----------------------------------------------------------------------------
# asnSet : Assumes that the arguments are already ASN encoded.
#-----------------------------------------------------------------------------

proc ::asn::asnSet {args} {
    asnSetFromList $args
}

proc ::asn::asnSetFromList {lst} {
    # The set tag is 0x31. The length is arbitrary and thus full
    # length coding is required. The arguments have to be BER encoded
    # already.

    set out ""
    foreach part $lst {
        append out $part
    }
    set len [string length $out]
    return [binary format H2a*a$len 31 [asnLength $len] $out]
}


#-----------------------------------------------------------------------------
# asnApplicationConstr
#-----------------------------------------------------------------------------

proc ::asn::asnApplicationConstr {appNumber args} {
    # Packs the arguments into a constructed value with application tag.

    set out ""
    foreach part $args {
        append out $part
    }
    set code [expr {0x060 + $appNumber}]
    set len  [string length $out]
    return [binary format ca*a$len $code [asnLength $len] $out]
}

#-----------------------------------------------------------------------------
# asnApplication
#-----------------------------------------------------------------------------

proc ::asn::asnApplication {appNumber data} {
    # Packs the arguments into a constructed value with application tag.

    set code [expr {0x040 + $appNumber}]
    set len  [string length $data]
    return [binary format ca*a$len $code [asnLength $len] $data]
}

#-----------------------------------------------------------------------------
# asnContextConstr
#-----------------------------------------------------------------------------

proc ::asn::asnContextConstr {contextNumber args} {
    # Packs the arguments into a constructed value with application tag.

    set out ""
    foreach part $args {
        append out $part
    }
    set code [expr {0x0A0 + $contextNumber}]
    set len  [string length $out]
    return [binary format ca*a$len $code [asnLength $len] $out]
}

#-----------------------------------------------------------------------------
# asnContext
#-----------------------------------------------------------------------------

proc ::asn::asnContext {contextNumber data} {
    # Packs the arguments into a constructed value with application tag.
    set code [expr {0x080 + $contextNumber}]
    set len  [string length $data]
    return [binary format ca*a$len $code [asnLength $len] $data]
}
#-----------------------------------------------------------------------------
# asnChoice
#-----------------------------------------------------------------------------

proc ::asn::asnChoice {appNumber args} {
    # Packs the arguments into a choice construction.

    set out ""
    foreach part $args {
        append out $part
    }
    set code [expr {0x080 + $appNumber}]
    set len  [string length $out]
    return [binary format ca*a$len $code [asnLength $len] $out]
}

#-----------------------------------------------------------------------------
# asnChoiceConstr
#-----------------------------------------------------------------------------

proc ::asn::asnChoiceConstr {appNumber args} {
    # Packs the arguments into a choice construction.

    set out ""
    foreach part $args {
        append out $part
    }
    set code [expr {0x0A0 + $appNumber}]
    set len  [string length $out]
    return [binary format ca*a$len $code [asnLength $len] $out]
}

#-----------------------------------------------------------------------------
# asnInteger : Encode integer value.
#-----------------------------------------------------------------------------

proc ::asn::asnInteger {number} {
    asnIntegerOrEnum 02 $number
}

#-----------------------------------------------------------------------------
# asnEnumeration : Encode enumeration value.
#-----------------------------------------------------------------------------

proc ::asn::asnEnumeration {number} {
    asnIntegerOrEnum 0a $number
}

#-----------------------------------------------------------------------------
# asnIntegerOrEnum : Common code for Integers and Enumerations
#                    No Bignum version, as we do not expect large Enums.
#-----------------------------------------------------------------------------

proc ::asn::asnIntegerOrEnum {tag number} {
    # The integer tag is 0x02 , the Enum Tag 0x0a otherwise identical. 
    # The length is 1, 2, 3, or 4, coded in a
    # single byte. This can be done directly, no need to go through
    # asnLength. The value itself is written in big-endian.

    # Known bug/issue: The command cannot handle very wide integers, i.e.
    # anything above 8 bytes length. Use asnBignumInteger for those.
    
    # check if we really have an int
    set num $number
    incr num
    
    if {($number >= -128) && ($number < 128)} {
        return [binary format H2H2c $tag 01 $number]
    }
    if {($number >= -32768) && ($number < 32768)} {
        return [binary format H2H2S $tag 02 $number]
    }
    if {($number >= -8388608) && ($number < 8388608)} {
        set numberb [expr {$number & 0xFFFF}]
        set numbera [expr {($number >> 16) & 0xFF}]
        return [binary format H2H2cS $tag 03 $numbera $numberb]
    }
    if {($number >= -2147483648) && ($number < 2147483648)} {
        return [binary format H2H2I $tag 04 $number]
    }
    if {($number >= -549755813888) && ($number < 549755813888)} {
        set numberb [expr {$number & 0xFFFFFFFF}]
        set numbera [expr {($number >> 32) & 0xFF}]
        return [binary format H2H2cI $tag 05 $numbera $numberb]
    }
    if {($number >= -140737488355328) && ($number < 140737488355328)} {
        set numberb [expr {$number & 0xFFFFFFFF}]
        set numbera [expr {($number >> 32) & 0xFFFF}]
        return [binary format H2H2SI $tag 06 $numbera $numberb]        
    }
    if {($number >= -36028797018963968) && ($number < 36028797018963968)} {
        set numberc [expr {$number & 0xFFFFFFFF}]
        set numberb [expr {($number >> 32) & 0xFFFF}]
        set numbera [expr {($number >> 48) & 0xFF}]
        return [binary format H2H2cSI $tag 07 $numbera $numberb $numberc]        
    }    
    if {($number >= -9223372036854775808) && ($number <= 9223372036854775807)} {
        return [binary format H2H2W $tag 08 $number]
    }
    return -code error "Integer value to large to encode, use asnBigInteger" 
}

#-----------------------------------------------------------------------------
# asnBigInteger : Encode a long integer value using math::bignum
#-----------------------------------------------------------------------------

proc ::asn::asnBigInteger {bignum} {
    # require math::bignum only if it is used
    package require math::bignum
    
    # this is a hack to check for bignum...
    if {[llength $bignum] < 2 || ([lindex $bignum 0] ne "bignum")} {
        return -code error "expected math::bignum value got \"$bignum\""
    }
    if {[math::bignum::sign $bignum]} {
        # generate two's complement form
        set bits [math::bignum::bits $bignum]
        set padding [expr {$bits % 8}]
        set len [expr {int(ceil($bits / 8.0))}]
        if {$padding == 0} {
            # we need a complete extra byte for the sign
            # unless this is a base 2 multiple
            set test [math::bignum::fromstr 0]
            math::bignum::setbit test [expr {$bits-1}]
            if {[math::bignum::ne [math::bignum::abs $bignum] $test]} {
                incr len
            }
        }
        set exp [math::bignum::pow \
		    [math::bignum::fromstr 256] \
		    [math::bignum::fromstr $len]]
        set bignum [math::bignum::add $bignum $exp]
        set hex [math::bignum::tostr $bignum 16]
    } else {
        set bits [math::bignum::bits $bignum]
        if {($bits % 8) == 0 && $bits > 0} {
            set pad "00"
        } else {
            set pad ""
        }
        set hex $pad[math::bignum::tostr $bignum 16]
    }
    if {[string length $hex]%2} {
        set hex "0$hex"
    }
    set octets [expr {(([string length $hex]+1)/2)}]
    return [binary format H2a*H* 02 [asnLength $octets] $hex]   
}


#-----------------------------------------------------------------------------
# asnBoolean : Encode a boolean value.
#-----------------------------------------------------------------------------

proc ::asn::asnBoolean {bool} {
    # The boolean tag is 0x01. The length is always 1, coded in
    # a single byte. This can be done directly, no need to go through
    # asnLength. The value itself is written in big-endian.

    return [binary format H2H2c 01 01 [expr {$bool ? 0x0FF : 0x0}]]
}

#-----------------------------------------------------------------------------
# asnOctetString : Encode a string of arbitrary bytes
#-----------------------------------------------------------------------------

proc ::asn::asnOctetString {string} {
    # The octet tag is 0x04. The length is arbitrary, so we need
    # 'asnLength' for full coding of the length.

    set len [string length $string]
    return [binary format H2a*a$len 04 [asnLength $len] $string]
}

#-----------------------------------------------------------------------------
# asnNull : Encode a null value
#-----------------------------------------------------------------------------

proc ::asn::asnNull {} {
    # Null has only one valid encoding
    return \x05\x00
}

#-----------------------------------------------------------------------------
# asnBitstring : Encode a Bit String value
#-----------------------------------------------------------------------------

proc ::asn::asnBitString {bitstring} {
    # The bit string tag is 0x03.
    # Bit strings can be either simple or constructed
    # we always use simple encoding
    
    set bitlen [string length $bitstring]
    set padding [expr {(8 - ($bitlen % 8)) % 8}]
    set len [expr {($bitlen / 8) + 1}]
    if {$padding != 0} { incr len }

    return [binary format H2a*cB* 03 [asnLength $len] $padding $bitstring]    
}

#-----------------------------------------------------------------------------
# asnUTCTime : Encode an UTC time string
#-----------------------------------------------------------------------------

proc ::asn::asnUTCTime {UTCtimestring} {
    # the utc time tag is 0x17.
    # 
    # BUG: we do not check the string for well formedness
    
    set ascii [encoding convertto ascii $UTCtimestring]
    set len [string length $ascii]
    return [binary format H2a*a* 17 [asnLength $len] $ascii]
}

#-----------------------------------------------------------------------------
# asnPrintableString : Encode a printable string
#-----------------------------------------------------------------------------
namespace eval asn {
    variable nonPrintableChars {[^ A-Za-z0-9'()+,.:/?=-]}
}	
proc ::asn::asnPrintableString {string} {
    # the printable string tag is 0x13
    variable nonPrintableChars
    # it is basically a restricted ascii string
    if {[regexp $nonPrintableChars $string ]} {
        return -code error "Illegal character in PrintableString."
    }
    
    # check characters
    set ascii [encoding convertto ascii $string]
    return [asnEncodeString 13 $ascii]
}

#-----------------------------------------------------------------------------
# asnIA5String : Encode an Ascii String
#-----------------------------------------------------------------------------
proc ::asn::asnIA5String {string} {
    # the IA5 string tag is 0x16
    # check for extended charachers
    if {[string length $string]!=[string bytelength $string]} {
	return -code error "Illegal character in IA5String"
    }
    set ascii [encoding convertto ascii $string]
    return [asnEncodeString 16 $ascii]
}

#-----------------------------------------------------------------------------
# asnNumericString : Encode a Numeric String type
#-----------------------------------------------------------------------------
namespace eval asn {
    variable nonNumericChars {[^0-9 ]}
}
proc ::asn::asnNumericString {string} {
    # the Numeric String type has tag 0x12
    variable nonNumericChars
    if {[regexp $nonNumericChars $string]} {
        return -code error "Illegal character in Numeric String."
    }
    
    return [asnEncodeString 12 $string]
}
#----------------------------------------------------------------------
# asnBMPString: Encode a Tcl string as Basic Multinligval (UCS2) string
#-----------------------------------------------------------------------
proc asn::asnBMPString  {string} {
    if {$::tcl_platform(byteOrder) eq "littleEndian"} {
	set bytes ""
	foreach {lo hi} [split [encoding convertto unicode $string] ""] {
	    append bytes $hi $lo
	}	
    } else {
	set bytes [encoding convertto unicode $string]
    }
    return [asnEncodeString 1e $bytes]
}	
#---------------------------------------------------------------------------
# asnUTF8String: encode tcl string as UTF8 String
#----------------------------------------------------------------------------
proc asn::asnUTF8String {string} {
    return [asnEncodeString 0c [encoding convertto utf-8 $string]]
}
#-----------------------------------------------------------------------------
# asnEncodeString : Encode an RestrictedCharacter String
#-----------------------------------------------------------------------------
proc ::asn::asnEncodeString {tag string} {
    set len [string length $string]
    return [binary format H2a*a$len $tag [asnLength $len] $string]    
}

#-----------------------------------------------------------------------------
# asnObjectIdentifier : Encode an Object Identifier value
#-----------------------------------------------------------------------------
proc ::asn::asnObjectIdentifier {oid} {
    # the object identifier tag is 0x06
    
    if {[llength $oid] < 2} {
        return -code error "OID must have at least two subidentifiers."
    }
    
    # basic check that it is valid
    foreach identifier $oid {
        if {$identifier < 0} {
            return -code error \
		"Malformed OID. Identifiers must be positive Integers."
        }
    }
    
    if {[lindex $oid 0] > 2} {
            return -code error "First subidentifier must be 0,1 or 2"
    }
    if {[lindex $oid 1] > 39} {
            return -code error \
		"Second subidentifier must be between 0 and 39"
    }
    
    # handle the special cases directly
    switch [llength $oid] {
        2  {  return [binary format H2H2c 06 01 \
		[expr {[lindex $oid 0]*40+[lindex $oid 1]}]] }
        default {
              # This can probably be written much shorter. 
              # Just a first try that works...
              #
              set octets [binary format c \
		[expr {[lindex $oid 0]*40+[lindex $oid 1]}]]
              foreach identifier [lrange $oid 2 end] {
                  set d 128
                  if {$identifier < 128} {
                    set subidentifier [list $identifier]
                  } else {  
                    set subidentifier [list]
                    # find the largest divisor
                    
                    while {($identifier / $d) >= 128} { 
			set d [expr {$d * 128}] 
		    }
                    # and construct the subidentifiers
                    set remainder $identifier
                    while {$d >= 128} {
                        set coefficient [expr {($remainder / $d) | 0x80}]
                        set remainder [expr {$remainder % $d}]
                        set d [expr {$d / 128}]
                        lappend subidentifier $coefficient
                    }
                    lappend subidentifier $remainder
                  }
                  append octets [binary format c* $subidentifier]
              }
              return [binary format H2a*a* 06 \
		      [asnLength [string length $octets]] $octets]
        }
    }

}

#-----------------------------------------------------------------------------
# asnGetResponse : Read a ASN response from a channel.
#-----------------------------------------------------------------------------

proc ::asn::asnGetResponse {sock data_var} {
    upvar 1 $data_var data

    # We expect a sequence here (tag 0x30). The code below is an
    # inlined replica of 'asnGetSequence', modified for reading from a
    # channel instead of a string.

    set tag [read $sock 1]

    if {$tag == "\x30"} {
    # The following code is a replica of 'asnGetLength', modified
    # for reading the bytes from the channel instead of a string.

        set len1 [read $sock 1]
        binary scan $len1 c num
        set length [expr {($num + 0x100) % 0x100}]

        if {$length  >= 0x080} {
        # The byte the read is not the length, but a prefix, and
        # the lower nibble tells us how many bytes follow.

            set len_length  [expr {$length & 0x7f}]

        # BUG: We should not perform the value extraction for an
        # BUG: improper length. It wastes cycles, and here it can
        # BUG: cause us trouble, reading more data than there is
        # BUG: on the channel. Depending on the channel
        # BUG: configuration an attacker can induce us to block,
        # BUG: causing a denial of service.
            set lengthBytes [read $sock $len_length]

            switch $len_length {
                1 {
            binary scan $lengthBytes     c length 
            set length [expr {($length + 0x100) % 0x100}]
                }
                2 { binary scan $lengthBytes     S length }
                3 { binary scan \x00$lengthBytes I length }
                4 { binary scan $lengthBytes     I length }
                default {
                    return -code error \
			"length information too long ($len_length)"
                }
            }
        }

    # Now that the length is known we get the remainder,
    # i.e. payload, and construct proper in-memory BER encoded
    # sequence.

        set rest [read $sock $length]
        set data [binary format aa*a$length $tag [asnLength $length] $rest]
    }  else {
    # Generate an error message if the data is not a sequence as
    # we expected.

        set tag_hex ""
        binary scan $tag H2 tag_hex
        return -code error "unknown start tag [string length $tag] $tag_hex"
    }
}

if {[package vsatisfies [package present Tcl] 8.5.0]} {
##############################################################################
# Code for 8.5
##############################################################################
#-----------------------------------------------------------------------------
# asnGetByte (8.5 version) : Retrieve a single byte from the data (unsigned)
#-----------------------------------------------------------------------------

proc ::asn::asnGetByte {data_var byte_var} {
    upvar 1 $data_var data $byte_var byte
    
    binary scan [string index $data 0] cu byte
    set data [string range $data 1 end]

    return
}

#-----------------------------------------------------------------------------
# asnPeekByte (8.5 version) : Retrieve a single byte from the data (unsigned) 
#               without removing it.
#-----------------------------------------------------------------------------

proc ::asn::asnPeekByte {data_var byte_var {offset 0}} {
    upvar 1 $data_var data $byte_var byte
    
    binary scan [string index $data $offset] cu byte

    return
}

#-----------------------------------------------------------------------------
# asnGetLength (8.5 version) : Decode an ASN length value (See notes)
#-----------------------------------------------------------------------------

proc ::asn::asnGetLength {data_var length_var} {
    upvar 1 $data_var data  $length_var length

    asnGetByte data length
    if {$length == 0x080} {
        return -code error "Indefinite length BER encoding not yet supported"
    }
    if {$length > 0x080} {
    # The retrieved byte is a prefix value, and the integer in the
    # lower nibble tells us how many bytes were used to encode the
    # length data following immediately after this prefix.

        set len_length [expr {$length & 0x7f}]
        
        if {[string length $data] < $len_length} {
            return -code error \
		"length information invalid, not enough octets left" 
        }
        
        asnGetBytes data $len_length lengthBytes

        switch $len_length {
            1 { binary scan $lengthBytes     cu length }
            2 { binary scan $lengthBytes     Su length }
            3 { binary scan \x00$lengthBytes Iu length }
            4 { binary scan $lengthBytes     Iu length }
            default {                
                binary scan $lengthBytes H* hexstr
		scan $hexstr %llx length
            }
        }
    }
    return
}

} else {
##############################################################################
# Code for Tcl 8.4
##############################################################################
#-----------------------------------------------------------------------------
# asnGetByte : Retrieve a single byte from the data (unsigned)
#-----------------------------------------------------------------------------

proc ::asn::asnGetByte {data_var byte_var} {
    upvar 1 $data_var data $byte_var byte
    
    binary scan [string index $data 0] c byte
    set byte [expr {($byte + 0x100) % 0x100}]  
    set data [string range $data 1 end]

    return
}

#-----------------------------------------------------------------------------
# asnPeekByte : Retrieve a single byte from the data (unsigned) 
#               without removing it.
#-----------------------------------------------------------------------------

proc ::asn::asnPeekByte {data_var byte_var {offset 0}} {
    upvar 1 $data_var data $byte_var byte
    
    binary scan [string index $data $offset] c byte
    set byte [expr {($byte + 0x100) % 0x100}]  

    return
}

#-----------------------------------------------------------------------------
# asnGetLength : Decode an ASN length value (See notes)
#-----------------------------------------------------------------------------

proc ::asn::asnGetLength {data_var length_var} {
    upvar 1 $data_var data  $length_var length

    asnGetByte data length
    if {$length == 0x080} {
        return -code error "Indefinite length BER encoding not yet supported"
    }
    if {$length > 0x080} {
    # The retrieved byte is a prefix value, and the integer in the
    # lower nibble tells us how many bytes were used to encode the
    # length data following immediately after this prefix.

        set len_length [expr {$length & 0x7f}]
        
        if {[string length $data] < $len_length} {
            return -code error \
		"length information invalid, not enough octets left" 
        }
        
        asnGetBytes data $len_length lengthBytes

        switch $len_length {
            1 {
        # Efficiently coded data will not go through this
        # path, as small length values can be coded directly,
        # without a prefix.

            binary scan $lengthBytes     c length 
            set length [expr {($length + 0x100) % 0x100}]
            }
            2 { binary scan $lengthBytes     S length 
            set length [expr {($length + 0x10000) % 0x10000}]
            }
            3 { binary scan \x00$lengthBytes I length 
            set length [expr {($length + 0x1000000) % 0x1000000}]
            }
            4 { binary scan $lengthBytes     I length 
            set length [expr {(wide($length) + 0x100000000) % 0x100000000}]
            }
            default {                
                binary scan $lengthBytes H* hexstr
                # skip leading zeros which are allowed by BER
                set hexlen [string trimleft $hexstr 0] 
                # check if it fits into a 64-bit signed integer
                if {[string length $hexlen] > 16} {
                    return -code error -errorcode {ARITH IOVERFLOW 
                            {Length value too large for normal use, try asnGetBigLength}} \
			    "Length value to large"
                } elseif {  [string length $hexlen] == 16 \
			&& ([string index $hexlen 0] & 0x8)} { 
                    # check most significant bit, if set we need bignum
                    return -code error -errorcode {ARITH IOVERFLOW 
                            {Length value too large for normal use, try asnGetBigLength}} \
			    "Length value to large"
                } else {
                    scan $hexstr "%lx" length
                }
            }
        }
    }
    return
}

} 

#-----------------------------------------------------------------------------
# asnRetag: Remove an explicit tag with the real newTag
#
#-----------------------------------------------------------------------------
proc ::asn::asnRetag {data_var newTag} {
    upvar 1 $data_var data 
    set tag ""
    set type ""
    set len [asnPeekTag data tag type dummy]	
    asnGetBytes data $len tagbytes
    set data [binary format c* $newTag]$data
}

#-----------------------------------------------------------------------------
# asnGetBytes : Retrieve a block of 'length' bytes from the data.
#-----------------------------------------------------------------------------

proc ::asn::asnGetBytes {data_var length bytes_var} {
    upvar 1 $data_var data  $bytes_var bytes

    incr length -1
    set bytes [string range $data 0 $length]
    incr length
    set data [string range $data $length end]

    return
}

#-----------------------------------------------------------------------------
# asnPeekTag : Decode the tag value
#-----------------------------------------------------------------------------

proc ::asn::asnPeekTag {data_var tag_var tagtype_var constr_var} {
    upvar 1 $data_var data $tag_var tag $tagtype_var tagtype $constr_var constr
    
    set type 0	
    set offset 0
    asnPeekByte data type $offset
    # check if we have a simple tag, < 31, which fits in one byte
     
    set tval [expr {$type & 0x1f}]
    if {$tval == 0x1f} {
	# long tag, max 64-bit with Tcl 8.4, unlimited with 8.5 bignum
	asnPeekByte data tagbyte [incr offset]
	set tval [expr {wide($tagbyte & 0x7f)}]
	while {($tagbyte & 0x80)} {
	    asnPeekByte data tagbyte [incr offset] 
	    set tval [expr {($tval << 7) + ($tagbyte & 0x7f)}]
	}
    } 

    set tagtype [lindex {UNIVERSAL APPLICATION CONTEXT PRIVATE} \
	[expr {($type & 0xc0) >>6}]]
    set tag $tval
    set constr [expr {($type & 0x20) > 0}]

    return [incr offset]	
}

#-----------------------------------------------------------------------------
# asnTag : Build a tag value
#-----------------------------------------------------------------------------

proc ::asn::asnTag {tagnumber {class UNIVERSAL} {tagstyle P}} {
    set first 0
    if {$tagnumber < 31} {
	# encode everything in one byte
	set first $tagnumber	
	set bytes [list]
    } else {
	# multi-byte tag
	set first 31
	set bytes [list [expr {$tagnumber & 0x7f}]]
	set tagnumber [expr {$tagnumber >> 7}]
	while {$tagnumber > 0} {
	    lappend bytes [expr {($tagnumber & 0x7f)+0x80}]
	    set tagnumber [expr {$tagnumber >>7}]	
	}

    }
    
    if {$tagstyle eq "C" || $tagstyle == 1 } {incr first 32}
    switch -glob -- $class {
	U* {		    ;# UNIVERSAL } 
	A* { incr first 64  ;# APPLICATION }
	C* { incr first 128 ;# CONTEXT }
	P* { incr first 192 ;# PRIVATE }
	default {
	    return -code error "Unknown tag class \"$class\""
	}	
    }
    if {[llength $bytes] > 0} {
	# long tag
	set rbytes [list]
	for {set i [expr {[llength $bytes]-1}]} {$i >= 0} {incr i -1} {
	    lappend rbytes [lindex $bytes $i]
	}
	return [binary format cc* $first $rbytes ]
    } 
    return [binary format c $first]
}



#-----------------------------------------------------------------------------
# asnGetBigLength : Retrieve a length that can not be represented in 63-bit
#-----------------------------------------------------------------------------

proc ::asn::asnGetBigLength {data_var biglength_var} {

    # Does any real world code really need this? 
    # If we encounter this, we are doomed to fail anyway, 
    # (there would be an Exabyte inside the data_var, )
    #
    # So i implement it just for completeness.
    # 
    package require math::bignum
    
    upvar 1 $data_var data  $biglength_var length

    asnGetByte data length
    if {$length == 0x080} {
        return -code error "Indefinite length BER encoding not yet supported"
    }
    if {$length > 0x080} {
    # The retrieved byte is a prefix value, and the integer in the
    # lower nibble tells us how many bytes were used to encode the
    # length data following immediately after this prefix.

        set len_length [expr {$length & 0x7f}]
        
        if {[string length $data] < $len_length} {
            return -code error \
		"length information invalid, not enough octets left" 
        }
        
        asnGetBytes data $len_length lengthBytes
        binary scan $lengthBytes H* hexlen
        set length [math::bignum::fromstr $hexlen 16]
    }
    return
}

#-----------------------------------------------------------------------------
# asnGetInteger : Retrieve integer.
#-----------------------------------------------------------------------------

proc ::asn::asnGetInteger {data_var int_var} {
    # Tag is 0x02. 

    upvar 1 $data_var data $int_var int

    asnGetByte   data tag

    if {$tag != 0x02} {
        return -code error \
            [format "Expected Integer (0x02), but got %02x" $tag]
    }

    asnGetLength data len
    asnGetBytes  data $len integerBytes

    set int ?

    switch $len {
        1 { binary scan $integerBytes     c int }
        2 { binary scan $integerBytes     S int }
        3 { 
            # check for negative int and pad 
            scan [string index $integerBytes 0] %c byte
            if {$byte & 128} {
                binary scan \xff$integerBytes I int
            } else {
                binary scan \x00$integerBytes I int 
            }
          }
        4 { binary scan $integerBytes     I int }
        5 -
        6 -
        7 -
        8 {
            # check for negative int and pad
            scan [string index $integerBytes 0] %c byte
            if {$byte & 128} {
                set pad [string repeat \xff [expr {8-$len}]]
            } else {
                set pad [string repeat \x00 [expr {8-$len}]]
            }
            binary scan $pad$integerBytes W int 
        }
        default {
        # Too long, or prefix coding was used.
            return -code error "length information too long"
        }
    }
    return
}

#-----------------------------------------------------------------------------
# asnGetBigInteger : Retrieve a big integer.
#-----------------------------------------------------------------------------

proc ::asn::asnGetBigInteger {data_var bignum_var} {
	# require math::bignum only if it is used
	package require math::bignum

	# Tag is 0x02. We expect that the length of the integer is coded with
	# maximal efficiency, i.e. without a prefix 0x81 prefix. If a prefix
	# is used this decoder will fail.

	upvar $data_var data $bignum_var bignum

	asnGetByte   data tag

	if {$tag != 0x02} {
		return -code error \
			[format "Expected Integer (0x02), but got %02x" $tag]
	}

	asnGetLength data len
	asnGetBytes  data $len integerBytes

	binary scan [string index $integerBytes 0] H* hex_head
	set head [expr 0x$hex_head]
	set replacement_head [expr {$head & 0x7f}]
	set integerBytes [string replace $integerBytes 0 0 [format %c $replacement_head]]

	binary scan $integerBytes H* hex

	set bignum [math::bignum::fromstr $hex 16]

	if {($head >> 7) && 1} {
		set bigsub [math::bignum::pow [::math::bignum::fromstr 2] [::math::bignum::fromstr [expr {($len * 8) - 1}]]]
		set bignum [math::bignum::sub $bignum $bigsub]
	}

	return $bignum
}




#-----------------------------------------------------------------------------
# asnGetEnumeration : Retrieve an enumeration id
#-----------------------------------------------------------------------------

proc ::asn::asnGetEnumeration {data_var enum_var} {
    # This is like 'asnGetInteger', except for a different tag.

    upvar 1 $data_var data $enum_var enum

    asnGetByte   data tag

    if {$tag != 0x0a} {
        return -code error \
            [format "Expected Enumeration (0x0a), but got %02x" $tag]
    }

    asnGetLength data len
    asnGetBytes  data $len integerBytes
    set enum ?

    switch $len {
        1 { binary scan $integerBytes     c enum }
        2 { binary scan $integerBytes     S enum }
        3 { binary scan \x00$integerBytes I enum }
        4 { binary scan $integerBytes     I enum }
        default {
            return -code error "length information too long"
        }
    }
    return
}

#-----------------------------------------------------------------------------
# asnGetOctetString : Retrieve arbitrary string.
#-----------------------------------------------------------------------------

proc ::asn::asnGetOctetString {data_var string_var} {
    # Here we need the full decoder for length data.

    upvar 1 $data_var data $string_var string
    
    asnGetByte data tag
    if {$tag != 0x04} { 
        return -code error \
            [format "Expected Octet String (0x04), but got %02x" $tag]
    }
    asnGetLength data length
    asnGetBytes  data $length temp
    set string $temp
    return
}

#-----------------------------------------------------------------------------
# asnGetSequence : Retrieve Sequence data for further decoding.
#-----------------------------------------------------------------------------

proc ::asn::asnGetSequence {data_var sequence_var} {
    # Here we need the full decoder for length data.

    upvar 1 $data_var data $sequence_var sequence

    asnGetByte data tag
    if {$tag != 0x030} { 
        return -code error \
            [format "Expected Sequence (0x30), but got %02x" $tag]
    }    
    asnGetLength data length
    asnGetBytes  data $length temp
    set sequence $temp
    return
}

#-----------------------------------------------------------------------------
# asnGetSet : Retrieve Set data for further decoding.
#-----------------------------------------------------------------------------

proc ::asn::asnGetSet {data_var set_var} {
    # Here we need the full decoder for length data.

    upvar 1 $data_var data $set_var set

    asnGetByte data tag
    if {$tag != 0x031} { 
        return -code error \
            [format "Expected Set (0x31), but got %02x" $tag]
    }    
    asnGetLength data length
    asnGetBytes  data $length temp
    set set $temp
    return
}

#-----------------------------------------------------------------------------
# asnGetApplication
#-----------------------------------------------------------------------------

proc ::asn::asnGetApplication {data_var appNumber_var {content_var {}} {encodingType_var {}} } {
    upvar 1 $data_var data $appNumber_var appNumber

    asnGetByte   data tag
    asnGetLength data length

    if {($tag & 0xC0) != 0x40} {
        return -code error \
            [format "Expected Application, but got %02x" $tag]
    }    
    if {$encodingType_var != {}} {
	upvar 1 $encodingType_var encodingType
	set encodingType [expr {($tag & 0x20) > 0}]
    }
    set appNumber [expr {$tag & 0x1F}]
	if {[string length $content_var]} {
		upvar 1 $content_var content
		asnGetBytes data $length content
	}	
    return
}

#-----------------------------------------------------------------------------
# asnGetBoolean: decode a boolean value
#-----------------------------------------------------------------------------

proc asn::asnGetBoolean {data_var bool_var} {
    upvar 1 $data_var data $bool_var bool

    asnGetByte data tag
    if {$tag != 0x01} {
        return -code error \
            [format "Expected Boolean (0x01), but got %02x" $tag]
    }

    asnGetLength data length
    asnGetByte data byte
    set bool [expr {$byte == 0 ? 0 : 1}]    
    return
}

#-----------------------------------------------------------------------------
# asnGetUTCTime: Extract an UTC Time string from the data. Returns a string
#                representing an UTC Time.
#
#-----------------------------------------------------------------------------

proc asn::asnGetUTCTime {data_var utc_var} {
    upvar 1 $data_var data $utc_var utc

    asnGetByte data tag
    if {$tag != 0x17} {
        return -code error \
            [format "Expected UTCTime (0x17), but got %02x" $tag]
    }

    asnGetLength data length
    asnGetBytes data $length bytes
    
    # this should be ascii, make it explicit
    set bytes [encoding convertfrom ascii $bytes]
    binary scan $bytes a* utc
    
    return
}


#-----------------------------------------------------------------------------
# asnGetBitString: Extract a Bit String value (a string of 0/1s) from the
#                  ASN.1 data.
#
#-----------------------------------------------------------------------------

proc asn::asnGetBitString {data_var bitstring_var} {
    upvar 1 $data_var data $bitstring_var bitstring

    asnGetByte data tag
    if {$tag != 0x03} {
        return -code error \
            [format "Expected Bit String (0x03), but got %02x" $tag]
    }
    
    asnGetLength data length
    # get the number of padding bits used at the end
    asnGetByte data padding
    incr length -1
    asnGetBytes data $length bytes
    binary scan $bytes B* bits
    
    # cut off the padding bits
    set bits [string range $bits 0 end-$padding]
    set bitstring $bits
}

#-----------------------------------------------------------------------------
# asnGetObjectIdentifier: Decode an ASN.1 Object Identifier (OID) into
#                         a Tcl list of integers.
#-----------------------------------------------------------------------------

proc asn::asnGetObjectIdentifier {data_var oid_var} {
      upvar 1 $data_var data $oid_var oid

      asnGetByte data tag
      if {$tag != 0x06} {
        return -code error \
            [format "Expected Object Identifier (0x06), but got %02x" $tag]  
      }
      asnGetLength data length
      
      # the first byte encodes the OID parts in position 0 and 1
      asnGetByte data val
      set oid [expr {$val / 40}]
      lappend oid [expr {$val % 40}]
      incr length -1
      
      # the next bytes encode the remaining parts of the OID
      set bytes [list]
      set incomplete 0
      while {$length} {
        asnGetByte data octet
        incr length -1
        if {$octet < 128} {
            set oidval $octet
            set mult 128
            foreach byte $bytes {
                if {$byte != {}} {
                incr oidval [expr {$mult*$byte}]    
                set mult [expr {$mult*128}]
                }
            }
            lappend oid $oidval
            set bytes [list]
            set incomplete 0
        } else {
            set byte [expr {$octet-128}]
            set bytes [concat [list $byte] $bytes]
            set incomplete 1
        }                      
      }
      if {$incomplete} {
        return -code error "OID Data is incomplete, not enough octets."
      }
      return
}

#-----------------------------------------------------------------------------
# asnGetContext: Decode an explicit context tag 
#
#-----------------------------------------------------------------------------

proc ::asn::asnGetContext {data_var contextNumber_var {content_var {}} {encodingType_var {}}} {
    upvar 1 $data_var data $contextNumber_var contextNumber 
    
    asnGetByte   data tag
    asnGetLength data length

    if {($tag & 0xC0) != 0x80} {
        return -code error \
            [format "Expected Context, but got %02x" $tag]
    }    
    if {$encodingType_var != {}} { 
	upvar 1 $encodingType_var encodingType 
	set encodingType [expr {($tag & 0x20) > 0}]
    }
    set contextNumber [expr {$tag & 0x1F}]
	if {[string length $content_var]} {
		upvar 1 $content_var content
		asnGetBytes data $length content
	}	
    return
}


#-----------------------------------------------------------------------------
# asnGetNumericString: Decode a Numeric String from the data
#-----------------------------------------------------------------------------

proc ::asn::asnGetNumericString {data_var print_var} {
    upvar 1 $data_var data $print_var print

    asnGetByte data tag
    if {$tag != 0x12} {
        return -code error \
            [format "Expected Numeric String (0x12), but got %02x" $tag]  
    }
    asnGetLength data length 
    asnGetBytes data $length string
    set print [encoding convertfrom ascii $string]
    return
}

#-----------------------------------------------------------------------------
# asnGetPrintableString: Decode a Printable String from the data
#-----------------------------------------------------------------------------

proc ::asn::asnGetPrintableString {data_var print_var} {
    upvar 1 $data_var data $print_var print

    asnGetByte data tag
    if {$tag != 0x13} {
        return -code error \
            [format "Expected Printable String (0x13), but got %02x" $tag]  
    }
    asnGetLength data length 
    asnGetBytes data $length string
    set print [encoding convertfrom ascii $string]
    return
}

#-----------------------------------------------------------------------------
# asnGetIA5String: Decode a IA5(ASCII) String from the data
#-----------------------------------------------------------------------------

proc ::asn::asnGetIA5String {data_var print_var} {
    upvar 1 $data_var data $print_var print

    asnGetByte data tag
    if {$tag != 0x16} {
        return -code error \
            [format "Expected IA5 String (0x16), but got %02x" $tag]  
    }
    asnGetLength data length 
    asnGetBytes data $length string
    set print [encoding convertfrom ascii $string]
    return
}
#------------------------------------------------------------------------
# asnGetBMPString: Decode Basic Multiningval (UCS2 string) from data
#------------------------------------------------------------------------
proc asn::asnGetBMPString {data_var print_var} {
    upvar 1 $data_var data $print_var print
    asnGetByte data tag
    if {$tag != 0x1e} {
        return -code error \
            [format "Expected BMP String (0x1e), but got %02x" $tag]  
    }
    asnGetLength data length 
	asnGetBytes data $length string
	if {$::tcl_platform(byteOrder) eq "littleEndian"} {
		set str2 ""
		foreach {hi lo} [split $string ""] {
			append str2 $lo $hi
		}
	} else {
		set str2 $string
	}
	set print [encoding convertfrom unicode $str2]
	return
}	
#------------------------------------------------------------------------
# asnGetUTF8String: Decode UTF8 string from data
#------------------------------------------------------------------------
proc asn::asnGetUTF8String {data_var print_var} {
    upvar 1 $data_var data $print_var print
    asnGetByte data tag
    if {$tag != 0x0c} {
        return -code error \
            [format "Expected UTF8 String (0x0c), but got %02x" $tag]  
    }
    asnGetLength data length 
	asnGetBytes data $length string
	#there should be some error checking to see if input is
	#properly-formatted utf8
	set print [encoding convertfrom utf-8 $string]
	
	return
}	
#-----------------------------------------------------------------------------
# asnGetNull: decode a NULL value
#-----------------------------------------------------------------------------

proc ::asn::asnGetNull {data_var} {
    upvar 1 $data_var data 

    asnGetByte data tag
    if {$tag != 0x05} {
        return -code error \
            [format "Expected NULL (0x05), but got %02x" $tag]
    }

    asnGetLength data length
    asnGetBytes data $length bytes
    
    # we do not check the null data, all bytes must be 0x00
    
    return
}

#----------------------------------------------------------------------------
# MultiType string routines
#----------------------------------------------------------------------------

namespace eval asn {
	variable stringTypes
	array set stringTypes {
		12 NumericString 
		13 PrintableString 
		16 IA5String 
		1e BMPString 
		0c UTF8String 
		14 T61String
		15 VideotexString
		1a VisibleString
		1b GeneralString
		1c UniversalString
	}	
	variable defaultStringType UTF8
}	
#---------------------------------------------------------------------------
# asnGetString - get readable string automatically detecting its type
#---------------------------------------------------------------------------
proc ::asn::asnGetString {data_var print_var {type_var {}}} {
	variable stringTypes
	upvar 1 $data_var data $print_var print
	asnPeekByte data tag
	set tag [format %02x $tag]
	if {![info exists stringTypes($tag)]} {
		return -code error "Expected one of string types, but got $tag"
	}
	asnGet$stringTypes($tag) data print
	if {[string length $type_var]} {
		upvar $type_var type
		set type $stringTypes($tag)
	}	
}
#---------------------------------------------------------------------
# defaultStringType - set or query default type for unrestricted strings
#---------------------------------------------------------------------
proc ::asn::defaultStringType {{type {}}} {
	variable defaultStringType
	if {![string length $type]} {
		return $defaultStringType
	}
	if {$type ne "BMP" && $type ne "UTF8"} {
		return -code error "Invalid default string type. Should be one of BMP, UTF8"
	}
	set defaultStringType $type
	return
}	

#---------------------------------------------------------------------------
# asnString - encode readable string into most restricted type possible
#---------------------------------------------------------------------------

proc ::asn::asnString {string} {
	variable nonPrintableChars
	variable nonNumericChars
	if {[string length $string]!=[string bytelength $string]} {
	# There are non-ascii character
		variable defaultStringType
		return [asn${defaultStringType}String $string]
	} elseif {![regexp $nonNumericChars $string]} {
		return [asnNumericString $string]
	} elseif {![regexp $nonPrintableChars $string]} {
		return [asnPrintableString $string]
	} else {
		return [asnIA5String $string]
	}	
}

#-----------------------------------------------------------------------------
package provide asn 0.8.4

