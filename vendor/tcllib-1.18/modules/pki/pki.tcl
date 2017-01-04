#! /usr/bin/env tclsh
# -*- tcl -*-
# RSA
#
# (c) 2010, 2011, 2012, 2013 Roy Keene.
#	 BSD Licensed.

# # ## ### ##### ######## #############
## Requisites

package require Tcl 8.5

## Versions of asn lower than 0.8.4 are known to have defects
package require asn 0.8.4

## Further dependencies
package require aes
package require des
package require math::bignum
package require md5 2
package require sha1
package require sha256

# # ## ### ##### ######## #############
## Requisites

namespace eval ::pki {
	variable oids
	array set oids {
		1.2.840.113549.1.1.1           rsaEncryption
		1.2.840.113549.1.1.5           sha1WithRSAEncryption
		1.2.840.113549.2.5             md5
		1.3.14.3.2.26                  sha1
		2.16.840.1.101.3.4.2.1         sha256
		0.9.2342.19200300.100.1.1      uid
		0.9.2342.19200300.100.1.10     manager
		0.9.2342.19200300.100.1.11     documentIdentifier
		0.9.2342.19200300.100.1.12     documentTitle
		0.9.2342.19200300.100.1.13     documentVersion
		0.9.2342.19200300.100.1.14     documentAuthor
		0.9.2342.19200300.100.1.15     documentLocation
		0.9.2342.19200300.100.1.2      textEncodedORAddress
		0.9.2342.19200300.100.1.20     homePhone
		0.9.2342.19200300.100.1.21     secretary
		0.9.2342.19200300.100.1.22     otherMailbox
		0.9.2342.19200300.100.1.25     dc
		0.9.2342.19200300.100.1.26     aRecord
		0.9.2342.19200300.100.1.27     mDRecord
		0.9.2342.19200300.100.1.28     mXRecord
		0.9.2342.19200300.100.1.29     nSRecord
		0.9.2342.19200300.100.1.3      mail
		0.9.2342.19200300.100.1.30     sOARecord
		0.9.2342.19200300.100.1.31     cNAMERecord
		0.9.2342.19200300.100.1.37     associatedDomain
		0.9.2342.19200300.100.1.38     associatedName
		0.9.2342.19200300.100.1.39     homePostalAddress
		0.9.2342.19200300.100.1.4      info
		0.9.2342.19200300.100.1.40     personalTitle
		0.9.2342.19200300.100.1.41     mobile
		0.9.2342.19200300.100.1.42     pager
		0.9.2342.19200300.100.1.43     co
		0.9.2342.19200300.100.1.43     friendlyCountryName
		0.9.2342.19200300.100.1.44     uniqueIdentifier
		0.9.2342.19200300.100.1.45     organizationalStatus
		0.9.2342.19200300.100.1.46     janetMailbox
		0.9.2342.19200300.100.1.47     mailPreferenceOption
		0.9.2342.19200300.100.1.48     buildingName
		0.9.2342.19200300.100.1.49     dSAQuality
		0.9.2342.19200300.100.1.5      drink
		0.9.2342.19200300.100.1.50     singleLevelQuality
		0.9.2342.19200300.100.1.51     subtreeMinimumQuality
		0.9.2342.19200300.100.1.52     subtreeMaximumQuality
		0.9.2342.19200300.100.1.53     personalSignature
		0.9.2342.19200300.100.1.54     dITRedirect
		0.9.2342.19200300.100.1.55     audio
		0.9.2342.19200300.100.1.56     documentPublisher
		0.9.2342.19200300.100.1.6      roomNumber
		0.9.2342.19200300.100.1.60     jpegPhoto
		0.9.2342.19200300.100.1.7      photo
		0.9.2342.19200300.100.1.8      userClass
		0.9.2342.19200300.100.1.9      host
		1.2.840.113549.1.9.1           email
		1.3.6.1.4.1.2428.90.1.1        norEduOrgUniqueNumber
		1.3.6.1.4.1.2428.90.1.11       norEduOrgSchemaVersion
		1.3.6.1.4.1.2428.90.1.12       norEduOrgNIN
		1.3.6.1.4.1.2428.90.1.2        norEduOrgUnitUniqueNumber
		1.3.6.1.4.1.2428.90.1.3        norEduPersonBirthDate
		1.3.6.1.4.1.2428.90.1.4        norEduPersonLIN
		1.3.6.1.4.1.2428.90.1.5        norEduPersonNIN
		1.3.6.1.4.1.2428.90.1.6        norEduOrgAcronym
		1.3.6.1.4.1.2428.90.1.7        norEduOrgUniqueIdentifier
		1.3.6.1.4.1.2428.90.1.8        norEduOrgUnitUniqueIdentifier
		1.3.6.1.4.1.2428.90.1.9        federationFeideSchemaVersion
		1.3.6.1.4.1.250.1.57           labeledURI
		1.3.6.1.4.1.5923.1.1.1.1       eduPersonAffiliation
		1.3.6.1.4.1.5923.1.1.1.10      eduPersonTargetedID
		1.3.6.1.4.1.5923.1.1.1.2       eduPersonNickname
		1.3.6.1.4.1.5923.1.1.1.3       eduPersonOrgDN
		1.3.6.1.4.1.5923.1.1.1.4       eduPersonOrgUnitDN
		1.3.6.1.4.1.5923.1.1.1.5       eduPersonPrimaryAffiliation
		1.3.6.1.4.1.5923.1.1.1.6       eduPersonPrincipalName
		1.3.6.1.4.1.5923.1.1.1.7       eduPersonEntitlement
		1.3.6.1.4.1.5923.1.1.1.8       eduPersonPrimaryOrgUnitDN
		1.3.6.1.4.1.5923.1.1.1.9       eduPersonScopedAffiliation
		1.3.6.1.4.1.5923.1.2.1.2       eduOrgHomePageURI
		1.3.6.1.4.1.5923.1.2.1.3       eduOrgIdentityAuthNPolicyURI
		1.3.6.1.4.1.5923.1.2.1.4       eduOrgLegalName
		1.3.6.1.4.1.5923.1.2.1.5       eduOrgSuperiorURI
		1.3.6.1.4.1.5923.1.2.1.6       eduOrgWhitePagesURI
		1.3.6.1.4.1.5923.1.5.1.1       isMemberOf
		2.16.840.1.113730.3.1.1        carLicense
		2.16.840.1.113730.3.1.2        departmentNumber
		2.16.840.1.113730.3.1.216      userPKCS12
		2.16.840.1.113730.3.1.241      displayName
		2.16.840.1.113730.3.1.3        employeeNumber
		2.16.840.1.113730.3.1.39       preferredLanguage
		2.16.840.1.113730.3.1.4        employeeType
		2.16.840.1.113730.3.1.40       userSMIMECertificate
		2.5.4.0                        objectClass
		2.5.4.1                        aliasedEntryName
		2.5.4.10                       o
		2.5.4.11                       ou
		2.5.4.12                       title
		2.5.4.13                       description
		2.5.4.14                       searchGuide
		2.5.4.15                       businessCategory
		2.5.4.16                       postalAddress
		2.5.4.17                       postalCode
		2.5.4.18                       postOfficeBox
		2.5.4.19                       physicalDeliveryOfficeName
		2.5.4.2                        knowledgeInformation
		2.5.4.20                       telephoneNumber
		2.5.4.21                       telexNumber
		2.5.4.22                       teletexTerminalIdentifier
		2.5.4.23                       facsimileTelephoneNumber
		2.5.4.23                       fax
		2.5.4.24                       x121Address
		2.5.4.25                       internationaliSDNNumber
		2.5.4.26                       registeredAddress
		2.5.4.27                       destinationIndicator
		2.5.4.28                       preferredDeliveryMethod
		2.5.4.29                       presentationAddress
		2.5.4.3                        cn
		2.5.4.30                       supportedApplicationContext
		2.5.4.31                       member
		2.5.4.32                       owner
		2.5.4.33                       roleOccupant
		2.5.4.34                       seeAlso
		2.5.4.35                       userPassword
		2.5.4.36                       userCertificate
		2.5.4.37                       cACertificate
		2.5.4.38                       authorityRevocationList
		2.5.4.39                       certificateRevocationList
		2.5.4.4                        sn
		2.5.4.40                       crossCertificatePair
		2.5.4.41                       name
		2.5.4.42                       gn
		2.5.4.43                       initials
		2.5.4.44                       generationQualifier
		2.5.4.45                       x500UniqueIdentifier
		2.5.4.46                       dnQualifier
		2.5.4.47                       enhancedSearchGuide
		2.5.4.48                       protocolInformation
		2.5.4.49                       distinguishedName
		2.5.4.5                        serialNumber
		2.5.4.50                       uniqueMember
		2.5.4.51                       houseIdentifier
		2.5.4.52                       supportedAlgorithms
		2.5.4.53                       deltaRevocationList
		2.5.4.54                       dmdName
		2.5.4.6                        c
		2.5.4.65                       pseudonym
		2.5.4.7                        l
		2.5.4.8                        st
		2.5.4.9                        street
		2.5.29.14                      id-ce-subjectKeyIdentifier
		2.5.29.15                      id-ce-keyUsage
		2.5.29.16                      id-ce-privateKeyUsagePeriod
		2.5.29.17                      id-ce-subjectAltName
		2.5.29.18                      id-ce-issuerAltName
		2.5.29.19                      id-ce-basicConstraints
		2.5.29.20                      id-ce-cRLNumber
		2.5.29.32                      id-ce-certificatePolicies
		2.5.29.33                      id-ce-cRLDistributionPoints
		2.5.29.35                      id-ce-authorityKeyIdentifier
	}

	variable handlers
	array set handlers {
		rsa                            {::pki::rsa::encrypt ::pki::rsa::decrypt ::pki::rsa::generate ::pki::rsa::serialize_key}
	}

	variable INT_MAX [expr {[format "%u" -1] / 2}]
}

namespace eval ::pki::rsa {}
namespace eval ::pki::x509 {}
namespace eval ::pki::pkcs {}

# # ## ### ##### ######## #############
## Implementation

proc ::pki::_dec_to_hex {num} {
	set retval [format %llx $num]
	return $retval
}

proc ::pki::_dec_to_ascii {num {bitlen -1}} {
	set retval ""

	while {$num} {
		set currchar [expr {$num & 0xff}]
		set retval "[format %c $currchar]$retval"
		set num [expr {$num >> 8}]
	}

	if {$bitlen != -1} {
		set bytelen [expr {$bitlen / 8}]
		while {[string length $retval] < $bytelen} {
			set retval "\x00$retval"
		}
	}

	return $retval
}

proc ::pki::_powm {x y m} {
	if {$y == 0} {
		return 1
	}

	set retval 1

	while {$y > 0} {
		if {($y & 1) == 1} {
			set retval [expr {($retval * $x) % $m}]
		}

		set y [expr {$y >> 1}]
		set x [expr {($x * $x) % $m}]
	}

	return $retval
}

## **NOTE** Requires that "m" be prime
### a^-1 === a^(m-2)    (all mod m)
proc ::pki::_modi {a m} {
	return [_powm $a [expr {$m - 2}] $m]
}

proc ::pki::_oid_number_to_name {oid} {
	set oid [join $oid .]

	if {[info exists ::pki::oids($oid)]} {
		return $::pki::oids($oid)
	}

	return $oid
}

proc ::pki::_oid_name_to_number {name} {
	foreach {chkoid chkname} [array get ::pki::oids] {
		if {[string equal -nocase $chkname $name]} {
			return [split $chkoid .]
		}
	}

	return -code error
}

proc ::pki::rsa::_encrypt_num {input exponent mod} {
	set ret [::pki::_powm $input $exponent $mod]

	return $ret
}

proc ::pki::rsa::_decrypt_num {input exponent mod} {
	set ret [::pki::_powm $input $exponent $mod]

	return $ret
}

proc ::pki::_pad_pkcs {data bitlength {blocktype 2}} {
	set ret ""

	set bytes_to_pad [expr {($bitlength / 8) - 3 - [string length $data]}]
	if {$bytes_to_pad < 0} {
		return $data
	}

	switch -- $blocktype {
		0 {
		}
		1 {
			append ret "\x00\x01"
			append ret [string repeat "\xff" $bytes_to_pad]
			append ret "\x00"
		}
		2 {
			append ret "\x00\x02"
			for {set idx 0} {$idx < $bytes_to_pad} {incr idx} {
				append ret [format %c [expr {int(rand() * 255 + 1)}]]
			}
			append ret "\x00"
		}
	}

	append ret $data

	return $ret
}

proc ::pki::_unpad_pkcs {data} {
	set check [string index $data 0]
	binary scan [string index $data 1] H* blocktype
	set datalen [string length $data]

	if {$check != "\x00"} {
		return $data
	}

	switch -- $blocktype {
		"00" {
			# Padding Scheme 1, the first non-zero byte is the start of data
			for {set idx 2} {$idx < $datalen} {incr idx} {
				set char [string index $data $idx]
				if {$char != "\x00"} {
					set ret [string range $data $idx end]
				}
			}
		}
		"01" {
			# Padding Scheme 2, pad bytes are 0xFF followed by 0x00
			for {set idx 2} {$idx < $datalen} {incr idx} {
				set char [string index $data $idx]
				if {$char != "\xff"} {
					if {$char == "\x00"} {
						set ret [string range $data [expr {$idx + 1}] end]

						break
					} else {
						return -code error "Invalid padding, seperator byte is not 0x00"
					}
				}
			}
		}
		"02" {
			# Padding Scheme 3, pad bytes are random, followed by 0x00
			for {set idx 2} {$idx < $datalen} {incr idx} {
				set char [string index $data $idx]
				if {$char == "\x00"} {
					set ret [string range $data [expr {$idx + 1}] end]

					break
				}
			}
		}
		default {
			return $data
		}
	}

	if {![info exists ret]} {
		return -code error "Invalid padding, no seperator byte found"
	}

	return $ret
}

proc ::pki::rsa::encrypt {mode input keylist} {
	switch -- $mode {
		"pub" {
			set exponent_ent e
		}
		"priv" {
			set exponent_ent d
		}
	}

	array set key $keylist

	set exponent $key($exponent_ent)
	set mod $key(n)

	## RSA requires that the input be no larger than the key
	set input_len_bits [expr {[string length $input] * 8}]
	if {$key(l) < $input_len_bits} {
		return -code error "Message length exceeds key length"
	}

	binary scan $input H* input_num

	set input_num "0x${input_num}"

	set retval_num [_encrypt_num $input_num $exponent $mod]

	set retval [::pki::_dec_to_ascii $retval_num $key(l)]

	return $retval
}

proc ::pki::rsa::decrypt {mode input keylist} {
	switch -- $mode {
		"pub" {
			set exponent_ent e
		}
		"priv" {
			set exponent_ent d
		}
	}

	array set key $keylist

	set exponent $key($exponent_ent)
	set mod $key(n)

	binary scan $input H* input_num

	set input_num "0x${input_num}"

	set retval_num [_decrypt_num $input_num $exponent $mod]

	set retval [::pki::_dec_to_ascii $retval_num $key(l)]

	return $retval
}

proc ::pki::rsa::serialize_key {keylist} {
	array set key $keylist

	foreach entry [list n e d p q] {
		if {![info exists key($entry)]} {
			return -code error "Key does not contain an element $entry"
		}
	}

	# Exponent 1
	## d (mod p-1)
	set e1 [expr {$key(d) % ($key(p) - 1)}]

	# Exponent 2
	#set e2 [expr d mod (q-1)]
	set e2 [expr {$key(d) % ($key(q) - 1)}]

	# Coefficient
	## Modular multiplicative inverse of q mod p
	set c [::pki::_modi $key(q) $key(p)]

	set ret [::asn::asnSequence \
			[::asn::asnBigInteger [::math::bignum::fromstr 0]] \
			[::asn::asnBigInteger [::math::bignum::fromstr $key(n)]] \
			[::asn::asnBigInteger [::math::bignum::fromstr $key(e)]] \
			[::asn::asnBigInteger [::math::bignum::fromstr $key(d)]] \
			[::asn::asnBigInteger [::math::bignum::fromstr $key(p)]] \
			[::asn::asnBigInteger [::math::bignum::fromstr $key(q)]] \
			[::asn::asnBigInteger [::math::bignum::fromstr $e1]] \
			[::asn::asnBigInteger [::math::bignum::fromstr $e2]] \
			[::asn::asnBigInteger [::math::bignum::fromstr $c]] \
	]

	return [list data $ret begin "-----BEGIN RSA PRIVATE KEY-----" end "-----END RSA PRIVATE KEY-----"]
}

proc ::pki::_lookup_command {action keylist} {
	array set key $keylist

	set type $key(type)

	switch -- $action {
		"encrypt" {
			set idx 0
		}
		"decrypt" {
			set idx 1
		}
		"generate" {
			set idx 2
		}
		"serialize_key" {
			set idx 3
		}
	}

	set cmdlist $::pki::handlers($type)

	set ret [lindex $cmdlist $idx]

	return $ret
}

proc ::pki::encrypt args {
	set outmode "hex"
	set enablepad 1

	set argsmode 0
	set newargs [list]
	foreach arg $args {
		if {![string match "-*" $arg]} {
			set argsmode 1
		}

		if {$argsmode} {
			lappend newargs $arg
			continue
		}

		switch -- $arg {
			"-pub" {
				set mode pub
				set padmode 2
			}
			"-priv" {
				set mode priv
				set padmode 1
			}
			"-hex" {
				set outmode "hex"
			}
			"-binary" {
				set outmode "bin"
			}
			"-pad" {
				set enablepad 1
			}
			"-nopad" {
				set enablepad 0
			}
			"--" {
				set argsmode 1
			}
			default {
				return -code error "usage: encrypt ?-binary? ?-hex? ?-pad? ?-nopad? -priv|-pub ?--? input key"
			}
		}
	}
	set args $newargs

	if {[llength $args] != 2 || ![info exists mode]} {
		return -code error "usage: encrypt ?-binary? ?-hex? ?-pad? ?-nopad? -priv|-pub ?--? input key"
	}

	set input [lindex $args 0]
	set keylist [lindex $args 1]
	array set key $keylist

	if {$enablepad} {
		set input [::pki::_pad_pkcs $input $key(l) $padmode]
	}

	set encrypt [::pki::_lookup_command encrypt $keylist]

	set retval [$encrypt $mode $input $keylist]

	switch -- $outmode {
		"hex" {
			binary scan $retval H* retval
		}
	}

	return $retval
}

proc ::pki::decrypt args {
	set inmode "hex"
	set enableunpad 1

	set argsmode 0
	set newargs [list]
	foreach arg $args {
		if {![string match "-*" $arg]} {
			set argsmode 1
		}

		if {$argsmode} {
			lappend newargs $arg
			continue
		}

		switch -- $arg {
			"-pub" {
				set mode pub
			}
			"-priv" {
				set mode priv
			}
			"-hex" {
				set inmode "hex"
			}
			"-binary" {
				set inmode "bin"
			}
			"-unpad" {
				set enableunpad 1
			}
			"-nounpad" {
				set enableunpad 0
			}
			"--" {
				set argsmode 1
			}
			default {
				return -code error "usage: decrypt ?-binary? ?-hex? ?-unpad? ?-nounpad? -priv|-pub ?--? input key"
			}
		}
	}
	set args $newargs

	if {[llength $args] != 2 || ![info exists mode]} {
		return -code error "usage: decrypt ?-binary? ?-hex? ?-unpad? ?-nounpad? -priv|-pub ?--? input key"
	}

	set input [lindex $args 0]
	set keylist [lindex $args 1]
	array set key $keylist

	switch -- $inmode {
		"hex" {
			set input [binary format H* $input]
		}
	}

	set decrypt [::pki::_lookup_command decrypt $keylist]

	set retval [$decrypt $mode $input $keylist]

	if {$enableunpad} {
		set retval [::pki::_unpad_pkcs $retval]
	}

	return $retval
}

# Hash and encrypt with private key
proc ::pki::sign {input keylist {algo "sha1"}} {
	switch -- $algo {
		"md5" {
			package require md5

			set header "\x30\x20\x30\x0c\x06\x08\x2a\x86\x48\x86\xf7\x0d\x02\x05\x05\x00\x04\x10"
			set hash [md5::md5 $input]
		}
		"sha1" {
			package require sha1

			set header "\x30\x21\x30\x09\x06\x05\x2b\x0e\x03\x02\x1a\x05\x00\x04\x14"
			set hash [sha1::sha1 -bin $input]
		}
		"sha256" {
			package require sha256

			set header "\x30\x31\x30\x0d\x06\x09\x60\x86\x48\x01\x65\x03\x04\x02\x01\x05\x00\x04\x20"
			set hash [sha2::sha256 -bin $input]
		}
		"raw" {
			set header ""
			set hash $input
		}
		default {
			return -code error "Invalid algorithm selected, must be one of: md5, sha1, sha256, raw"
		}
	}

	set plaintext "${header}${hash}"

	array set key $keylist

	set padded [::pki::_pad_pkcs $plaintext $key(l) 1]

	return [::pki::encrypt -binary -nopad -priv -- $padded $keylist]
}

# Verify known-plaintext with signature
proc ::pki::verify {signedmessage checkmessage keylist {algo default}} {
	package require asn

	if {[catch {
		set plaintext [::pki::decrypt -binary -unpad -pub -- $signedmessage $keylist]
	}]} {
		return false
	}

	if {$algo == "default"} {
		set algoId "unknown"
		set digest ""

		catch {
			::asn::asnGetSequence plaintext message
			::asn::asnGetSequence message digestInfo
			::asn::asnGetObjectIdentifier digestInfo algoId
			::asn::asnGetOctetString message digest
		}

		set algoId [::pki::_oid_number_to_name $algoId]
	} else {
		set algoId $algo
		set digest $plaintext
	}

	switch -- $algoId {
		"md5" - "md5WithRSAEncryption" {
			set checkdigest [md5::md5 $checkmessage]
		}
		"sha1" - "sha1WithRSAEncryption" {
			set checkdigest [sha1::sha1 -bin $checkmessage]
		}
		"sha256" - "sha256WithRSAEncryption" {
			set checkdigest [sha2::sha256 -bin $checkmessage]
		}
		default {
			return -code error "Unknown hashing algorithm: $algoId"
		}
	}

	if {$checkdigest != $digest} {
		return false
	}

	return true
}

proc ::pki::key {keylist {password ""} {encodePem 1}} {
	set serialize_key [::pki::_lookup_command serialize_key $keylist]

	if {$serialize_key eq ""} {
		array set key $keylist

		return -code error "Do not know how to serialize an $key(type) key"
	}

	array set retval_parts [$serialize_key $keylist]

	if {$encodePem} {
		set retval [::pki::_encode_pem $retval_parts(data) $retval_parts(begin) $retval_parts(end) $password]
	} else {
		if {$password != ""} {
			return -code error "DER encoded keys may not be password protected"
		}

		set retval $retval_parts(data)
	}

	return $retval
}

proc ::pki::_parse_init {} {
	if {[info exists ::pki::_parse_init_done]} {
		return
	}

	package require asn

	set test "FAIL"
	catch {
		set test [binary decode base64 "UEFTUw=="]
	}

	switch -- $test {
		"PASS" {
			set ::pki::rsa::base64_binary 1
		}
		"FAIL" {
			set ::pki::rsa::base64_binary 0

			package require base64
		}
	}

	set ::pki::_parse_init_done 1
	return
}

proc ::pki::_getopensslkey {password salt bytes} {
	package require md5

	set salt [string range $salt 0 7]

	set saltedkey "${password}${salt}"
	for {set ret ""} {[string length $ret] < $bytes} {} {
		if {![info exists hash]} {
			set hash $saltedkey
		} else {
			set hash "${hash}${saltedkey}"
		}

		set hash [md5::md5 $hash]

		append ret $hash
	}

	if {[string length $ret] < $bytes} {
		set bytes_to_add [expr $bytes - [string length $ret]]
		set ret "[string repeat "\x00" $bytes_to_add]${ret}"
	}

	set ret [string range $ret 0 [expr {$bytes - 1}]]

	return $ret
}

proc ::pki::_encode_pem {data begin end {password ""} {algo "aes-256-cbc"}} {
	set ret ""

	append ret "${begin}\n"
	if {$password != ""} {
		switch -glob -- $algo {
			"aes-*" {
				set algostr [string toupper $algo]
				set work [split $algo "-"]
				set algo "aes"
				set keysize [lindex $work 1]
				set mode [lindex $work 2]
				set blocksize 16
				set ivsize [expr {$blocksize * 8}]
			}
			default {
				return -code error "Only AES is currently supported"
			}
		}

		set keybytesize [expr {$keysize / 8}]
		set ivbytesize [expr {$ivsize / 8}]

		set iv ""
		while {[string length $iv] < $ivbytesize} {
			append iv [::pki::_random -binary]
		}
		set iv [string range $iv 0 [expr {$ivbytesize - 1}]]

		set password_key [::pki::_getopensslkey $password $iv $keybytesize]

		set pad [expr {$blocksize - ([string length $data] % $blocksize)}]
		append data [string repeat "\x09" $pad]

		switch -- $algo {
			"aes" {
				set data [aes::aes -dir encrypt -mode $mode -iv $iv -key $password_key -- $data]
			}
		}

		binary scan $iv H* iv
		set iv [string toupper $iv]

		append ret "Proc-Type: 4,ENCRYPTED\n"
		append ret "DEK-Info: $algostr,$iv\n"
		append ret "\n"
	}

	if {$::pki::rsa::base64_binary} {
		append ret [binary encode base64 -maxlen 64 $data]
	} else {
		append ret [::base64::encode -maxlen 64 $data]
	}
	append ret "\n"
	append ret "${end}\n"

	return $ret
}

proc ::pki::_parse_pem {pem begin end {password ""}} {
	# Unencode a PEM-encoded object
	set testpem [split $pem \n]
	set pem_startidx [lsearch -exact $testpem $begin]
	set pem_endidx [lsearch -exact -start $pem_startidx $testpem $end]

	if {$pem_startidx == -1 || $pem_endidx == -1} {
		return [list data $pem]
	}

	set pem $testpem

	incr pem_startidx
	incr pem_endidx -1

	array set ret [list]

	set newpem ""
	foreach line [lrange $pem $pem_startidx $pem_endidx] {
		if {[string match "*:*" $line]} {
			set work [split $line :]

			set var [string toupper [lindex $work 0]]
			set val [string trim [join [lrange $work 1 end] :]]

			set ret($var) $val

			continue
		}

		set line [string trim $line]

		append newpem $line
	}

	if {$newpem != ""} {
		if {$::pki::rsa::base64_binary} {
			set pem [binary decode base64 $newpem]
		} else {
			set pem [::base64::decode $newpem]
		}
	}

	if {[info exists ret(PROC-TYPE)] && [info exists ret(DEK-INFO)]} {
		if {$ret(PROC-TYPE) == "4,ENCRYPTED"} {
			if {$password == ""} {
				return [list error "ENCRYPTED"]
			}

			switch -glob -- $ret(DEK-INFO) {
				"DES-EDE3-*" {
					package require des

					# DES-EDE3-CBC,03B1F1883BFA4412
					set keyinfo $ret(DEK-INFO)

					set work [split $keyinfo ,]
					set cipher [lindex $work 0]
					set iv [lindex $work 1]

					set work [split $cipher -]
					set algo [lindex $work 0]
					set mode [string tolower [lindex $work 2]]

					set iv [binary format H* $iv]
					set password_key [::pki::_getopensslkey $password $iv 24]

					set pem [DES::des -dir decrypt -mode $mode -iv $iv -key $password_key -- $pem]
				}
				"AES-*" {
					package require aes

					# AES-256-CBC,AF517BA39E94FF39D1395C63F6DE9657
					set keyinfo $ret(DEK-INFO)

					set work [split $keyinfo ,]
					set cipher [lindex $work 0]
					set iv [lindex $work 1]

					set work [split $cipher -]
					set algo [lindex $work 0]
					set keysize [lindex $work 1]
					set mode [string tolower [lindex $work 2]]

					set iv [binary format H* $iv]
					set password_key [::pki::_getopensslkey $password $iv [expr $keysize / 8]]

					set pem [aes::aes -dir decrypt -mode $mode -iv $iv -key $password_key -- $pem]
				}
			}
		}
	}

	set ret(data) $pem

	return [array get ret]
}

proc ::pki::pkcs::parse_key {key {password ""}} {
	array set parsed_key [::pki::_parse_pem $key "-----BEGIN RSA PRIVATE KEY-----" "-----END RSA PRIVATE KEY-----" $password]

	set key_seq $parsed_key(data)

	::asn::asnGetSequence key_seq key
	::asn::asnGetBigInteger key version
	::asn::asnGetBigInteger key ret(n)
	::asn::asnGetBigInteger key ret(e)
	::asn::asnGetBigInteger key ret(d)
	::asn::asnGetBigInteger key ret(p)
	::asn::asnGetBigInteger key ret(q)

	set ret(n) [::math::bignum::tostr $ret(n)]
	set ret(e) [::math::bignum::tostr $ret(e)]
	set ret(d) [::math::bignum::tostr $ret(d)]
	set ret(p) [::math::bignum::tostr $ret(p)]
	set ret(q) [::math::bignum::tostr $ret(q)]
	set ret(l) [expr {int([::pki::_bits $ret(n)] / 8.0000 + 0.5) * 8}]
	set ret(type) rsa

	return [array get ret]
}

proc ::pki::x509::_dn_to_list {dn} {
	set ret ""

	while {$dn != ""} {
		::asn::asnGetSet dn dn_parts
		::asn::asnGetSequence dn_parts curr_part
		::asn::asnGetObjectIdentifier curr_part label
		::asn::asnGetString curr_part value

		set label [::pki::_oid_number_to_name $label]
		lappend ret $label $value
	}

	return $ret
}

proc ::pki::x509::_list_to_dn {name} {
	set ret ""
	foreach {oid_name value} $name {
		if {![regexp {[^ A-Za-z0-9'()+,.:/?=-]} $value]} {
			set asnValue [::asn::asnPrintableString $value]
		} else {
			set asnValue [::asn::asnUTF8String $value]
		}

		append ret [::asn::asnSet \
			[::asn::asnSequence \
				[::asn::asnObjectIdentifier [::pki::_oid_name_to_number $oid_name]] \
				$asnValue \
			] \
		] \
	}

	return $ret
}

proc ::pki::x509::_dn_to_string {dn} {
	set ret [list]

	foreach {label value} [_dn_to_list $dn] {
		set label [string toupper $label]

		lappend ret "$label=$value"
	}

	set ret [join $ret {, }]

	return $ret
}

proc ::pki::x509::_string_to_dn {string} {
	foreach {label value} [split $string ",="] {
		set label [string trim $label]
		set value [string trim $value]

		lappend namelist $label $value
	}

	return [_list_to_dn $namelist]
}

proc ::pki::x509::_dn_to_cn {dn} {
	foreach {label value} [split $dn ",="] {
		set label [string toupper [string trim $label]]
		set value [string trim $value]

		if {$label == "CN"} {
			return $value
		}
	}

	return ""
}

proc ::pki::x509::_utctime_to_native {utctime} {
	return [clock scan $utctime -format {%y%m%d%H%M%SZ} -gmt true]
}

proc ::pki::x509::_native_to_utctime {time} {
	return [clock format $time -format {%y%m%d%H%M%SZ} -gmt true]
}

proc ::pki::x509::parse_cert {cert} {
	array set parsed_cert [::pki::_parse_pem $cert "-----BEGIN CERTIFICATE-----" "-----END CERTIFICATE-----"]
	set cert_seq $parsed_cert(data)

	array set ret [list]

	# Decode X.509 certificate, which is an ASN.1 sequence
	::asn::asnGetSequence cert_seq wholething
	::asn::asnGetSequence wholething cert

	set ret(cert) $cert
	set ret(cert) [::asn::asnSequence $ret(cert)]
	binary scan $ret(cert) H* ret(cert)

	::asn::asnPeekByte cert peek_tag
	if {$peek_tag != 0x02} {
		# Version number is optional, if missing assumed to be value of 0
		::asn::asnGetContext cert - asn_version
		::asn::asnGetInteger asn_version ret(version)
		incr ret(version)
	} else {
		set ret(version) 1
	}

	::asn::asnGetBigInteger cert ret(serial_number)
	::asn::asnGetSequence cert data_signature_algo_seq
		::asn::asnGetObjectIdentifier data_signature_algo_seq ret(data_signature_algo)
	::asn::asnGetSequence cert issuer
	::asn::asnGetSequence cert validity
		::asn::asnGetUTCTime validity ret(notBefore)
		::asn::asnGetUTCTime validity ret(notAfter)
	::asn::asnGetSequence cert subject
	::asn::asnGetSequence cert pubkeyinfo
		::asn::asnGetSequence pubkeyinfo pubkey_algoid
			::asn::asnGetObjectIdentifier pubkey_algoid ret(pubkey_algo)
		::asn::asnGetBitString pubkeyinfo pubkey

	set extensions_list [list]
	while {$cert != ""} {
		::asn::asnPeekByte cert peek_tag

		switch -- [format {0x%02x} $peek_tag] {
			"0xa1" {
				::asn::asnGetContext cert - issuerUniqID
			}
			"0xa2" {
				::asn::asnGetContext cert - subjectUniqID
			}
			"0xa3" {
				::asn::asnGetContext cert - extensions_ctx
				::asn::asnGetSequence extensions_ctx extensions
				while {$extensions != ""} {
					::asn::asnGetSequence extensions extension
						::asn::asnGetObjectIdentifier extension ext_oid

						::asn::asnPeekByte extension peek_tag
						if {$peek_tag == 0x1} {
							::asn::asnGetBoolean extension ext_critical
						} else {
							set ext_critical false
						}

						::asn::asnGetOctetString extension ext_value_seq

					set ext_oid [::pki::_oid_number_to_name $ext_oid]

					set ext_value [list $ext_critical]

					switch -- $ext_oid {
						id-ce-basicConstraints {
							::asn::asnGetSequence ext_value_seq ext_value_bin

							if {$ext_value_bin != ""} {
								::asn::asnGetBoolean ext_value_bin allowCA
							} else {
								set allowCA "false"
							}

							if {$ext_value_bin != ""} {
								::asn::asnGetInteger ext_value_bin caDepth
							} else {
								set caDepth -1
							}
						
							lappend ext_value $allowCA $caDepth
						}
						default {
							binary scan $ext_value_seq H* ext_value_seq_hex
							lappend ext_value $ext_value_seq_hex
						}
					}

					lappend extensions_list $ext_oid $ext_value
				}
			}
		}
	}
	set ret(extensions) $extensions_list

	::asn::asnGetSequence wholething signature_algo_seq
	::asn::asnGetObjectIdentifier signature_algo_seq ret(signature_algo)
	::asn::asnGetBitString wholething ret(signature)

	# Convert values from ASN.1 decoder to usable values if needed
	set ret(notBefore) [::pki::x509::_utctime_to_native $ret(notBefore)]
	set ret(notAfter) [::pki::x509::_utctime_to_native $ret(notAfter)]
	set ret(serial_number) [::math::bignum::tostr $ret(serial_number)]
	set ret(data_signature_algo) [::pki::_oid_number_to_name $ret(data_signature_algo)]
	set ret(signature_algo) [::pki::_oid_number_to_name $ret(signature_algo)]
	set ret(pubkey_algo) [::pki::_oid_number_to_name $ret(pubkey_algo)]
	set ret(issuer) [_dn_to_string $issuer]
	set ret(subject) [_dn_to_string $subject]
	set ret(signature) [binary format B* $ret(signature)]
	binary scan $ret(signature) H* ret(signature)

	# Handle RSA public keys by extracting N and E
	switch -- $ret(pubkey_algo) {
		"rsaEncryption" {
			set pubkey [binary format B* $pubkey]
			binary scan $pubkey H* ret(pubkey)

			::asn::asnGetSequence pubkey pubkey_parts
			::asn::asnGetBigInteger pubkey_parts ret(n)
			::asn::asnGetBigInteger pubkey_parts ret(e)

			set ret(n) [::math::bignum::tostr $ret(n)]
			set ret(e) [::math::bignum::tostr $ret(e)]
			set ret(l) [expr {int([::pki::_bits $ret(n)] / 8.0000 + 0.5) * 8}]
			set ret(type) rsa
		}
	}

	return [array get ret]
}

# Verify whether a cert is valid, regardless of trust
proc ::pki::x509::validate_cert {cert args} {
	# Verify arguments and load options
	for {set idx 0} {$idx < [llength $args]} {incr idx} {
		set arg [lindex $args $idx]

		switch -- $arg {
			"-sign_message" {
				incr idx
				set dn [lindex $args $idx]
				set cn [_dn_to_cn $dn]

				set opts(sign_message) $cn
			}
			"-encrypt_message" {
				incr idx
				set dn [lindex $args $idx]
				set cn [_dn_to_cn $dn]

				set opts(encrypt_message) $cn
			}
			"-sign_cert" {
				incr idx
				set dn [lindex $args $idx]
				if {$dn == "ALL" || $dn == "ANY"} {
					set cn $dn
				} else {
					set cn [_dn_to_cn $dn]
				}

				incr idx
				set currdepth [lindex $args $idx]

				set opts(sign_cert) [list $cn $currdepth]
			}
			"-ssl" {
				incr idx
				set dn [lindex $args $idx]
				set cn [_dn_to_cn $dn]

				set opts(ssl) $cn
			}
			default {
				return -code error {wrong # args: should be "validate_cert cert ?-sign_message dn_of_signer? ?-encrypt_message dn_of_signer? ?-sign_cert [dn_to_be_signed | ANY | ALL] ca_depth? ?-ssl dn?"}
			}
		}
	}

	# Load cert
	array set cert_arr $cert

	# Validate certificate
	## Validate times
	if {![info exists cert_arr(notBefore)] || ![info exists cert_arr(notAfter)]} {
		return false
	}

	set currtime [clock seconds]
	if {$currtime < $cert_arr(notBefore) || $currtime > $cert_arr(notAfter)} {
		return false
	}

	# Check for extensions and process them
	## Critical extensions must be understood, non-critical extensions may be ignored if not understood
	set CA 0
	set CAdepth -1
	foreach {ext_id ext_val} $cert_arr(extensions) {
		set critical [lindex $ext_val 0]

		switch -- $ext_id {
			id-ce-basicConstraints {
				set CA [lindex $ext_val 1]
				set CAdepth [lindex $ext_val 2]
			}
			default {
				### If this extensions is critical and not understood, we must reject it
				if {$critical} {
					return false
				}
			}
		}
	}

	if {[info exists opts(sign_cert)]} {
		if {!$CA} {
			return false
		}

		if {$CAdepth >= 0} {
			set sign_depth [lindex $opts(sign_cert) 1]
			if {$sign_depth > $CAdepth} {
				return false
			}
		}
	}

	return true
}

proc ::pki::x509::verify_cert {cert trustedcerts {intermediatecerts ""}} {
	# Validate cert
	if {![validate_cert $cert]} {
		return false;
	}

	# Load trusted certs
	foreach trustedcert_list $trustedcerts {
		if {![validate_cert $trustedcert_list -sign_cert ANY -1]} {
			continue
		}

		unset -nocomplain trustedcert
		array set trustedcert $trustedcert_list

		set subject $trustedcert(subject)

		set trustedcertinfo($subject) $trustedcert_list
	}

	# Load intermediate certs
	foreach intermediatecert_list $intermediatecerts {
		if {![validate_cert $intermediatecert_list -sign_cert ANY -1]} {
			continue
		}

		unset -nocomplain intermediatecert
		array set intermediatecert $intermediatecert_list

		set subject $intermediatecert(subject)

		set intermediatecertinfo($subject) $intermediatecert_list
	}

	# Load cert
	array set cert_arr $cert

	# Verify certificate
	## Encode certificate to hash later
	set message [binary format H* $cert_arr(cert)]

	## Find CA to verify against
	if {![info exists trustedcertinfo($cert_arr(issuer))]} {
		## XXX: Try to find an intermediate path

		## XXX: Verify each cert in the intermediate path, returning in
		##      failure if a link in the chain breaks

		## Otherwise, return in failure
		return false
	}

	set cacert $trustedcertinfo($cert_arr(issuer))
	array set cacert_arr $cacert

	## Set signature to binary form
	set signature [::pki::_dec_to_ascii 0x$cert_arr(signature) $cacert_arr(l)]

	## Verify
	set ret [::pki::verify $signature $message $cacert]

	return $ret
}

# Generate a PKCS#10 Certificate Signing Request
proc ::pki::pkcs::create_csr {keylist namelist {encodePem 0} {algo "sha1"}} {
	array set key $keylist

	set name [::pki::x509::_list_to_dn $namelist]

	set type $key(type)

	switch -- $type {
		"rsa" {
			set pubkey [::asn::asnSequence \
				[::asn::asnBigInteger [::math::bignum::fromstr $key(n)]] \
				[::asn::asnBigInteger [::math::bignum::fromstr $key(e)]] \
			]
			set pubkey_algo_params [::asn::asnNull]
		}
	}
	binary scan $pubkey B* pubkey_bitstring

	set cert_req_info [::asn::asnSequence \
		[::asn::asnInteger 0] \
		[::asn::asnSequence $name] \
		[::asn::asnSequence \
			[::asn::asnSequence \
				[::asn::asnObjectIdentifier [::pki::_oid_name_to_number ${type}Encryption]] \
				$pubkey_algo_params \
			] \
			[::asn::asnBitString $pubkey_bitstring] \
		] \
		[::asn::asnContextConstr 0 ""] \
	]

	set signature [::pki::sign $cert_req_info $keylist $algo]
	binary scan $signature B* signature_bitstring
	
	set cert_req [::asn::asnSequence \
		$cert_req_info \
		[::asn::asnSequence [::asn::asnObjectIdentifier [::pki::_oid_name_to_number "${algo}With${type}Encryption"]] [::asn::asnNull]] \
		[::asn::asnBitString $signature_bitstring] \
	]

	if {$encodePem} {
		set cert_req [::pki::_encode_pem $cert_req "-----BEGIN CERTIFICATE REQUEST-----" "-----END CERTIFICATE REQUEST-----"]
	}

	return $cert_req
}

# Parse a PKCS#10 CSR
proc ::pki::pkcs::parse_csr {csr} {
	array set ret [list]

	array set parsed_csr [::pki::_parse_pem $csr "-----BEGIN CERTIFICATE REQUEST-----" "-----END CERTIFICATE REQUEST-----"]
	set csr $parsed_csr(data)

	::asn::asnGetSequence csr cert_req_seq
		::asn::asnGetSequence cert_req_seq cert_req_info

	set cert_req_info_saved [::asn::asnSequence $cert_req_info]

			::asn::asnGetInteger cert_req_info version
			::asn::asnGetSequence cert_req_info name
			::asn::asnGetSequence cert_req_info pubkeyinfo
				::asn::asnGetSequence pubkeyinfo pubkey_algoid
					::asn::asnGetObjectIdentifier pubkey_algoid pubkey_type
					::asn::asnGetBitString pubkeyinfo pubkey
		::asn::asnGetSequence cert_req_seq signature_algo_seq
			::asn::asnGetObjectIdentifier signature_algo_seq signature_algo
		::asn::asnGetBitString cert_req_seq signature_bitstring

	# Convert parsed fields to native types
	set signature [binary format B* $signature_bitstring]
	set ret(subject) [::pki::x509::_dn_to_string $name]

	## Convert Pubkey type to string
	set pubkey_type [::pki::_oid_number_to_name $pubkey_type]

	# Parse public key, based on type
	switch -- $pubkey_type {
		"rsaEncryption" {
			set pubkey [binary format B* $pubkey]

			::asn::asnGetSequence pubkey pubkey_parts
			::asn::asnGetBigInteger pubkey_parts key(n)
			::asn::asnGetBigInteger pubkey_parts key(e)

			set key(n) [::math::bignum::tostr $key(n)]
			set key(e) [::math::bignum::tostr $key(e)]
			set key(l) [expr {2**int(ceil(log([::pki::_bits $key(n)])/log(2)))}]
			set key(type) rsa
		}
		default {
			return -code error "Unsupported key type: $pubkey_type"
		}
	}

	# Convert key to RSA parts
	set keylist [array get key]

	# Validate CSR requestor has access to the private key
	set csrValid [::pki::verify $signature $cert_req_info_saved $keylist]
	if {!$csrValid} {
		return -code error "CSR Signature check failed"
	}

	array set ret $keylist

	return [array get ret]
}

proc ::pki::x509::create_cert {signreqlist cakeylist serial_number notBefore notAfter isCA extensions {encodePem 0} {algo "sha1"}} {
	# Parse parameters
	array set cakey $cakeylist
	array set signreq $signreqlist

	set type $signreq(type)

	# Process extensions
	set extensions_list $extensions
	unset extensions
	array set extensions $extensions_list

	# If we are generating a CA cert, add a CA extension
	if {$isCA} {
		set extensions(id-ce-basicConstraints) [list true true -1]
	}

	# Determine what version we need to use (default to 1)
	if {[array get extensions] == ""} {
		set version 1
	} else {
		set version 3
	}

	set certlist [list]

	# Create certificate to be signed
	## Insert version number (if not version 1)
	if {$version != 1} {
		lappend certlist [::asn::asnContextConstr 0 [::asn::asnInteger [expr {$version - 1}]]]
	}

	## Insert serial number
	lappend certlist [::asn::asnBigInteger [math::bignum::fromstr $serial_number]]

	## Insert data algorithm
	lappend certlist [::asn::asnSequence \
		[::asn::asnObjectIdentifier [::pki::_oid_name_to_number "${algo}With${type}Encryption"]] \
		[::asn::asnNull] \
	]

	## Insert issuer
	lappend certlist [::asn::asnSequence [::pki::x509::_string_to_dn $cakey(subject)]]

	## Insert validity requirements
	lappend certlist [::asn::asnSequence \
		[::asn::asnUTCTime [::pki::x509::_native_to_utctime $notBefore]] \
		[::asn::asnUTCTime [::pki::x509::_native_to_utctime $notAfter]] \
	]

	## Insert subject
	lappend certlist [::asn::asnSequence [::pki::x509::_string_to_dn $signreq(subject)]]

	## Insert public key information
	switch -- $type {
		"rsa" {
			set pubkey [::asn::asnSequence \
				[::asn::asnBigInteger [::math::bignum::fromstr $signreq(n)]] \
				[::asn::asnBigInteger [::math::bignum::fromstr $signreq(e)]] \
			]

			set pubkey_algo_params [::asn::asnNull]
		}
	}
	binary scan $pubkey B* pubkey_bitstring

	lappend certlist [::asn::asnSequence \
		[::asn::asnSequence \
			[::asn::asnObjectIdentifier [::pki::_oid_name_to_number "${type}Encryption"]] \
			$pubkey_algo_params \
		] \
		[::asn::asnBitString $pubkey_bitstring] \
	]

	## Insert extensions
	if {[array get extensions] != ""} {
		set extensionslist [list]

		foreach {extension extvalue} [array get extensions] {
			set critical 0

			switch -- $extension {
				"id-ce-basicConstraints" {
					set critical [lindex $extvalue 0]
					set allowCA [lindex $extvalue 1]
					set caDepth [lindex $extvalue 2]

					if {$caDepth < 0} {
						set extvalue [::asn::asnSequence [::asn::asnBoolean $allowCA]]
					} else {
						set extvalue [::asn::asnSequence [::asn::asnBoolean $allowCA] [::asn::asnInteger $caDepth]]
					}
				}
				default {
					return -code error "Unknown extension: $extension"
				}
			}

			lappend extensionslist [::asn::asnSequence \
				[::asn::asnObjectIdentifier [::pki::_oid_name_to_number $extension]] \
				[::asn::asnBoolean $critical] \
				[::asn::asnOctetString $extvalue] \
			]
		}

		lappend certlist [::asn::asnContextConstr 3 [::asn::asnSequenceFromList $extensionslist]]
	}

	## Enclose certificate data in an ASN.1 sequence
	set cert [::asn::asnSequenceFromList $certlist]

	# Sign certificate request using CA
	set signature [::pki::sign $cert $cakeylist $algo]
	binary scan $signature B* signature_bitstring

	set cert [::asn::asnSequence \
		$cert \
		[::asn::asnSequence \
			[::asn::asnObjectIdentifier [::pki::_oid_name_to_number "${algo}With${type}Encryption"]] \
			[::asn::asnNull] \
		] \
		[::asn::asnBitString $signature_bitstring] \
	]

	if {$encodePem} {
		set cert [::pki::_encode_pem $cert "-----BEGIN CERTIFICATE-----" "-----END CERTIFICATE-----"]
	}

	return $cert
}

proc ::pki::_bits {num} {
	if {$num == 0} {
		return 0
	}

	set num [format %llx $num]

	set numlen [string length $num]

	set numprecise 2

	if {$numlen > $numprecise} {
		set basebits [expr {($numlen - $numprecise) * 4}]
	} else {
		set basebits 0
	}

	set highbits 0x[string range $num 0 [expr {$numprecise - 1}]]

	set ret [expr {$basebits + log($highbits) / 0.69314718055994530941723}]

	set ret [expr {floor($ret) + 1}]

	set ret [lindex [split $ret .] 0]

	return $ret
}

proc ::pki::_random args {
	if {[lindex $args 0] == "-binary"} {
		set outputmode binary
	} else {
		set outputmode numeric
	}

	if {![info exists ::pki::_random_dev]} {
		foreach trydev [list /dev/urandom /dev/random __RAND__] {
			if {$trydev != "__RAND__"} {
				if {[catch {
					set fd [open $trydev [list RDONLY BINARY]]
					close $fd
					unset fd
				}]} {
					continue
				}
			}

			set ::pki::_random_dev $trydev

			break
		}
	}

	set dev ${::pki::_random_dev}

	switch -- $dev {
		"__RAND__" {
			set ret [expr {int(rand() * 2147483647)}]
		}
		default {
			set fd [open $dev [list RDONLY BINARY]]
			set data [read $fd 8]
			close $fd

			binary scan $data H* ret
			set ret [expr 0x$ret]
		}
	}

	switch -- $outputmode {
		"numeric" {
			# Do nothing, results are already numeric
		}
		"binary" {
			set ret [binary format H* [format %02llx $ret]]
		}
	}

	return $ret
}

proc ::pki::_isprime {n} {
	set k 10

	if {$n <= 3} {
		return true
	}

	if {$n % 2 == 0} {
		return false
	}
	
	# write n - 1 as 2^s·d with d odd by factoring powers of 2 from n \u2212 1
	set d [expr {$n - 1}]
	set s 0
	while {$d % 2 == 0} {
		set d [expr {$d / 2}]
		incr s
	}
	
	while {$k > 0} {
		incr k -1
		set rand_1 [expr {int(rand() * $::pki::INT_MAX)}]
		set rand_2 [expr {int(rand() * $::pki::INT_MAX)}]
		if {$rand_1 < $rand_2} {
			set rand_num $rand_1
			set rand_den $rand_2
		} else {
			set rand_num $rand_2
			set rand_den $rand_1
		}

		set a [expr {2 + (($n - 4) * $rand_num / $rand_den)}]

		set x [_powm $a $d $n]
		if {$x == 1 || $x == $n - 1} {
			continue
		}

		for {set r 1} {$r < $s} {incr r} {
			set x [_powm $x 2 $n]
			if {$x == 1} {
				return false
			}
			if {$x == $n - 1} {
				break
			}
		}

		if {$x != $n - 1} {
			return false
		}
	}

	return true
}

proc ::pki::rsa::_generate_private {p q e bitlength} {
	set totient [expr {($p - 1) * ($q - 1)}]

	for {set di 1} {$di < $e} {incr di} {
		set dchk [expr {($totient * $di + 1) / $e}]
		set chkval [expr {$dchk * $e - 1}]

		set rem [expr {$chkval % $totient}]
		if {$rem == 0} {
			break
		}
	}

	# puts "bd=[_bits $dchk], di = $di"
	for {} {1} {incr di $e} {
		set dchk [expr {($totient * $di + 1) / $e}]
		set chkval [expr {$dchk * $e - 1}]

		set rem [expr {$chkval % $totient}]
		if {$rem == 0} {
			if {[::pki::_bits $dchk] > $bitlength} {
				if {![info exists d]} {
					set d $dchk
				}

				break
			}

			set d $dchk
		}

	}

	return $d
}

proc ::pki::rsa::generate {bitlength {exponent 0x10001}} {
	set e $exponent

	# Step 1. Pick 2 numbers that when multiplied together will give a number with the appropriate length
	set componentbitlen [expr {$bitlength / 2}]
	set bitmask [expr {(1 << $componentbitlen) - 1}]

	set p 0
	set q 0
	while 1 {
		set plen [::pki::_bits $p]
		set qlen [::pki::_bits $q]

		if {$plen >= $componentbitlen} {
			set p [expr {$p & $bitmask}]

			set plen [::pki::_bits $p]
		}

		if {$qlen >= $componentbitlen} {
			set q [expr {$q & $bitmask}]

			set qlen [::pki::_bits $q]
		}

		if {$plen >= $componentbitlen && $qlen >= $componentbitlen} {
			break
		}

		set x [::pki::_random]
		set y [::pki::_random]

		set xlen [expr {[::pki::_bits $x] / 2}]
		set ylen [expr {[::pki::_bits $y] / 2}]

		set xmask [expr {(1 << $xlen) - 1}]
		set ymask [expr {(1 << $ylen) - 1}]

		set p [expr {($p << $xlen) + ($x & $xmask)}]
		set q [expr {($q << $ylen) + ($y & $ymask)}]
	}


	# Step 2. Verify that "p" and "q" are useful
	## Step 2.a. Verify that they are not too close
	### Where "too close" is defined as 2*n^(1/4)
	set quadroot_of_n [expr {isqrt(isqrt($p * $q))}]
	set min_distance [expr {2 * $quadroot_of_n}]
	set distance [expr {abs($p - $q)}]

	if {$distance < $min_distance} {
		#### Try again.

		return [::pki::rsa::generate $bitlength $exponent]
	}

	# Step 3. Convert the numbers into prime numbers
	if {$p % 2 == 0} {
		incr p -1
	}
	while {![::pki::_isprime $p]} {
		incr p -2
	}

	if {$q % 2 == 0} {
		incr q -1
	}
	while {![::pki::_isprime $q]} {
		incr q -2
	}

	# Step 4. Compute N by multiplying P and Q
	set n [expr {$p * $q}]
	set retkey(n) $n

	# Step 5. Compute D ...
	## Step 5.a. Generate D
	set d [::pki::rsa::_generate_private $p $q $e $bitlength]
	set retkey(d) $d

	## Step 5.b. Verify D is large enough
	### Verify that D is greater than (1/3)*n^(1/4) 
	set quadroot_of_n [expr {isqrt(isqrt($n))}]
	set min_d [expr {$quadroot_of_n / 3}]
	if {$d < $min_d} {
		#### Try again.

		return [::pki::rsa::generate $bitlength $exponent]
	}

	# Step 6. Encode key information
	set retkey(type) rsa
	set retkey(e) $e
	set retkey(l) $bitlength

	# Step 7. Record additional information that will be needed to write out a PKCS#1 compliant key
	set retkey(p) $p
	set retkey(q) $q

	return [array get retkey]
}

## Initialize parsing routines, which may load additional packages (base64)
::pki::_parse_init

# # ## ### ##### ######## #############
## Ready

package provide pki 0.6
