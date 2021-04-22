#! /usr/bin/env tclsh
# -*- tcl -*-
# RSA
#
# (c) 2010, 2011, 2012, 2013 Roy Keene.
#	 BSD Licensed.
# (c) 2021 Ashok P. Nadkarni
#	 BSD Licensed.

# # ## ### ##### ######## #############
## Requisites

package require Tcl 8.6

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
	# OID->name map. Note the corresponding name->OID map is constructed on
	# the fly on first use in _oid_name_to_number.
	variable oids
	array set oids {
		1.2.840.113549.1.1.1           rsaEncryption
		1.2.840.113549.1.1.4           md5WithRSAEncryption
		1.2.840.113549.1.1.5           sha1WithRSAEncryption
		1.2.840.113549.1.1.11          sha256WithRSAEncryption
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
		2.5.29.9                       subjectDirectoryAttributes
		2.5.29.14                      subjectKeyIdentifier
		2.5.29.15                      keyUsage
		2.5.29.16                      privateKeyUsagePeriod
		2.5.29.17                      subjectAltName
		2.5.29.18                      issuerAltName
		2.5.29.19                      basicConstraints
		2.5.29.20                      cRLNumber
		2.5.29.30                      nameConstraints
		2.5.29.31                      cRLDistributionPoints
		2.5.29.32                      certificatePolicies
		2.5.29.33                      policyMappings
		2.5.29.34                      policyConstraintsDeprecated
		2.5.29.35                      authorityKeyIdentifier
		2.5.29.36                      policyConstraints
		2.5.29.37                      extKeyUsage
		2.5.29.46                      freshestCRL
		2.5.29.54                      inhibitAnyPolicy
		1.3.6.1.5.5.7.3.1              serverAuth
		1.3.6.1.5.5.7.3.2              clientAuth
		1.3.6.1.5.5.7.3.3              codeSigning
		1.3.6.1.5.5.7.3.4              emailProtection
		1.3.6.1.5.5.7.3.5              ipsecEndSystem
		1.3.6.1.5.5.7.3.6              ipsecTunnel
		1.3.6.1.5.5.7.3.7              ipsecUser
		1.3.6.1.5.5.7.3.8              timeStamping
		1.3.6.1.5.5.7.3.9              OCSPSigning
		1.3.6.1.5.5.7.1.1              authorityInfoAccess
		1.3.6.1.5.5.7.1.11             subjectInfoAccess 
		1.3.6.1.5.5.7.2.1              cps
		1.3.6.1.5.5.7.2.2              unotice
		1.3.6.1.5.5.7.48.1             id-ad-ocsp
		1.3.6.1.5.5.7.48.2             id-ad-caIssuers
		1.3.6.1.5.5.7.48.3             id-ad-timeStamping
		1.3.6.1.5.5.7.48.5             id-ad-caRepository
		1.2.840.113549.1.9.14          extensionRequest
	}

	variable handlers
	array set handlers {
		rsa {
			::pki::rsa::encrypt
			::pki::rsa::decrypt
			::pki::rsa::generate
			::pki::rsa::serialize_key
			::pki::rsa::serialize_public_key
		}
	}

	variable INT_MAX [expr {[format %u -1] / 2}]
}

namespace eval ::pki::rsa {}
namespace eval ::pki::x509 {}
namespace eval ::pki::pkcs {}

# # ## ### ##### ######## #############
## Implementation


proc ::pki::_dec_to_hex num {
	set retval [format %llx $num]
	return $retval
}


proc ::pki::_dec_to_ascii {num {bitlen -1}} {
	set retval {}

	while {$num} {
		set currchar [expr {$num & 0xff}]
		set retval [format %c $currchar]$retval
		set num [expr {$num >> 8}]
	}

	if {$bitlen != -1} {
		set bytelen [expr {$bitlen / 8}]
		while {[string length $retval] < $bytelen} {
			set retval \x00$retval
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
	variable oids
	variable oid_names
	unset -nocomplain oid_names; # To handle reloading during development
	foreach {oid oid_name} [array get ::pki::oids] {
		set oid_name [string tolower $oid_name]
		set oid_names($oid_name) $oid
	}
	if {[array size oids] != [array size oid_names]} {
		return -code error "Internal error: OID->name map array oids has duplicate entries."
	}
	proc [namespace current]::_oid_name_to_number {name} {
		variable oid_names
		set lower [string tolower $name]
		if {[info exists oid_names($lower)]} {
			return [split $oid_names($lower) .]
		}
		return -code error "Unable to convert OID $name to an OID value"
	}
	return [_oid_name_to_number $name]
}

proc ::pki::_oid_number_to_dotted {oid} {
	return [join $oid .]
}

proc ::pki::_oid_dotted_to_number {dotted_oid} {
	return [split $oid .]
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
	set ret {} 

	set bytes_to_pad [expr {($bitlength / 8) - 3 - [string length $data]}]
	if {$bytes_to_pad < 0} {
		return $data
	}

	switch -- $blocktype {
		0 {
		}
		1 {
			append ret \x00\x01
			append ret [string repeat \xff $bytes_to_pad]
			append ret \x00
		}
		2 {
			append ret \x00\x02
			for {set idx 0} {$idx < $bytes_to_pad} {incr idx} {
				append ret [format %c [expr {int(rand() * 255 + 1)}]]
			}
			append ret \x00
		}
	}

	append ret $data

	return $ret
}


proc ::pki::_unpad_pkcs data {
	set check [string index $data 0]
	binary scan [string index $data 1] H* blocktype
	set datalen [string length $data]

	if {$check ne "\x00"} {
		return $data
	}

	switch -- $blocktype {
		00 {
			# Padding Scheme 1, the first non-zero byte is the start of data
			for {set idx 2} {$idx < $datalen} {incr idx} {
				set char [string index $data $idx]
				if {$char ne "\x00"} {
					set ret [string range $data $idx end]
					break
				}
			}
		}
		01 {
			# Padding Scheme 2, pad bytes are 0xFF followed by 0x00
			for {set idx 2} {$idx < $datalen} {incr idx} {
				set char [string index $data $idx]
				if {$char ne "\xff"} {
					if {$char eq "\x00"} {
						set ret [string range $data [expr {$idx + 1}] end]

						break
					} else {
						return -code error "Invalid padding, seperator byte is not 0x00"
					}
				}
			}
		}
		02 {
			# Padding Scheme 3, pad bytes are random, followed by 0x00
			for {set idx 2} {$idx < $datalen} {incr idx} {
				set char [string index $data $idx]
				if {$char eq "\x00"} {
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


proc ::pki::rsa::encrypt {mode input keylist {overhead 0}} {
	switch -- $mode {
		pub {
			set exponent_ent e
		}
		priv {
			set exponent_ent d
		}
	}

	array set key $keylist

	set exponent $key($exponent_ent)
	set mod $key(n)

	## RSA requires that the input be no larger than the key
	set input_len_bits [expr {
		([string length $input] - $overhead) * 8
	}]
	if {$key(l) < $input_len_bits} {
		return -code error "Message length exceeds key length"
	}

	binary scan $input H* input_num

	set input_num 0x${input_num}

	set retval_num [_encrypt_num $input_num $exponent $mod]

	set retval [::pki::_dec_to_ascii $retval_num $key(l)]

	return $retval
}


proc ::pki::rsa::decrypt {mode input keylist} {
	switch -- $mode {
		pub {
			set exponent_ent e
		}
		priv {
			set exponent_ent d
		}
	}

	array set key $keylist

	set exponent $key($exponent_ent)
	set mod $key(n)

	binary scan $input H* input_num

	set input_num 0x${input_num}

	set retval_num [_decrypt_num $input_num $exponent $mod]

	set retval [::pki::_dec_to_ascii $retval_num $key(l)]

	return $retval
}


proc ::pki::rsa::serialize_public_key {keylist} {
	array set key $keylist

	foreach entry [list n e] {
		if {![info exists key($entry)]} {
			return -code error "Key does not contain an element $entry"
		}
	}

	set pubkey [::asn::asnSequence [
		::asn::asnBigInteger [::math::bignum::fromstr $key(n)]] [
		::asn::asnBigInteger [::math::bignum::fromstr $key(e)]]]
	set pubkey_algo_params [::asn::asnNull]

	binary scan $pubkey B* pubkey_bitstring

	set ret [::asn::asnSequence [
		::asn::asnSequence [
			::asn::asnObjectIdentifier [::pki::_oid_name_to_number rsaEncryption]
		] $pubkey_algo_params] [
			::asn::asnBitString $pubkey_bitstring]
		]

	return [list data $ret begin -----BEGIN PUBLIC KEY----- end -----END PUBLIC KEY-----]
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

	set ret [::asn::asnSequence [
		::asn::asnBigInteger [::math::bignum::fromstr 0]] [
		::asn::asnBigInteger [::math::bignum::fromstr $key(n)]] [
		::asn::asnBigInteger [::math::bignum::fromstr $key(e)]] [
		::asn::asnBigInteger [::math::bignum::fromstr $key(d)]] [
		::asn::asnBigInteger [::math::bignum::fromstr $key(p)]] [
		::asn::asnBigInteger [::math::bignum::fromstr $key(q)]] [
		::asn::asnBigInteger [::math::bignum::fromstr $e1]] [
		::asn::asnBigInteger [::math::bignum::fromstr $e2]] [
		::asn::asnBigInteger [::math::bignum::fromstr $c]]
	]

	return [list data $ret begin {-----BEGIN RSA PRIVATE KEY-----} \
		end {-----END RSA PRIVATE KEY-----}]
}


proc ::pki::_lookup_command {action keylist} {
	array set key $keylist

	set type $key(type)

	switch -- $action {
		encrypt {
			set idx 0
		}
		decrypt {
			set idx 1
		}
		generate {
			set idx 2
		}
		serialize_key {
			set idx 3
		}
		serialize_public_key {
			set idx 4
		}
	}

	set cmdlist $::pki::handlers($type)

	set ret [lindex $cmdlist $idx]

	return $ret
}


proc ::pki::encrypt args {
	set outmode hex
	set enablepad 1

	set argsmode 0
	set newargs [list]
	foreach arg $args {
		if {![string match -* $arg]} {
			set argsmode 1
		}

		if {$argsmode} {
			lappend newargs $arg
			continue
		}

		switch -- $arg {
			-pub {
				set mode pub
				set padmode 2
			}
			-priv {
				set mode priv
				set padmode 1
			}
			-hex {
				set outmode hex
			}
			-binary {
				set outmode bin
			}
			-pad {
				set enablepad 1
			}
			-nopad {
				set enablepad 0
			}
			-- {
				set argsmode 1
			}
			default {
				return -code error "usage: encrypt ?-binary? ?-hex? ?-pad? ?-nopad?\
					-priv|-pub ?--? input key"
			}
		}
	}
	set args $newargs

	if {[llength $args] != 2 || ![info exists mode]} {
		return -code error "usage: encrypt ?-binary? ?-hex? ?-pad? ?-nopad?\
			-priv|-pub ?--? input key"
	}

	set input [lindex $args 0]
	set keylist [lindex $args 1]
	array set key $keylist

	if {$enablepad} {
		set input [::pki::_pad_pkcs $input $key(l) $padmode]
	}
	set overhead 3

	set encrypt [::pki::_lookup_command encrypt $keylist]

	set retval [$encrypt $mode $input $keylist $overhead]

	switch -- $outmode {
		hex {
			binary scan $retval H* retval
		}
	}

	return $retval
}


proc ::pki::decrypt args {
	set inmode hex
	set enableunpad 1

	set argsmode 0
	set newargs [list]
	foreach arg $args {
		if {![string match -* $arg]} {
			set argsmode 1
		}

		if {$argsmode} {
			lappend newargs $arg
			continue
		}

		switch -- $arg {
			-pub {
				set mode pub
			}
			-priv {
				set mode priv
			}
			-hex {
				set inmode hex
			}
			-binary {
				set inmode bin
			}
			-unpad {
				set enableunpad 1
			}
			-nounpad {
				set enableunpad 0
			}
			-- {
				set argsmode 1
			}
			default {
				return -code error "usage: decrypt ?-binary? ?-hex? ?-unpad? ?-nounpad?\
					-priv|-pub ?--? input key"
			}
		}
	}
	set args $newargs

	if {[llength $args] != 2 || ![info exists mode]} {
		return -code error "usage: decrypt ?-binary? ?-hex? ?-unpad? ?-nounpad?\
			-priv|-pub ?--? input key"
	}

	set input [lindex $args 0]
	set keylist [lindex $args 1]
	array set key $keylist

	switch -- $inmode {
		hex {
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
proc ::pki::sign {input keylist {algo sha1}} {
	switch -- $algo {
		md5 {
			package require md5

			set header \x30\x20\x30\x0c\x06\x08\x2a\x86\x48\x86\xf7\x0d\x02\x05\x05\x00\x04\x10
			set hash [md5::md5 $input]
		}
		sha1 {
			package require sha1

			set header \x30\x21\x30\x09\x06\x05\x2b\x0e\x03\x02\x1a\x05\x00\x04\x14
			set hash [sha1::sha1 -bin $input]
		}
		sha256 {
			package require sha256

			set header \x30\x31\x30\x0d\x06\x09\x60\x86\x48\x01\x65\x03\x04\x02\x01\x05\x00\x04\x20
			set hash [sha2::sha256 -bin $input]
		}
		raw {
			set header {}
			set hash $input
		}
		default {
			return -code error "Invalid algorithm selected, must be one of: md5, sha1, sha256, raw"
		}
	}

	set plaintext ${header}${hash}

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

	if {$algo eq {default}} {
		set algoId unknown
		set digest {}

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
		md5 - md5WithRSAEncryption {
			set checkdigest [md5::md5 $checkmessage]
		}
		sha1 - sha1WithRSAEncryption {
			set checkdigest [sha1::sha1 -bin $checkmessage]
		}
		sha256 - sha256WithRSAEncryption {
			set checkdigest [sha2::sha256 -bin $checkmessage]
		}
		default {
			return -code error "Unknown hashing algorithm: $algoId"
		}
	}

	if {$checkdigest ne $digest} {
		return false
	}

	return true
}


proc ::pki::key {keylist {password {}} {encodePem 1}} {
	set serialize_key [::pki::_lookup_command serialize_key $keylist]

	if {$serialize_key eq {}} {
		array set key $keylist

		return -code error "Do not know how to serialize an $key(type) key"
	}

	array set retval_parts [$serialize_key $keylist]

	if {$encodePem} {
		set retval [::pki::_encode_pem $retval_parts(data) $retval_parts(begin) \
			$retval_parts(end) $password]
	} else {
		if {$password ne {}} {
			return -code error {DER encoded keys may not be password protected}
		}

		set retval $retval_parts(data)
	}

	return $retval
}


proc ::pki::public_key {keylist {password {}} {encodePem 1}} {
	set serialize_key [::pki::_lookup_command serialize_public_key $keylist]

	if {$serialize_key eq {}} {
		array set key $keylist

		return -code error "Do not know how to serialize an $key(type) key"
	}

	array set retval_parts [$serialize_key $keylist]

	if {$encodePem} {
		set retval [::pki::_encode_pem $retval_parts(data) $retval_parts(begin) \
			$retval_parts(end) $password]
	} else {
		if {$password ne {}} {
			return -code error {DER encoded keys may not be password protected}
		}

		set retval $retval_parts(data)
	}

	return $retval
}


proc ::pki::parse {text {errorOnUnknownType 0}} {
	set rc [list]
	while {[regexp {^.*?-----BEGIN (.*?)-----(.*?)-----END (.*?)-----(.*)$} \
		$text - type body type2 text]} {

		if {$type != $type2} {
			return -code error "BEGIN and END types do not match ($type and $type2)"
		}
		set body "-----BEGIN $type-----\n$body\n-----END $type-----\n"

		switch -- $type {
			{RSA PRIVATE KEY} {
				lappend rc key [::pki::pkcs::parse_key $body]
			}
			{PUBLIC KEY} {
				lappend rc public_key [::pki::pkcs::parse_public_key $body]
			}
			CERTIFICATE {
				lappend rc certificate [::pki::x509::parse_cert $body]
			}
			{CERTIFICATE REQUEST} {
				lappend rc certificate_request [::pki::pkcs::parse_csr $body]
			}
			default {
				if {$errorOnUnknownType} {
					return -code error "Unable to parse key with type $type"
				}
			}
		}
	}
	return $rc
}


proc ::pki::_parse_init {} {
	if {[info exists ::pki::_parse_init_done]} {
		return
	}

	package require asn

	set test FAIL
	catch {
		set test [binary decode base64 UEFTUw==]
	}

	switch -- $test {
		PASS {
			set ::pki::rsa::base64_binary 1
		}
		FAIL {
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

	set saltedkey $password$salt
	for {set ret {}} {[string length $ret] < $bytes} {} {
		if {![info exists hash]} {
			set hash $saltedkey
		} else {
			set hash $hash$saltedkey
		}

		set hash [md5::md5 $hash]

		append ret $hash
	}

	if {[string length $ret] < $bytes} {
		set bytes_to_add [expr $bytes - [string length $ret]]
		set ret [string repeat \x00 $bytes_to_add]$ret
	}

	set ret [string range $ret 0 [expr {$bytes - 1}]]
	return $ret
}


proc ::pki::_encode_pem {data begin end {password {}} {algo aes-256-cbc}} {
	set ret {} 

	append ret $begin\n
	if {$password ne {}} {
		switch -glob -- $algo {
			aes-* {
				set algostr [string toupper $algo]
				set work [split $algo -]
				set algo aes
				set keysize [lindex $work 1]
				set mode [lindex $work 2]
				set blocksize 16
				set ivsize [expr {$blocksize * 8}]
			}
			default {
				return -code error {Only AES is currently supported}
			}
		}

		set keybytesize [expr {$keysize / 8}]
		set ivbytesize [expr {$ivsize / 8}]

		set iv {} 
		while {[string length $iv] < $ivbytesize} {
			append iv [::pki::_random -binary]
		}
		set iv [string range $iv 0 [expr {$ivbytesize - 1}]]

		set password_key [::pki::_getopensslkey $password $iv $keybytesize]

		set pad [expr {$blocksize - ([string length $data] % $blocksize)}]
		append data [string repeat \x09 $pad]

		switch -- $algo {
			aes {
				set data [aes::aes -dir encrypt -mode $mode -iv $iv -key $password_key -- $data]
			}
		}

		binary scan $iv H* iv
		set iv [string toupper $iv]

		append ret "Proc-Type: 4,ENCRYPTED\n"
		append ret "DEK-Info: $algostr,$iv\n"
		append ret \n
	}

	if {$::pki::rsa::base64_binary} {
		append ret [binary encode base64 -maxlen 64 $data]
	} else {
		append ret [::base64::encode -maxlen 64 $data]
	}
	append ret \n
	append ret $end\n
	return $ret
}


proc ::pki::_parse_pem {pem begin end {password {}}} {
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
		if {[string match *:* $line]} {
			set work [split $line :]

			set var [string toupper [lindex $work 0]]
			set val [string trim [join [lrange $work 1 end] :]]

			set ret($var) $val

			continue
		}

		set line [string trim $line]

		append newpem $line
	}

	if {$newpem ne {}} {
		if {$::pki::rsa::base64_binary} {
			set pem [binary decode base64 $newpem]
		} else {
			set pem [::base64::decode $newpem]
		}
	}

	if {[info exists ret(PROC-TYPE)] && [info exists ret(DEK-INFO)]} {
		if {$ret(PROC-TYPE) eq {4,ENCRYPTED}} {
			if {$password eq {}} {
				return [list error ENCRYPTED]
			}

			switch -glob -- $ret(DEK-INFO) {
				DES-EDE3-* {
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
				AES-* {
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


proc ::pki::pkcs::parse_public_key {key {password {}}} {
	array set parsed_key [::pki::_parse_pem $key \
		{-----BEGIN PUBLIC KEY-----} {-----END PUBLIC KEY-----} $password]

	set key_seq $parsed_key(data)

	::asn::asnGetSequence key_seq pubkeyinfo
		::asn::asnGetSequence pubkeyinfo pubkey_algoid
			::asn::asnGetObjectIdentifier pubkey_algoid oid
		::asn::asnGetBitString pubkeyinfo pubkey
	set ret(pubkey_algo) [::pki::_oid_number_to_name $oid]

	switch -- $ret(pubkey_algo) {
		rsaEncryption {
			set pubkey [binary format B* $pubkey]

			::asn::asnGetSequence pubkey pubkey_parts
				::asn::asnGetBigInteger pubkey_parts ret(n)
				::asn::asnGetBigInteger pubkey_parts ret(e)

			set ret(n) [::math::bignum::tostr $ret(n)]
			set ret(e) [::math::bignum::tostr $ret(e)]
			set ret(l) [expr {int([::pki::_bits $ret(n)] / 8.0000 + 0.5) * 8}]
			set ret(type) rsa
		}
		default {
			error {Unknown algorithm}
		}
	}

	return [array get ret]
}


proc ::pki::pkcs::parse_key {key {password {}}} {
	array set parsed_key [::pki::_parse_pem $key \
		{-----BEGIN RSA PRIVATE KEY-----} {-----END RSA PRIVATE KEY-----} $password]

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


# dn expected to be concatenated RelativeDistinguishedName DER encoded values
proc ::pki::x509::_dn_to_list dn {
	set ret {} 

	while {$dn ne {}} {
		# RelativeDistinguishedName  ::=
		# SET SIZE (1 .. MAX) OF SingleAttribute { {SupportedAttributes} }
		# SingleAttribute{ATTRIBUTE:AttrSet} ::= SEQUENCE {
		# 	type      ATTRIBUTE.&id({AttrSet}),
		# 	value     ATTRIBUTE.&Type({AttrSet}{@type})
		# }
		# Assumed here that Set contains a single attribute, and the attribute
		# value is a string. This should suffice for most (all?) X.509 certs
		::asn::asnGetSet dn dn_parts
		::asn::asnGetSequence dn_parts curr_part
		::asn::asnGetObjectIdentifier curr_part label
		::asn::asnGetString curr_part value

		set label [::pki::_oid_number_to_name $label]
		lappend ret $label $value
	}

	return $ret
}


proc ::pki::x509::_list_to_dn name {
	set ret {} 
	foreach {oid_name value} $name {
		if {![regexp {[^ A-Za-z0-9'()+,.:/?=-]} $value]} {
			set asnValue [::asn::asnPrintableString $value]
		} else {
			set asnValue [::asn::asnUTF8String $value]
		}

		append ret [::asn::asnSet [
			::asn::asnSequence [
				::asn::asnObjectIdentifier [::pki::_oid_name_to_number $oid_name]
			] $asnValue ]
		]
	}

	return $ret
}


proc ::pki::x509::_dn_to_string dn {
	set ret [list]

	foreach {label value} [_dn_to_list $dn] {
		set label [string toupper $label]

		lappend ret $label=$value
	}

	set ret [join $ret {, }]

	return $ret
}


proc ::pki::x509::_string_to_dn string {
	foreach {label value} [split $string ,=] {
		set label [string trim $label]
		set value [string trim $value]

		lappend namelist $label $value
	}

	return [_list_to_dn $namelist]
}


proc ::pki::x509::_dn_to_cn dn {
	foreach {label value} [split $dn ,=] {
		set label [string toupper [string trim $label]]
		set value [string trim $value]

		if {$label eq {CN}} {
			return $value
		}
	}

	return {} 
}


proc ::pki::x509::_utctime_to_native utctime {
	return [clock scan $utctime -format %y%m%d%H%M%SZ -gmt true]
}

proc ::pki::x509::_native_to_utctime time {
	return [clock format $time -format %y%m%d%H%M%SZ -gmt true]
}

proc ::pki::x509::_generalizedtime_to_native utctime {
	return [clock scan $utctime -format %Y%m%d%H%M%SZ -gmt true]
}


proc ::pki::x509::_generalizedtime_to_utctime time {
	return [clock format $time -format %Y%m%d%H%M%SZ -gmt true]
}


proc ::pki::x509::_parse_BasicConstraints {ext_octets_var} {
	# https://www.rfc-editor.org/rfc/rfc5280#page-128
	# BasicConstraints ::= SEQUENCE {
	# 	cA                      BOOLEAN DEFAULT FALSE,
	# 	pathLenConstraint       INTEGER (0..MAX) OPTIONAL }

	upvar 1 $ext_octets_var ext_octets
	# bytes will hold actual sequence bytes without the header
	::asn::asnGetSequence ext_octets bytes

	# Both elements are effectively optional. Upper levels use CA depth of -1
	# to indicate no constraints specified
	set allowCA 0
	set caDepth -1

	if {$bytes ne {}} {
		# Check first element - if not a boolean, it is missing and should default
		::asn::asnPeekByte bytes tag
		if {$tag == 0x01} {
			::asn::asnGetBoolean bytes allowCA
		}
		# Second field if present
		if {$bytes ne {}} {
			::asn::asnGetInteger bytes caDepth
		}
		# TODO - should we raise an error if extra bytes left over?
	}


	return [list $allowCA $caDepth]
}


proc ::pki::x509::_parse_ExtKeyUsage {ext_octets_var} {
	# extKeyUsage OBJECT IDENTIFIER ::= {id-ce 37}
	# ExtKeyUsageSyntax ::= SEQUENCE SIZE (1..MAX) OF KeyPurposeId
	# KeyPurposeId ::= OBJECT IDENTIFIER
	# -- permit unspecified key uses
	# anyExtendedKeyUsage OBJECT IDENTIFIER ::= { extKeyUsage 0 }
	# -- extended key purpose OIDs
	# id-kp-serverAuth             OBJECT IDENTIFIER ::= { id-kp 1 }
	# id-kp-clientAuth             OBJECT IDENTIFIER ::= { id-kp 2 }
	# id-kp-codeSigning            OBJECT IDENTIFIER ::= { id-kp 3 }
	# id-kp-emailProtection        OBJECT IDENTIFIER ::= { id-kp 4 }
	# id-kp-ipsecEndSystem         OBJECT IDENTIFIER ::= { id-kp 5 }
	# id-kp-ipsecTunnel            OBJECT IDENTIFIER ::= { id-kp 6 }
	# id-kp-ipsecUser              OBJECT IDENTIFIER ::= { id-kp 7 }
	# id-kp-timeStamping           OBJECT IDENTIFIER ::= { id-kp 8 }
	# id-kp-OCSPSigning            OBJECT IDENTIFIER ::= { id-kp 9 }

	upvar 1 $ext_octets_var ext_octets
	::asn::asnGetSequence ext_octets bytes

	set ext_key_usage [list]
	while {$bytes ne {}} {
		::asn::asnGetObjectIdentifier bytes oid
		lappend ext_key_usage [::pki::_oid_number_to_name $oid]
	}

	return $ext_key_usage
}


proc ::pki::x509::_parse_KeyUsage {ext_octets_var} {
	# KeyUsage ::= BIT STRING {
	# 	digitalSignature        (0),
	# 	nonRepudiation          (1),  -- recent editions of X.509 have
	# 	-- renamed this bit to contentCommitment
	# 	keyEncipherment         (2),
	# 	dataEncipherment        (3),
	# 	keyAgreement            (4),
	# 	keyCertSign             (5),
	# 	cRLSign                 (6),
	# 	encipherOnly            (7),
	# 	decipherOnly            (8) }

	upvar 1 $ext_octets_var ext_octets
	::asn::asnGetBitString ext_octets bits

	scan $bits %b bits
	set tokens {
		digitalSignature nonRepudiation keyEncipherment dataEncipherment
		keyAgreement keyCertSign cRLSign encipherOnly decipherOnly
	}
	set ntokens [llength $tokens]
	set key_usage [list $bits]
	for {set i 0} {$i < $ntokens} {incr i} {
		if {$bits & (1 << $i)} {
			lappend key_usage [lindex $tokens $i]
		}
	}
	return $key_usage
}

proc ::pki::x509::_parse_GeneralName {bytes_var {with_ip_mask 0}} {
	# Returns a pair "name type" and name value
	# by parsing a GeneralName ASN.1 structure in $bytes_var. The parsed bytes
	# are removed from $bytes_var.
	# https://www.rfc-editor.org/rfc/rfc5280#page-128
	# GeneralName ::= CHOICE {
	# 	otherName                 [0]  AnotherName,
	# 	rfc822Name                [1]  IA5String,
	# 	dNSName                   [2]  IA5String,
	# 	x400Address               [3]  ORAddress,
	# 	directoryName             [4]  Name,
	# 	ediPartyName              [5]  EDIPartyName,
	# 	uniformResourceIdentifier [6]  IA5String,
	# 	iPAddress                 [7]  OCTET STRING,
	# 	registeredID              [8]  OBJECT IDENTIFIER }
	# In addition, from RFC 8398 -
	# id-on-SmtpUTF8Mailbox OBJECT IDENTIFIER ::= { id-on 9 }
	# SmtpUTF8Mailbox ::= UTF8String (SIZE (1..MAX))

	upvar 1 $bytes_var bytes

	::asn::asnPeekByte bytes tag
	# The tag is context-specific (0x80) | choice index To extract using asn
	# routines, replace the tag with the concrete primitive tag using
	# asnRetag. This is somewhat inefficient and it would have been better
	# if the asn routines took an optional "expected_tag" argument but they
	# do not, and I don't want to start hacking that module.

	# Note the name tags (rfc822name etc.) are same as those used in create_cert
	switch -exact -- [format 0x%02x $tag] {
		0xa0 {
			# AnotherName - Important because Windows uses it for WinRM to store
			# UPN format names with OID 1.3.6.1.4.1.311.20.2.3 with the value
			# as a UTF-8 encoded string. However, other OID's may not use this
			# UTF-8 forms, so we just keep the raw data in hex.
			::asn::asnGetContext bytes context_tag other_name
			# ::asn::asnRetag bytes 0x30; # Retag as SEQUENCE
			# ::asn::asnGetSequence bytes other_name
			::asn::asnGetObjectIdentifier other_name other_name_oid
			# Since interpretation is unknown, just store hex representation
			binary scan $other_name H* other_name_hex
			return [list otherName [list [::pki::_oid_number_to_dotted $other_name_oid] $other_name_hex]]
		}
		0x81 {
			::asn::asnRetag bytes 0x16;	# Retag as IA5String
			::asn::asnGetIA5String bytes name
			return [list rfc822Name $name]
		}
		0x82 {
			::asn::asnRetag bytes 0x16;	# Retag as IA5String
			::asn::asnGetIA5String bytes name
			return [list dNSName $name]
		}
		0xa3 {
			# TODO x400address - forget about parsing this for now!
			::asn::asnGetContext bytes context_tag x400addr
			# ::asn::asnRetag bytes 0x30; # Retag as SEQUENCE
			# ::asn::asnGetSequence bytes x400addr
			binary scan $x400addr H* x400addr_hex
			return [list x400Address $x400addr_hex]
		}
		0xa4 {
			::asn::asnGetContext bytes context_tag dn_bytes
			#::asn::asnRetag bytes 0x30; # Retag as SEQUENCE
			::asn::asnGetSequence dn_bytes dir_name
			return [list directoryName [_dn_to_string $dir_name]]
		}
		0xa5 {
			# EDIPartyName ::= SEQUENCE {
			# 	nameAssigner            [0]     DirectoryString OPTIONAL,
			# 	partyName               [1]     DirectoryString }
			# DirectoryString ::= CHOICE {
			# 	teletexString       TeletexString   (SIZE (1..MAX)),
			# 	printableString     PrintableString (SIZE (1..MAX)),
			# 	universalString     UniversalString (SIZE (1..MAX)),
			# 	utf8String          UTF8String      (SIZE (1..MAX)),
			# 	bmpString           BMPString       (SIZE (1..MAX)) }
			# TODO - Not too hard to implement but I'm not clear about the
			# presence of implicit tags and do not have a sample certificate
			::asn::asnRetag bytes 0x30; # Retag as SEQUENCE
			::asn::asnGetSequence bytes edi
			binary scan $edi H* edi_hex
			return [list ediPartyName $edi_hex]
		}
		0x86 {
			::asn::asnRetag bytes 0x16;	# Retag as IA5String
			::asn::asnGetIA5String bytes name
			return [list uniformResourceIdentifier $name]
		}
		0x87 {
			# IPv4/6 -> must be exactly 4/16 octets respectively in a subject
			# name but can be 8/32 in a name constraint.
			::asn::asnRetag bytes 0x04
			::asn::asnGetOctetString bytes addr
			set n [string length $addr]
			if {$n == 4} {
				binary scan $addr cu* addr
				set addr_str [join $addr .]
			} elseif {$n == 16} {
				binary scan $addr H* addr
				set addr_str [regsub -all {[[:xdigit:]]{4}(?=.)} $addr {\0:}]
			} elseif {$with_ip_mask && $n == 8} {
				binary scan $addr cu4cu* addr mask
				set addr_str [list [join $addr .] [join $mask .]]
			} elseif {$with_ip_mask && $n == 32} {
				binary scan $addr H32H32 addr mask
				set addr [regsub -all {[[:xdigit:]]{4}(?=.)} $addr {\0:}]
				set mask [regsub -all {[[:xdigit:]]{4}(?=.)} $mask {\0:}]
				set addr_str [list $addr $mask]
			} else {
				error "Invalid IP address. Has $n octets."
			}
			return [list iPAddress $addr_str]
		}
		0x88 {
			::asn::asnRetag bytes 0x06;	# Retag as OBJECT IDENTIFIER
			::asn::asnGetObjectIdentifier bytes oid
			return [list registeredID [::pki::_oid_number_to_dotted $oid]]
		}
		0x89 {
			::asn::asnRetag bytes 0x0C;	# Retag as UTF8 string
			::asn::asnGetUTF8String bytes name
			return [list uniformResourceIdentifier $name]
		}
		default {
			puts bytes:[binary encode hex $bytes]
			error "Unknown context tag [format 0x%02x $tag] encountered in parsing ASN.1 GeneralName."
		}
	}
}


proc ::pki::x509::_parse_GeneralNames {bytes_var} {
	# GeneralNames ::= SEQUENCE SIZE (1..MAX) OF GeneralName
	# https://www.rfc-editor.org/rfc/rfc5280#page-128
	# GeneralName ::= CHOICE {
	# 	otherName                 [0]  AnotherName,
	# 	rfc822Name                [1]  IA5String,
	# 	dNSName                   [2]  IA5String,
	# 	x400Address               [3]  ORAddress,
	# 	directoryName             [4]  Name,
	# 	ediPartyName              [5]  EDIPartyName,
	# 	uniformResourceIdentifier [6]  IA5String,
	# 	iPAddress                 [7]  OCTET STRING,
	# 	registeredID              [8]  OBJECT IDENTIFIER }
	# In addition, from RFC 8398 -
	# id-on-SmtpUTF8Mailbox OBJECT IDENTIFIER ::= { id-on 9 }
	# SmtpUTF8Mailbox ::= UTF8String (SIZE (1..MAX))
	upvar 1 $bytes_var bytes
	::asn::asnGetSequence bytes names_bytes

	set names [list]
	while {$names_bytes ne {}} {
		# names is a flat name type and name value list. NOT a dictionary
		# since types may be repeated.
		lappend names {*}[_parse_GeneralName names_bytes]
	}
	return $names
}


proc ::pki::x509::_parse_GeneralSubtrees {bytes_var} {
	# NOTE: bytes is content of GeneralSubtrees AFTER stripping SEQUENCE header
	# GeneralSubtrees ::= SEQUENCE SIZE (1..MAX) OF GeneralSubtree
	# GeneralSubtree ::= SEQUENCE {
	# 	base                    GeneralName,
	# 	minimum         [0]     BaseDistance DEFAULT 0,
	# 	maximum         [1]     BaseDistance OPTIONAL }
	# BaseDistance ::= INTEGER (0..MAX)

	upvar 1 $bytes_var bytes
	::asn::asnGetSequence bytes subtrees_bytes

	set subtrees [list]
	while {$subtrees_bytes ne {}} {
		::asn::asnGetSequence subtrees_bytes subtree_bytes
		set base [_parse_GeneralName subtree_bytes 1]
		set minimum 0;			# As per default in spec
		if {$subtree_bytes ne {}} {
			::asn::asnPeekByte subtree_bytes tag
			if {$tag == 0x80} {
				::asn::asnRetag subtree_bytes 0x02
				::asn::asnGetInteger subtree_bytes minimum
				# Next tag. Note NO default if not present
				if {$subtree_bytes ne {}} {
					::asn::asnPeekByte subtree_bytes tag
					::asn::asnRetag subtree_bytes 0x02
					::asn::asnGetInteger subtree_bytes maximum
				}
			}
		}
		set subtree [list base $base minimum $minimum]
		if {[info exists maximum]} {
			lappend subtree $maximum
		}
		lappend subtrees $subtree
	}

	return $subtrees
}


proc ::pki::x509::_parse_AuthorityKeyIdentifier {ext_octets_var} {
	# AuthorityKeyIdentifier ::= SEQUENCE {
	# 	keyIdentifier             [0] KeyIdentifier           OPTIONAL,
	# 	authorityCertIssuer       [1] GeneralNames            OPTIONAL,
	# 	authorityCertSerialNumber [2] CertificateSerialNumber OPTIONAL  }
	# KeyIdentifier ::= OCTET STRING

	upvar 1 $ext_octets_var ext_octets

	::asn::asnGetSequence ext_octets bytes

	# Note the fields are optional but must appear in the sequence shown.
	# TODO - should we raise an error if fields in wrong order?

	set ext_value [list]
	if {$bytes eq {}} {
		return $ext_value
	}

	# The tag is context-specific (0x80) | choice index To extract using asn
	# routines, replace the tag with the concrete primitive tag using
	# asnRetag. This is somewhat inefficient and it would have been better
	# if the asn routines took an optional "expected_tag" argument but they
	# do not, and I don't want to start hacking that module.

	::asn::asnPeekByte bytes tag
	if {$tag == 0x80} {
		::asn::asnRetag bytes 0x04; # Retag as OCTET STRING
		::asn::asnGetOctetString bytes key_identifier
		binary scan $key_identifier H* key_identifier_hex
		lappend ext_value keyIdentifier $key_identifier_hex
		if {$bytes eq {}} {
			return $ext_value
		}
		::asn::asnPeekByte bytes tag
	}

	if {$tag == 0xa1} {
		::asn::asnRetag bytes 0x30; # Retag as SEQUENCE - (GeneralNames)
		lappend ext_value \
			authorityCertIssuer [_parse_GeneralNames bytes]
		if {$bytes eq {}} {
			return $ext_value
		}
		::asn::asnPeekByte bytes tag
	}

	if {$tag == 0x82} {
		if {0} {
			This breaks because asnGetInteger cannot handle very large integers
			::asn::asnRetag bytes 0x02; # Retag as INTEGER
			::asn::asnGetInteger bytes serial
		} else {
			# TODO - add this support to asnGetInteger
			::asn::asnGetByte bytes tag
			::asn::asnGetLength bytes len
			::asn::asnGetBytes bytes $len sn_bytes
			binary scan $sn_bytes H* sn_hex
			set serial [format %lld 0x$sn_hex]
		}
		lappend ext_value authorityCertSerialNumber $serial
	}

	# TODO - are we supposed to raise an error if no fields or extra bytes?
	return $ext_value
}


proc ::pki::x509::_parse_NameConstraints {ext_octets_var} {
	# NameConstraints ::= SEQUENCE {
	# 	permittedSubtrees       [0]     GeneralSubtrees OPTIONAL,
	# 	excludedSubtrees        [1]     GeneralSubtrees OPTIONAL }

	upvar 1 $ext_octets_var ext_octets
	::asn::asnGetSequence ext_octets bytes
	set ext_value [list]
	if {$bytes eq {}} {
		return $ext_value
	}
	::asn::asnPeekByte bytes tag
	if {$tag == 0xa0} {
		::asn::asnRetag bytes 0x30;	# Tag as SEQUENCE
		lappend ext_value permittedSubtrees [_parse_GeneralSubtrees bytes]
		if {$bytes eq {}} {
			return $ext_value
		}
		::asn::asnPeekByte bytes tag
	}
	if {$tag == 0xa1} {
		::asn::asnRetag bytes 0x30;	# Tag as SEQUENCE
		lappend ext_value excludedSubtrees [_parse_GeneralSubtrees bytes]
	}
	return $ext_value
}


proc ::pki::x509::_parse_PolicyConstraints {ext_octets_var} {
	# PolicyConstraints ::= SEQUENCE {
    #     requireExplicitPolicy           [0] SkipCerts OPTIONAL,
    #     inhibitPolicyMapping            [1] SkipCerts OPTIONAL }
	# SkipCerts ::= INTEGER (0..MAX)

	upvar 1 $ext_octets_var ext_octets
	::asn::asnGetSequence ext_octets bytes
	set ext_value [list]
	if {$bytes eq {}} {
		return $ext_value
	}
	::asn::asnPeekByte bytes tag
	if {$tag == 0x80} {
		::asn::asnRetag bytes 0x02;	# Tag as INTEGER
		::asn::asnGetInteger bytes skip
		lappend ext_value requireExplicitPolicy $skip
		if {$bytes eq {}} {
			return $ext_value
		}
		::asn::asnPeekByte bytes tag
	}
	if {$tag == 0x81} {
		::asn::asnRetag bytes 0x02;	# Tag as INTEGER
		::asn::asnGetInteger bytes skip
		lappend ext_value inhibitPolicyMapping $skip
	}
	return $ext_value
}


proc ::pki::x509::_parse_UserNotice bytes_var {
	# UserNotice ::= SEQUENCE {
    #     noticeRef        NoticeReference OPTIONAL,
    #     explicitText     DisplayText OPTIONAL }
	# NoticeReference ::= SEQUENCE {
    #     organization     DisplayText,
    #     noticeNumbers    SEQUENCE OF INTEGER }
	# DisplayText ::= CHOICE {
    #     ia5String        IA5String      (SIZE (1..200)),
    #     visibleString    VisibleString  (SIZE (1..200)),
    #     bmpString        BMPString      (SIZE (1..200)),
    #     utf8String       UTF8String     (SIZE (1..200)) }

	upvar 1 $bytes_var bytes

	set user_notice [list]
	::asn::asnGetSequence bytes user_notice_bytes
	::asn::asnPeekByte user_notice_bytes tag
	if {$tag == 0x30} {
		# NoticeReference
		::asn::asnGetSequence user_notice_bytes notice_ref_bytes
		::asn::asnGetString notice_ref_bytes org
		set notice_numbers [list]
		::asn::asnGetSequence notice_ref_bytes int_seq_bytes
		while {$int_seq_bytes ne {}} {
			::asn::asnGetSequence int_seq_bytes number
			lappend notice_numbers $number
		}
		lappend user_notice noticeRef \
			[list organization $org noticeNumbers $notice_numbers]
	}
	if {$user_notice_bytes ne {}} {
		::asn::asnGetString user_notice_bytes explicit_text
		lappend user_notice explicitText $explicit_text
	}
	return $user_notice
}


proc ::pki::x509::_parse_PolicyQualifierInfo bytes_var {
	# PolicyQualifierInfo ::= SEQUENCE {
	# 	policyQualifierId  PolicyQualifierId,
	# 	qualifier          ANY DEFINED BY policyQualifierId }
	# Qualifier ::= CHOICE {
    #     cPSuri           CPSuri,
    #     userNotice       UserNotice }
	# CPSuri ::= IA5String

	upvar 1 $bytes_var bytes

	::asn::asnGetObjectIdentifier bytes qualifier_oid
	set qualifier_oid [::pki::_oid_number_to_name $qualifier_oid]
	switch -exact -- $qualifier_oid {
		cps {
			::asn::asnGetIA5String bytes value
		}
		unotice {
			set value [_parse_UserNotice bytes]
		}
		default {
			binary scan $bytes H* value
		}
	}
	return [list $qualifier_oid $value]
}


proc ::pki::x509::_parse_CertificatePolicies ext_octets_var {
	# CertificatePolicies ::= SEQUENCE SIZE (1..MAX) OF PolicyInformation
	# PolicyInformation ::= SEQUENCE {
	#    policyIdentifier CertPolicyId,
	#    policyQualifiers SEQUENCE SIZE (1..MAX) OF PolicyQualifierInfo OPTIONAL }
	# CertPolicyId ::= OBJECT IDENTIFIER

	upvar 1 $ext_octets_var ext_octets
	::asn::asnGetSequence ext_octets bytes
	set ext_value [list]
	if {$bytes eq {}} {
		return $ext_value
	}

	while {$bytes ne {}} {
		::asn::asnGetSequence bytes policy_info_bytes
		::asn::asnGetObjectIdentifier policy_info_bytes policy_oid
		set policy_oid [::pki::_oid_number_to_dotted $policy_oid]
		set policy_info [list policyIdentifier $policy_oid]
		if {$policy_info_bytes ne {}} {
			set qualifers [list]
			::asn::asnGetSequence policy_info_bytes qualifiers_bytes
			while {$qualifiers_bytes ne {}} {
				::asn::asnGetSequence qualifiers_bytes qualifier_info_bytes
				lappend qualifiers {*}[_parse_PolicyQualifierInfo qualifier_info_bytes]
			}
			lappend policy_info policyQualifiers $qualifiers
		}
		lappend ext_value $policy_info
	}

	return $ext_value
}


proc ::pki::x509::_parse_PolicyMappings {ext_octets_var} {
    # PolicyMappings ::= SEQUENCE SIZE (1..MAX) OF SEQUENCE {
    #     issuerDomainPolicy      CertPolicyId,
    #     subjectDomainPolicy     CertPolicyId }
    # CertPolicyId ::= OBJECT IDENTIFIER

    upvar 1 $ext_octets_var ext_octets
    ::asn::asnGetSequence ext_octets bytes
    set ext_value [list]
    while {$bytes ne {}} {
        ::asn::asnGetSequence bytes mapping_bytes
        ::asn::asnGetObjectIdentifier mapping_bytes issuer_policy_oid
        ::asn::asnGetObjectIdentifier mapping_bytes subject_policy_oid
        lappend ext_value \
            [::pki::_oid_number_to_dotted $issuer_policy_oid] \
            [::pki::_oid_number_to_dotted $subject_policy_oid]
    }

    return $ext_value
}


proc ::pki::x509::_parse_AccessDescriptionSequence {ext_octets_var} {
	# AuthorityInfoAccessSyntax  ::=
	# SEQUENCE SIZE (1..MAX) OF AccessDescription
	# SubjectInfoAccessSyntax  ::=
	# SEQUENCE SIZE (1..MAX) OF AccessDescription
	# AccessDescription  ::=  SEQUENCE {
	# 	accessMethod          OBJECT IDENTIFIER,
	# 	accessLocation        GeneralName  }

	upvar 1 $ext_octets_var ext_octets
	::asn::asnGetSequence ext_octets bytes
	set ext_value [list]
	while {$bytes ne {}} {
        ::asn::asnGetSequence bytes access_bytes
        ::asn::asnGetObjectIdentifier access_bytes method_oid
		set location [_parse_GeneralName access_bytes]
		lappend ext_value [list \
							   accessMethod [::pki::_oid_number_to_name $method_oid] \
							   accessLocation $location
							  ]
	}

	return $ext_value
}


proc ::pki::x509::_parse_Attribute {bytes_var} {
	# Attribute               ::= SEQUENCE {
	# 	type             AttributeType,
	# 	values    SET OF AttributeValue }
	# AttributeType           ::= OBJECT IDENTIFIER
	# AttributeValue          ::= ANY -- DEFINED BY AttributeType

	upvar 1 $bytes_var bytes
	::asn::asnGetSequence bytes seq_bytes
	::asn::asnGetObjectIdentifier seq_bytes type_oid
	::asn::asnGetSet seq_bytes values_bytes
	binary scan H* $values_bytes values_hex
	return [list type [::pki::_oid_number_to_dotted $type_oid] values $values_hex]
}


proc ::pki::x509::_parse_AttributeAndValue {bytes_var} {
	# AttributeTypeAndValue ::= SEQUENCE {
	# 	type     AttributeType,
	# 	value    AttributeValue }
	# AttributeType           ::= OBJECT IDENTIFIER
	# AttributeValue          ::= ANY -- DEFINED BY AttributeType

	upvar 1 $bytes_var bytes
	::asn::asnGetSequence bytes seq_bytes
	::asn::asnGetObjectIdentifier seq_bytes type_oid
	binary scan H* $seq_bytes value_hex
	return [list type [::pki::_oid_number_to_dotted $type_oid] value $value_hex]
}

proc ::pki::x509::_parse_SubjectDirectoryAttributes {ext_octets_var} {
	# SubjectDirectoryAttributes ::= SEQUENCE SIZE (1..MAX) OF Attribute

	upvar 1 $ext_octets_var ext_octets
	::asn::asnGetSequence ext_octets bytes

	set ext_value {}
	while {$bytes ne {}} {
		lappend ext_value [_parse_Attribute bytes]
	}

	return $ext_value
}

proc ::pki::x509::_parse_DistributionPoint {bytes_var} {
	# DistributionPoint ::= SEQUENCE {
    #     distributionPoint       [0]     DistributionPointName OPTIONAL,
    #     reasons                 [1]     ReasonFlags OPTIONAL,
    #     cRLIssuer               [2]     GeneralNames OPTIONAL }
	# DistributionPointName ::= CHOICE {
    #     fullName                [0]     GeneralNames,
    #     nameRelativeToCRLIssuer [1]     RelativeDistinguishedName }
	# ReasonFlags ::= BIT STRING {
    #     unused                  (0),
    #     keyCompromise           (1),
    #     cACompromise            (2),
    #     affiliationChanged      (3),
    #     superseded              (4),
    #     cessationOfOperation    (5),
    #     certificateHold         (6),
    #     privilegeWithdrawn      (7),
    #     aACompromise            (8) }

	upvar 1 $bytes_var bytes
	set value [list]
	::asn::asnGetSequence bytes dp_bytes
	if {$dp_bytes eq {}} {
		return $value
	}

	::asn::asnPeekByte dp_bytes tag

	# Note about tagging. Constructed encodings have the form 0xA?, primitives 0x8?
	if {$tag == 0xA0} {
		::asn::asnGetContext dp_bytes context_tag name_bytes
		::asn::asnPeekByte name_bytes name_tag
		if {$name_tag == 0xA0} {
			::asn::asnRetag name_bytes 0x30; # Retag as SEQUENCE
			lappend value distributionPoint \
				[list fullName [_parse_GeneralNames name_bytes]]
		} elseif {$name_tag == 0xA1} {
			::asn::asnRetag name_bytes 0x31; # Retag as SET (RelativeDistinguishedName)
			#::asn::asnGetSequence name_bytes rdn
			lappend value distributionPoint \
				[list nameRelativeToCRLIssuer [_dn_to_string $name_bytes]]

		}
		if {$dp_bytes eq {}} {
			return $value
		}
		::asn::asnPeekByte dp_bytes tag
	}
	if {$tag == 0x81} {
		::asn::asnRetag dp_bytes 0x03; # BITSTRING
		::asn::asnGetBitString dp_bytes bits
		scan $bits %b bits
		set tokens {
			unused keyCompromise cACompromise affiliationChanged superseded
			cessationOfOperation certificateHold privilegeWithdrawn aACompromise
		}
		set ntokens [llength $tokens]
		set reasons [list $bits]; # Keep binary bits to support unknown flags
		# Note start with i=1 since the "unused" bit is not to be checked
		for {set i 1} {$i < $ntokens} {incr i} {
			if {$bits & (1 << $i)} {
				lappend reasons [lindex $tokens $i]
			}
		}
		lappend value reasons $reasons
		if {$dp_bytes eq {}} {
			return $value
		}
		::asn::asnPeekByte dp_bytes tag
	}
	if {$tag == 0xa2} {
		# cRLIssuer
		::asn::asnRetag dp_bytes 0x30; # SEQUENCE
		lappend value cRLIssuer [_parse_GeneralNames dp_bytes]
	}
	return $value
}


proc ::pki::x509::_parse_CRLDistributionPoints {ext_octets_var} {
	# CRLDistributionPoints ::= SEQUENCE SIZE (1..MAX) OF DistributionPoint

    upvar 1 $ext_octets_var ext_octets
    ::asn::asnGetSequence ext_octets bytes
    set ext_value [list]
    while {$bytes ne {}} {
        lappend ext_value [_parse_DistributionPoint bytes]
    }

    return $ext_value
}


proc ::pki::x509::_parse_extensions {extensions extensions_list_var} {
	upvar 1 $extensions_list_var extensions_list
	# Note - do NOT init extensions_list as we are appending to whatever caller
	# has already stored there.
	while {$extensions ne {}} {
		# Each extension is itself a sequence. The first element is an OID that
		# identifies the extension. The second element is the "critical" flag.
		# This is optional and defaults to false. The third element is the
		# actual extension value encoded as an octet string.
		::asn::asnGetSequence extensions extension
		::asn::asnGetObjectIdentifier extension ext_oid
		set ext_oid [::pki::_oid_number_to_name $ext_oid]

		# Check for presence of optional "critical" flag
		::asn::asnPeekByte extension peek_tag
		if {$peek_tag == 0x1} {
			::asn::asnGetBoolean extension ext_critical
		} else {
			set ext_critical 0
		}

		# Now extract the extension value. Note the structure of the octet
		# string will depend on the OID.
		::asn::asnGetOctetString extension ext_octets

		# Parsed value of extension is the critical flag followed by zero or
		# more oid-dependent values.

		switch -exact -- $ext_oid {
			subjectAltName -
			issuerAltName {
				set ext_value [_parse_GeneralNames ext_octets]
			}
			basicConstraints {
				set ext_value [_parse_BasicConstraints ext_octets]
			}
			keyUsage {
				set ext_value [_parse_KeyUsage ext_octets]
			}
			extKeyUsage {
				set ext_value [_parse_ExtKeyUsage ext_octets]
			}
			authorityKeyIdentifier {
				set ext_value [_parse_AuthorityKeyIdentifier ext_octets]
			}
			subjectKeyIdentifier {
				::asn::asnGetOctetString ext_octets subject_key_id
				binary scan $subject_key_id H* ext_value
			}
			nameConstraints {
				set ext_value [_parse_NameConstraints ext_octets]
			}
			certificatePolicies {
				set ext_value [_parse_CertificatePolicies ext_octets]
			}
			policyMappings {
				set ext_value [_parse_PolicyMappings ext_octets]
			}
			policyConstraints {
				set ext_value [_parse_PolicyConstraints ext_octets]
			}
			inhibitAnyPolicy {
				::asn::asnGetInteger ext_octets ext_value
			}
			subjectDirectoryAttributes {
				set ext_value [_parse_SubjectDirectoryAttributes ext_octets]
			}
			freshestCRL -
			cRLDistributionPoints {
				set ext_value [_parse_CRLDistributionPoints ext_octets]
			}
			authorityInfoAccess -
			subjectInfoAccess {
				set ext_value [_parse_AccessDescriptionSequence ext_octets]
			}
			default {
				binary scan $ext_octets H* ext_value
			}
		}
		if {$ext_oid eq "basicConstraints"} {
			# TODO - backward compatibility hack This was returned in 0.1 as a
			# three element list - {critical allowCa caDepth} If backward compat
			# is not an issue, we should make it consistent with the asn.1 specs
			# and other extensions where the value is a separate structure from
			# the critical flag and not flattened into a list. For now, return
			# both forms.
			lappend extensions_list id-ce-basicConstraints [list $ext_critical {*}$ext_value]
			# Note we also add the new form of basicConstraints below
		}
		lappend extensions_list $ext_oid [list $ext_critical $ext_value]
	}
	return
}

proc ::pki::x509::parse_cert {cert} {
	array set parsed_cert [::pki::_parse_pem $cert \
		{-----BEGIN CERTIFICATE-----} {-----END CERTIFICATE-----}]
	set cert_seq $parsed_cert(data)

	array set ret [list]

	# Include the raw certificate
	set ret(raw) $cert
	binary scan $ret(raw) H* ret(raw)

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
		::asn::asnPeekByte validity peek_tag
	if {$peek_tag == 0x18} {
		::asn::asnGetGeneralizedTime validity ret(notBefore)
		set ret(notBefore) [::pki::x509::_generalizedtime_to_native $ret(notBefore)]
	} else {
		# 0x17
		::asn::asnGetUTCTime validity ret(notBefore)
		set ret(notBefore) [::pki::x509::_utctime_to_native $ret(notBefore)]
	}
	if {$peek_tag == 0x18} {
		::asn::asnGetGeneralizedTime validity ret(notAfter)
		set ret(notAfter) [::pki::x509::_generalizedtime_to_native $ret(notAfter)]
	} else {
		# 0x17
		::asn::asnGetUTCTime validity ret(notAfter)
		set ret(notAfter) [::pki::x509::_utctime_to_native $ret(notAfter)]
	}
	::asn::asnGetSequence cert subject
	::asn::asnGetSequence cert pubkeyinfo
		::asn::asnGetSequence pubkeyinfo pubkey_algoid
			::asn::asnGetObjectIdentifier pubkey_algoid ret(pubkey_algo)
		::asn::asnGetBitString pubkeyinfo pubkey

	set extensions_list [list]
	# TODO - this loop seems incorrect to me. The order should be fixed and
	# out-of-order should be an error. Moreover, duplicates should not be allowed.
	while {$cert ne {}} {
		::asn::asnPeekByte cert peek_tag

		switch -- [format 0x%02x $peek_tag] {
			0xa1 {
				# TODO - where is this returned?
				::asn::asnGetContext cert - issuerUniqID
			}
			0xa2 {
				# TODO - where is this returned?
				::asn::asnGetContext cert - subjectUniqID
			}
			0xa3 {
				::asn::asnGetContext cert - extensions_ctx
				::asn::asnGetSequence extensions_ctx extensions
				_parse_extensions $extensions extensions_list
			}
		}
	}
	# TODO - are duplicated extensions allowed? See RFC 5280 - section 4.2.
	set ret(extensions) $extensions_list

	::asn::asnGetSequence wholething signature_algo_seq
	::asn::asnGetObjectIdentifier signature_algo_seq ret(signature_algo)
	::asn::asnGetBitString wholething ret(signature)

	# Convert values from ASN.1 decoder to usable values if needed
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
		rsaEncryption {
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
	set {ignore time} 0
	# Verify arguments and load options
	for {set idx 0} {$idx < [llength $args]} {incr idx} {
		set arg [lindex $args $idx]

		switch -- $arg {
			-ignoretime {
				set {ignore time} true
			}
			-sign_message {
				incr idx
				set dn [lindex $args $idx]
				set cn [_dn_to_cn $dn]

				set opts(sign_message) $cn
			}
			-encrypt_message {
				incr idx
				set dn [lindex $args $idx]
				set cn [_dn_to_cn $dn]

				set opts(encrypt_message) $cn
			}
			-sign_cert {
				incr idx
				set dn [lindex $args $idx]
				if {$dn eq {ALL} || $dn eq {ANY}} {
					set cn $dn
				} else {
					set cn [_dn_to_cn $dn]
				}

				incr idx
				set currdepth [lindex $args $idx]

				set opts(sign_cert) [list $cn $currdepth]
			}
			-ssl {
				incr idx
				set dn [lindex $args $idx]
				set cn [_dn_to_cn $dn]

				set opts(ssl) $cn
			}
			default {
				return -code error {wrong # args: should be \
					"validate_cert cert ?-sign_message dn_of_signer?\
						?-encrypt_message dn_of_signer? ?-sign_cert\
						[dn_to_be_signed | ANY | ALL] ca_depth? ?-ssl dn?"}
			}
		}
	}

	# Load cert
	array set cert_arr $cert
	# Validate certificate

	if {!${ignore time}} {
		## Validate times
		if {![info exists cert_arr(notBefore)]
			|| ![info exists cert_arr(notAfter)]
		} {
			return false
		}

		set currtime [clock seconds]
		if {$currtime < $cert_arr(notBefore) || $currtime > $cert_arr(notAfter)} {
			return false
		}
	}

    # Check for extensions and process them. However v1 certs have no extensions
	if {$cert_arr(version) == 0} {
		# Do not permit V1 certificates for signing.
		set CA 0
	} else {
		## Critical extensions must be understood, non-critical extensions may be ignored if not understood
		set CA 0
		set CAdepth -1
		foreach {ext_id ext_val} $cert_arr(extensions) {
			set critical [lindex $ext_val 0]

			switch -- $ext_id {
				basicConstraints {
					set CA [lindex $ext_val 1 0]
					set CAdepth [lindex $ext_val 1 1]
				}
				default {
					### If this extensions is critical and not understood, we must reject it
					if {$critical} {
						return false
					}
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


proc ::pki::x509::verify_cert {cert trustedcerts args} {
	if {[llength $args] % 2 == 1} {
		set args [lassign $args[set args {}] intermediatecerts]
	} else {
		set intermediatecerts {}
	}

	set {validate args} {}

	foreach {key val} $args[set args {}] {
		switch $key {
			{validate args} {
				set {validate args} $val
			}
			default {
				return -code error [list {unknown agument} $key]
			}
			
		}
	}

	# Validate cert
	if {![eval validate_cert [list $cert] ${validate args}]} {
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
proc ::pki::pkcs::create_csr {keylist namelist {encodePem 0} {algo sha1}} {
	array set key $keylist

	set name [::pki::x509::_list_to_dn $namelist]

	set type $key(type)

	switch -- $type {
		rsa {
			set pubkey [::asn::asnSequence [
				::asn::asnBigInteger [
					::math::bignum::fromstr $key(n)
				]
			] [
				::asn::asnBigInteger [::math::bignum::fromstr $key(e)]
			]]
			set pubkey_algo_params [::asn::asnNull]
		}
	}
	binary scan $pubkey B* pubkey_bitstring

	set cert_req_info [::asn::asnSequence [
		::asn::asnInteger 0] [
			::asn::asnSequence $name
		] [
			::asn::asnSequence [
				::asn::asnSequence [
					::asn::asnObjectIdentifier [
						::pki::_oid_name_to_number ${type}Encryption]
				] $pubkey_algo_params 
			] [
				::asn::asnBitString $pubkey_bitstring
			]] [
			::asn::asnContextConstr 0 {} 
		]
	]

	set signature [::pki::sign $cert_req_info $keylist $algo]
	binary scan $signature B* signature_bitstring
	
	set cert_req [::asn::asnSequence $cert_req_info [
		::asn::asnSequence [
			::asn::asnObjectIdentifier [
				::pki::_oid_name_to_number ${algo}With${type}Encryption
			]
		] [::asn::asnNull]
	] [
		::asn::asnBitString $signature_bitstring
	]]

	if {$encodePem} {
		set cert_req [::pki::_encode_pem $cert_req \
			{-----BEGIN CERTIFICATE REQUEST-----} {-----END CERTIFICATE REQUEST-----}]
	}

	return $cert_req
}


# Parse a PKCS#10 CSR
proc ::pki::pkcs::parse_csr csr {
	# RFC 2986
	# CertificationRequestInfo ::= SEQUENCE {
    #     version       INTEGER { v1(0) } (v1,...),
    #     subject       Name,
    #     subjectPKInfo SubjectPublicKeyInfo{{ PKInfoAlgorithms }},
    #     attributes    [0] Attributes{{ CRIAttributes }}
	# }
	# Attributes { ATTRIBUTE:IOSet } ::= SET OF Attribute{{ IOSet }}
	array set ret [list]

	array set parsed_csr [::pki::_parse_pem $csr \
		{-----BEGIN CERTIFICATE REQUEST-----} {-----END CERTIFICATE REQUEST-----}]
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

	# At this point cert_req_info contains attributes if any
	while {$cert_req_info ne {}} {
		::asn::asnGetByte cert_req_info tag
		::asn::asnGetLength cert_req_info len
		::asn::asnGetBytes cert_req_info $len attrs_bytes
		if {$tag == 0xa0} {
			# attr_bytes contains set of attributes without the set header
			# Each attribute is a sequence of 2 elems - OID and a SET of values
			while {$attrs_bytes ne {}} {
				::asn::asnGetSequence attrs_bytes attr_seq
				::asn::asnGetObjectIdentifier attr_seq attr_oid
				::asn::asnGetSet attr_seq attr_value_set
				set attr_oid [::pki::_oid_number_to_name $attr_oid]
				if {$attr_oid eq "extensionRequest"} {
					::asn::asnGetSequence attr_value_set ext_req_seq
					set ext_list {}
					::pki::x509::_parse_extensions $ext_req_seq ext_list
				} else {
					# TODO - what else can be here. Should we add it in hex?
				}
			}
		} else {
			# TODO - nothing else defined in RFC2986. Skipping but should
			# we return the tag and attr_bytes in hex?
		}
	}

	if {[info exists ext_list]} {
		set ret(extensionRequest) $ext_list
	}

	# Convert parsed fields to native types
	set signature [binary format B* $signature_bitstring]
	set ret(subject) [::pki::x509::_dn_to_string $name]

	## Convert Pubkey type to string
	set pubkey_type [::pki::_oid_number_to_name $pubkey_type]

	# Parse public key, based on type
	switch -- $pubkey_type {
		rsaEncryption {
			set pubkey [binary format B* $pubkey]

			::asn::asnGetSequence pubkey pubkey_parts
			::asn::asnGetBigInteger pubkey_parts key(n)
			::asn::asnGetBigInteger pubkey_parts key(e)

			set key(n) [::math::bignum::tostr $key(n)]
			set key(e) [::math::bignum::tostr $key(e)]
			set key(l) [expr {2 ** int(ceil(log([::pki::_bits $key(n)])/log(2)))}]
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
		return -code error {CSR Signature check failed}
	}

	array set ret $keylist

	return [array get ret]
}


proc ::pki::x509::create_cert {
	signreqlist cakeylist serial_number notBefore notAfter isCA extensions
	{encodePem 0} {algo sha1}
} {
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
		set extensions(basicConstraints) [list true true -1]
	}

	# Determine what version we need to use (default to 1)
	if {[array get extensions] eq {}} {
		set version 1
	} else {
		set version 3
	}

	set certlist [list]

	# Create certificate to be signed
	## Insert version number (if not version 1)
	if {$version != 1} {
		lappend certlist [::asn::asnContextConstr 0 [
			::asn::asnInteger [expr {$version - 1}]]]
	}

	## Insert serial number
	lappend certlist [::asn::asnBigInteger [math::bignum::fromstr $serial_number]]

	## Insert data algorithm
	switch -glob -- $algo {
		*With*Encryption {
			# Already fully qualified, add nothing
			regexp {^.*With(.*)Encryption$} $algo -> type
			regexp {^(.*)With(.*)Encryption$} $algo -> hashingAlgorithm type

			set hashingAlgorithm [string tolower $hashingAlgorithm]
			set type [string tolower $type]
		}
		default {
			set hashingAlgorithm $algo

			set algo ${algo}With${type}Encryption
		}
	}

	lappend certlist [::asn::asnSequence [
		::asn::asnObjectIdentifier [::pki::_oid_name_to_number $algo]] [
			::asn::asnNull
		]
	]

	## Insert issuer
	lappend certlist [::asn::asnSequence [::pki::x509::_string_to_dn $cakey(subject)]]

	## Insert validity requirements
	lappend certlist [::asn::asnSequence [
		::asn::asnUTCTime [
			::pki::x509::_native_to_utctime $notBefore]
		] [
			::asn::asnUTCTime [::pki::x509::_native_to_utctime $notAfter
		]]
	]

	## Insert subject
	lappend certlist [::asn::asnSequence [::pki::x509::_string_to_dn $signreq(subject)]]

	## Insert public key information
	switch -- $type {
		rsa {
			set pubkey [::asn::asnSequence [
				::asn::asnBigInteger [
					::math::bignum::fromstr $signreq(n)]
			] [
				::asn::asnBigInteger [::math::bignum::fromstr $signreq(e)]
			]]

			set pubkey_algo_params [::asn::asnNull]
		}
	}
	binary scan $pubkey B* pubkey_bitstring

	lappend certlist [::asn::asnSequence [
		::asn::asnSequence [
			::asn::asnObjectIdentifier [
				::pki::_oid_name_to_number ${type}Encryption
			]
		] $pubkey_algo_params ] [
			::asn::asnBitString $pubkey_bitstring
		]
	]

	## Insert extensions
	if {[array get extensions] ne {}} {
		set extensionslist [list]

		foreach {extension extvalue} [array get extensions] {
			set critical 0

			switch -- $extension {
				id-ce-basicConstraints -
				basicConstraints {
					set critical [lindex $extvalue 0]
					set allowCA [lindex $extvalue 1]
					set caDepth [lindex $extvalue 2]

					if {$caDepth < 0} {
						set extvalue [::asn::asnSequence [::asn::asnBoolean $allowCA]]
					} else {
						set extvalue [::asn::asnSequence [
							::asn::asnBoolean $allowCA
						] [
							::asn::asnInteger $caDepth
						]]
					}
				}

				id-ce-subjectAltName -
				subjectAltName {
					set critical [lindex $extvalue 0]
	
					unset -nocomplain altnames

					foreach {altnametype altnamevalue} [lrange $extvalue 1 end] {
						switch -- [string tolower $altnametype] {
							rfc822Name -
							rfc822name {
								lappend altnames [::asn::asnChoice 1 $altnamevalue]
							}
							dNSName -
							dnsname {
								lappend altnames [::asn::asnChoice 2 $altnamevalue]
							}
							default {
								# TODO - add other alternate name types
								return -code error "Unknown subjectAltName type: $altnametype"
							}
						}
					}

					set extvalue [::asn::asnSequence {*}$altnames]
				}

				id-ce-cRLDistributionPoints -
				cRLDistributionPoints {
					set critical [lindex $extvalue 0]

					set crlDistributionPoint_objects [list distributionPoint reasons cRLIssuer]
					set crlDistributionPointsASN [list]

					foreach crlDistributionPoint_dict [lrange $extvalue 1 end] {
						set crlDistributionPoint_objectASN [list]
						set crlSequenceIdx -1

						foreach crlDistributionPoint_objectName $crlDistributionPoint_objects {
							unset -nocomplain crlDistributionPointASN
							incr crlSequenceIdx

							if {![dict exists $crlDistributionPoint_dict $crlDistributionPoint_objectName]} {
								continue
							}

							set crlDistributionPoint_object [dict get $crlDistributionPoint_dict $crlDistributionPoint_objectName]

							switch -- $crlDistributionPoint_objectName {
								distributionPoint {
									foreach {crlDistributionPointNameType crlDistributionPointName_dict} $crlDistributionPoint_object {
										switch -- $crlDistributionPointNameType {
											name {
												unset -nocomplain crlDistributionPointName
												array set crlDistributionPointName $crlDistributionPointName_dict

												switch -- $crlDistributionPointName(type) {
													url {
														set crlDistributionPointNameASN [::asn::asnChoice 6 $crlDistributionPointName(value)]
													}
													default {
														return -code error "Unsupported crlDistributionPointName choice: $crlDistributionPointName(type)"
													}
												}
												set crlDistributionPointASN [::asn::asnContextConstr 0 $crlDistributionPointNameASN]
											}
											default {
												return -code error "Unsupported crlDistributionPointNameType: $crlDistributionPointNameType"
											}
										}
									}
								}
								default {
									return -code error "Unsupported crlDistributionPoint option: $crlDistributionPoint_objectName"
								}
							}

							lappend crlDistributionPoint_objectASN [::asn::asnContextConstr $crlSequenceIdx $crlDistributionPointASN]
						}
						lappend crlDistributionPointsASN [::asn::asnSequenceFromList $crlDistributionPoint_objectASN]
					}

					set extvalue [::asn::asnSequenceFromList $crlDistributionPointsASN]
				}

				id-ce-keyUsage -
				keyUsage {
					set critical [lindex $extvalue 0]
					set extvalue [string tolower [lrange $extvalue 1 end]]

					set keyUsages [string tolower [list digitalSignature nonRepudiation keyEncipherment dataEncipherment keyAgreement keyCertSign cRLSign encipherOnly decipherOnly]]

					foreach keyUsage $extvalue {
						if {$keyUsage ni $keyUsages} {
							return -code error "Invalid key usage: $keyUsage"
						}
					}

					set keyUsageValue {}
					foreach keyUsage $keyUsages {
						if {$keyUsage in $extvalue} {
							set keyUsageResult 1
						} else {
							set keyUsageResult 0
						}
						append keyUsageValue $keyUsageResult
					}

					set extvalue [::asn::asnBitString $keyUsageValue]
				}

				default {
					return -code error "Unknown extension: $extension"
				}
			}

			lappend extensionslist [::asn::asnSequence [
				::asn::asnObjectIdentifier [
					::pki::_oid_name_to_number $extension]
				] [
					::asn::asnBoolean $critical] [
						::asn::asnOctetString $extvalue
				]
			]
		}

		lappend certlist [::asn::asnContextConstr 3 [
			::asn::asnSequenceFromList $extensionslist]]
	}

	## Enclose certificate data in an ASN.1 sequence
	set cert [::asn::asnSequenceFromList $certlist]

	# Sign certificate request using CA
	set signature [::pki::sign $cert $cakeylist $hashingAlgorithm]
	binary scan $signature B* signature_bitstring

	set cert [::asn::asnSequence $cert [
		::asn::asnSequence [
			::asn::asnObjectIdentifier [
				::pki::_oid_name_to_number $algo]
			] [
				::asn::asnNull
			]
		] [
			::asn::asnBitString $signature_bitstring
		]
	]

	if {$encodePem} {
		set cert [::pki::_encode_pem $cert \
			{-----BEGIN CERTIFICATE-----} {-----END CERTIFICATE-----}]
	}

	return $cert
}


proc ::pki::_bits num {
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
	if {[lindex $args 0] eq {-binary}} {
		set outputmode binary
	} else {
		set outputmode numeric
	}

	if {![info exists ::pki::_random_dev]} {
		foreach trydev [list /dev/urandom /dev/random __RAND__] {
			if {$trydev ne {__RAND__}} {
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

	set dev $::pki::_random_dev

	switch -- $dev {
		__RAND__ {
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
		numeric {
			# Do nothing, results are already numeric
		}
		binary {
			set ret [binary format H* [format %02llx $ret]]
		}
	}

	return $ret
}


proc ::pki::_isprime n {
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
	for {} 1 {incr di $e} {
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
			set n [expr {$p * $q}]
			set nlen [::pki::_bits $n]

			unset n

			if {$nlen == $bitlength} {
				unset nlen

				break
                        }
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

## Fill in missing ASN.1 routines

if {1 || [info commands ::asn::asnGetT61String] eq ""} {
	namespace eval ::asn {}
	proc asn::asnGetT61String {data_var print_var} {
		# This is NOT a fully conforming T.61 decoder. See caveats below.
		# The result may be used for display purposes etc. but not for validation.
		# RFC 5280 bans the use for the latter purpose anyways.
		upvar 1 $data_var data $print_var print
		asnGetByte data tag
		if {$tag != 0x14} {
			return -code error \
				[format "Expected T.61 String (0x14), but got %02x" $tag]  
		}
		asnGetLength data length
		asnGetBytes data $length t61
		#
		# Conversion : https://www.compart.com/en/unicode/charsets/T.61-8bit
		# - All characters in ascii range 0-0x7f are passed through. T.61 does
		# not use/define all control characters and even some printables like {, }
		# but we pass them through anyways.
		# - Certain 8-bit character within a certain range map to Unicode
		# equivalents but with a few gaps and exceptions
		# - T.61 encodes diacritics as the diacritic followed by the base
		# character. These are encoded as the *decomposed* Unicode character
		# consisting of the base character followed by the diacritic
		# (i.e reversed order from T.61). Encoding as precomposed would need
		# to be table-driven. As an aside, I do not think the Tcl encoding system
		# can deal with the reordering required.
		# - Everything else result in an error because interpretation of
		# remaining bytes is not implemented.
		binary scan $t61 cu* t61_bytes
		set string ""
		for {set n [llength $t61_bytes]; set i 0} {$i < $n} {incr i} {
			set ord [lindex $t61_bytes $i]
			if {$ord < 0x80} {
				# 0-0x7f Primary control and graphic characters (basically
				# ascii) but with some unused passed through
				append string [format %c $ord]
			} elseif {$ord < 0xa0} {
				# 0x80-0x9f - supplementary control. Could map directly to Unicode
				# except CSI (0x9b) which is a variable length control sequence
				# that we do not want to parse.
				if {$ord == 0x9b} {
					error "T.61 control character ([format 0x%02x]) encountered."
				}
				append string [format %c $ord]
			} elseif {$ord < 0xc1} {
				# 0xa1-0xbf - Supplementary graphics characters or unused. Map
				# directly to Unicode with some exceptions.
				if {$ord == 0xa4} {
					append string \$
				} elseif {$od == 0xa6} {
					append string #
				} elseif {$od == 0xa8} {
					append string \u00a4
				} elseif {$od == 0xb4} {
					append string \u00d7
				} elseif {$od == 0xb8} {
					append string \u00f7
				} else {
					append string [format %c $ord]
				}
			} elseif {$ord < 0xd0} {
				# 0xc1-0xcf - diacritic leaders.
				set diacritic [dict get {
					c1 \u0300 c2 \u0301 c3 \u0302 c4 \u0303 c5 \u0304 c6 \u0306
					c7 \u0307 c8 \u0308 c9 \u0308 ca \u030a cb \u0327 cc \u0332
					cd \u030b ce \u0328 cf \u030c
				} [format %02x $ord]]

				# In unicode form, the diacritic
				# follows the base character. So we need to fetch the next T.61
				# character.
				incr i
				if {$i >= $n} {
					error "Composing diacritic ([format %02x $ord]) not followed by a character."
				}
				set ord [lindex $t61_bytes $i]
				# TODO - do we need to check that the following character is valid?
				# If so, how?
				# TODO - Normalise diacritic and base into a single composed character
				append string [format %c $ord] $diacritic
			} elseif {$ord < 0xe0} {
				# Undefined. Replace with ?. Should we generate an error?
				append string ?
			} else {
				# Final set of supplementary graphics 
				# TODO - e5 and ff are undefined. We replace with ?. Should we
				# generate an error?
				append string [dict get {
					e0 \u2126 e1 \u00c6 e2 \u00d0 e3 \u00aa e4 \u0126 e5 ?
					e6 \u0132 e7 \u013f e8 \u0141 e9 \u00d8 ea \u0152 eb \u00ba
					ec \u00de ed \u0166 ee \u014a ef \u0149 f0 \u0138 f1 \u00e6
					f2 \u0111 f3 \u00f0 f4 \u0127 f5 \u0131 f6 \u0133 f7 \u0140
					f8 \u0142 f9 \u00f8 fa \u0153 fb \u00df fc \u00fe fd \u0167
					fe \u014b ff ?
				} [format %02x $ord]]
			}
		}

		# Now that we completed without errors, we can set the output variable
		set print $string
		return
	}
}



if {[info commands ::asn::asnGetGeneralizedTime] eq ""} {
	namespace eval ::asn {}
	# TODO - asnGeneralizedTime
	proc asn::asnGetGeneralizedTime {data_var utc_var} {
		upvar 1 $data_var data $utc_var utc

		asnGetByte data tag
		if {$tag != 0x18} {
			return -code error \
				[format "Expected GeneralizedTime (0x18), but got %02x" $tag]
		}

		asnGetLength data length
		asnGetBytes data $length bytes

		# this should be ascii, make it explicit
		# TODO: support fractional seconds though not required for X.509
		set bytes [encoding convertfrom ascii $bytes]
		binary scan $bytes a* utc

		return
	}
}

if {[info commands ::asn::asnGeneralizedTime] eq ""} {
	namespace eval ::asn {}
	proc asn::asnGeneralizedTime {UTCtimestring} {
		# the generalized time tag is 0x18.
		# 
		# TODO: check the string for well formedness
		# TODO: accept clock seconds as well as an integer
		# TODO: support fractional seconds though not required for X.509
		# which does not permit them.

		set ascii [encoding convertto ascii $UTCtimestring]
		set len [string length $ascii]
		return [binary format H2a*a* 18 [asnLength $len] $ascii]
	}
}

if {[info commands ::asn::asnGetVisibleString] eq ""} {
	namespace eval ::asn {}
	proc asn::asnGetVisibleString {data_var string_var} {
		upvar 1 $data_var data $string_var str
		asnGetByte data tag
		if {$tag != 0x1a} {
			return -code error \
				[format "Expected VisisbleString (0x1a), but got %02x" $tag]  
		}
		asnGetLength data length
		asnGetBytes data $length bytes
		set str [encoding convertfrom ascii $bytes]
		# TODO: Supposed to be printable ascii only. Should we check and error out?
		return
	}
}

## Initialize parsing routines, which may load additional packages (base64)
::pki::_parse_init

# # ## ### ##### ######## #############
## Ready

package provide pki 0.20
