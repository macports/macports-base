# desjr.tcl
# $Revision: 1.1 $
# $Date: 2005/09/26 09:16:59 $
#
# Port of Javascript implementation to Tcl 8.4 by Mac A. Cody,
# 3DES functionality removed, February, 2003
# July, 2003   - Separated key set generation from encryption/decryption.
#                Renamed "des" procedure to "block" to differentiate from the
#                "stream" procedure used for CFB and OFB modes.
#                Modified the "encrypt" and "decrypt" procedures to support
#                CFB and OFB modes. Changed the procedure arguments.
# August, 2003 - Added the "stream" procedure to support CFB and OFB modes.
# June, 2004 - Corrected input vector bug in stream-mode processing.  Added
#              support for feedback vector storage and management function.
#              This enables a stream of data to be processed over several calls
#              to the encryptor or decryptor.
# September, 2004 - Added feedback vector to the CBC mode of operation to allow
#                   a large data set to be processed over several calls to the
#                   encryptor or decryptor.
# October, 2004 - Added test for weak keys in the createKeys procedure.
#
# Paul Tero, July 2001
# http://www.shopable.co.uk/des.html
#
# Optimised for performance with large blocks by Michael Hayworth,
# November 2001, http://www.netdealing.com
#
# This software is copyrighted (c) 2003, 2004 by Mac A. Cody.  All rights
# reserved.  The following terms apply to all files associated with
# the software unless explicitly disclaimed in individual files or
# directories.

# The authors hereby grant permission to use, copy, modify, distribute,
# and license this software for any purpose, provided that existing
# copyright notices are retained in all copies and that this notice is
# included verbatim in any distributions. No written agreement, license,
# or royalty fee is required for any of the authorized uses.
# Modifications to this software may be copyrighted by their authors and
# need not follow the licensing terms described here, provided that the
# new terms are clearly indicated on the first page of each file where
# they apply.

# IN NO EVENT SHALL THE AUTHORS OR DISTRIBUTORS BE LIABLE TO ANY PARTY
# FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
# ARISING OUT OF THE USE OF THIS SOFTWARE, ITS DOCUMENTATION, OR ANY
# DERIVATIVES THEREOF, EVEN IF THE AUTHORS HAVE BEEN ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

# THE AUTHORS AND DISTRIBUTORS SPECIFICALLY DISCLAIM ANY WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.  THIS SOFTWARE
# IS PROVIDED ON AN "AS IS" BASIS, AND THE AUTHORS AND DISTRIBUTORS HAVE
# NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
# MODIFICATIONS.

# GOVERNMENT USE: If you are acquiring this software on behalf of the
# U.S. government, the Government shall have only "Restricted Rights"
# in the software and related documentation as defined in the Federal 
# Acquisition Regulations (FARs) in Clause 52.227.19 (c) (2).  If you
# are acquiring the software on behalf of the Department of Defense, the
# software shall be classified as "Commercial Computer Software" and the
# Government shall have only "Restricted Rights" as defined in Clause
# 252.227-7013 (c) (1) of DFARs.  Notwithstanding the foregoing, the
# authors grant the U.S. Government and others acting in its behalf
# permission to use and distribute the software in accordance with the
# terms specified in this license. 
namespace eval des {
    variable keysets
    set keysets(ndx) 1
    # Produre: keyset - Create or destroy a keyset created
    #                   from a 64-bit DES key.
    # Inputs:
    #   oper  : The operation to be performed.  This will be either "create"
    #           (make a new keyset) or "destroy" (delete an existing keyset).
    #           The meaning of the argument "value" depends of the operation
    #           performed.  An error is generated if "oper" is not "create"
    #           or "destroy".
    #             
    #   value : If the argument "oper" is "create", then "value" is the 64-bit
    #           DES key.  (Note: The lsb of each byte is ignored; odd parity is
    #           not required).  If the argument "oper" is "destroy", then
    #           "value" is a handle to a keyset that was created previously.
    #
    #   weak:   If true then weak keys are allowed. The default is to raise an
    #           error when a weak key is seen.
    # Output:
    #   If the argument "oper" is "create", then the output is a handle to the
    #   keyset stored in the des namespace.  If the argument "oper" is
    #   "destroy", then nothing is returned.
    proc keyset {oper value {weak 0}} {
	variable keysets
	set newset {}
	switch -exact -- $oper {
	    create {
		# Create a new keyset handle.
		set newset keyset$keysets(ndx)
		# Create key set
		set keysets($newset) [createKeys $value $weak]
		# Never use that keyset handle index again.
		incr keysets(ndx)
	    }
	    destroy {
		# Determine if the keyset handle is valid.
		if {[array names keysets $value] != {}} {
		    # Delete the handle and corresponding keyset.
                    unset keysets($value)
		} else {
		    error "The keyset handle \"$value\" is invalid!"
		}
	    }
	    default {
		error {The operator must be either "create" or "destroy".}
	    }
	}
	return $newset
    }

    # Procedure: encrypt - Encryption front-end for the des procedure
    # Inputs:
    #   keyset  : Handle to an existing keyset.
    #   message : String to be encrypted.
    #   mode    : DES mode ecb (default), cbc, cfb, or ofb.
    #   iv      : Name of the initialization vector used in CBC, CFB,
    #             and OFB modes.
    #   kbits   : Number of bits in a data block (default of 64).
    # Output:
    #   The encrypted data string.
    proc encrypt {keyset message {mode ecb} {iv {}} {kbits 64}} {
	switch -exact -- $mode {
	    ecb {
		return [block $keyset $message 1 0]
	    }
	    cbc -
	    ofb -
	    cfb {
		# Is the initialization/feedback vector variable is valid?
		if {[string length $iv] == 0} {
		    error "An initialization variable must be specified."
		} else {
		    upvar $iv ivec
		    if {![info exists ivec]} {
			error "The variable $iv does not exist."
		    }
		}
		switch -exact -- $mode {
		    cbc {
			return [block $keyset $message 1 1 ivec]
		    }
		    ofb {
			return [stream $keyset $message 1 0 ivec $kbits]
		    }
		    cfb {
			return [stream $keyset $message 1 1 ivec $kbits]
		    }
		}
	    }
	    default {
		error {Mode must be ecb, cbc, cfb, or ofb.}
	    }
	}
    }

    # Procedure: decrypt - Decryption front-end for the des procedure
    # Inputs:
    #   keyset  : Handle to an existing keyset.
    #   message : String to be decrypted.
    #   mode    : DES mode ecb (default), cbc, cfb, or ofb.
    #   iv      : Name of the initialization vector used in CBC, CFB,
    #             and OFB modes.
    #   kbits   : Number of bits in a data block (default of 64).
    # Output:
    #   The encrypted or decrypted data string.
    proc decrypt {keyset message {mode ecb} {iv {}} {kbits 64}} {
	switch -exact -- $mode {
	    ecb {
		return [block $keyset $message 0 0]
	    }
	    cbc -
	    ofb -
	    cfb {
		# Is the initialization/feedback vector variable is valid?
		if {[string length $iv] < 1} {
		    error "An initialization variable must be specified."
		} else {
		    upvar $iv ivec
		    if {![info exists ivec]} {
			error "The variable $iv does not exist."
		    }
		}
		switch -exact -- $mode {
		    cbc {
			return [block $keyset $message 0 1 ivec]
		    }
		    ofb {
			return [stream $keyset $message 0 0 ivec $kbits]
		    }
		    cfb {
			return [stream $keyset $message 0 1 ivec $kbits]
		    }
		}
	    }
	    default {
		error {Mode must be ecb, cbc, cfb, or ofb.}
	    }
	}
    }

    variable spfunction1 [list 0x1010400 0 0x10000 0x1010404 0x1010004 0x10404 0x4 0x10000 0x400 0x1010400 0x1010404 0x400 0x1000404 0x1010004 0x1000000 0x4 0x404 0x1000400 0x1000400 0x10400 0x10400 0x1010000 0x1010000 0x1000404 0x10004 0x1000004 0x1000004 0x10004 0 0x404 0x10404 0x1000000 0x10000 0x1010404 0x4 0x1010000 0x1010400 0x1000000 0x1000000 0x400 0x1010004 0x10000 0x10400 0x1000004 0x400 0x4 0x1000404 0x10404 0x1010404 0x10004 0x1010000 0x1000404 0x1000004 0x404 0x10404 0x1010400 0x404 0x1000400 0x1000400 0 0x10004 0x10400 0 0x1010004];
    variable spfunction2 [list 0x80108020 0x80008000 0x8000 0x108020 0x100000 0x20 0x80100020 0x80008020 0x80000020 0x80108020 0x80108000 0x80000000 0x80008000 0x100000 0x20 0x80100020 0x108000 0x100020 0x80008020 0 0x80000000 0x8000 0x108020 0x80100000 0x100020 0x80000020 0 0x108000 0x8020 0x80108000 0x80100000 0x8020 0 0x108020 0x80100020 0x100000 0x80008020 0x80100000 0x80108000 0x8000 0x80100000 0x80008000 0x20 0x80108020 0x108020 0x20 0x8000 0x80000000 0x8020 0x80108000 0x100000 0x80000020 0x100020 0x80008020 0x80000020 0x100020 0x108000 0 0x80008000 0x8020 0x80000000 0x80100020 0x80108020 0x108000];
    variable spfunction3 [list 0x208 0x8020200 0 0x8020008 0x8000200 0 0x20208 0x8000200 0x20008 0x8000008 0x8000008 0x20000 0x8020208 0x20008 0x8020000 0x208 0x8000000 0x8 0x8020200 0x200 0x20200 0x8020000 0x8020008 0x20208 0x8000208 0x20200 0x20000 0x8000208 0x8 0x8020208 0x200 0x8000000 0x8020200 0x8000000 0x20008 0x208 0x20000 0x8020200 0x8000200 0 0x200 0x20008 0x8020208 0x8000200 0x8000008 0x200 0 0x8020008 0x8000208 0x20000 0x8000000 0x8020208 0x8 0x20208 0x20200 0x8000008 0x8020000 0x8000208 0x208 0x8020000 0x20208 0x8 0x8020008 0x20200];
    variable spfunction4 [list 0x802001 0x2081 0x2081 0x80 0x802080 0x800081 0x800001 0x2001 0 0x802000 0x802000 0x802081 0x81 0 0x800080 0x800001 0x1 0x2000 0x800000 0x802001 0x80 0x800000 0x2001 0x2080 0x800081 0x1 0x2080 0x800080 0x2000 0x802080 0x802081 0x81 0x800080 0x800001 0x802000 0x802081 0x81 0 0 0x802000 0x2080 0x800080 0x800081 0x1 0x802001 0x2081 0x2081 0x80 0x802081 0x81 0x1 0x2000 0x800001 0x2001 0x802080 0x800081 0x2001 0x2080 0x800000 0x802001 0x80 0x800000 0x2000 0x802080];
    variable spfunction5 [list 0x100 0x2080100 0x2080000 0x42000100 0x80000 0x100 0x40000000 0x2080000 0x40080100 0x80000 0x2000100 0x40080100 0x42000100 0x42080000 0x80100 0x40000000 0x2000000 0x40080000 0x40080000 0 0x40000100 0x42080100 0x42080100 0x2000100 0x42080000 0x40000100 0 0x42000000 0x2080100 0x2000000 0x42000000 0x80100 0x80000 0x42000100 0x100 0x2000000 0x40000000 0x2080000 0x42000100 0x40080100 0x2000100 0x40000000 0x42080000 0x2080100 0x40080100 0x100 0x2000000 0x42080000 0x42080100 0x80100 0x42000000 0x42080100 0x2080000 0 0x40080000 0x42000000 0x80100 0x2000100 0x40000100 0x80000 0 0x40080000 0x2080100 0x40000100];
    variable spfunction6 [list 0x20000010 0x20400000 0x4000 0x20404010 0x20400000 0x10 0x20404010 0x400000 0x20004000 0x404010 0x400000 0x20000010 0x400010 0x20004000 0x20000000 0x4010 0 0x400010 0x20004010 0x4000 0x404000 0x20004010 0x10 0x20400010 0x20400010 0 0x404010 0x20404000 0x4010 0x404000 0x20404000 0x20000000 0x20004000 0x10 0x20400010 0x404000 0x20404010 0x400000 0x4010 0x20000010 0x400000 0x20004000 0x20000000 0x4010 0x20000010 0x20404010 0x404000 0x20400000 0x404010 0x20404000 0 0x20400010 0x10 0x4000 0x20400000 0x404010 0x4000 0x400010 0x20004010 0 0x20404000 0x20000000 0x400010 0x20004010];
    variable spfunction7 [list 0x200000 0x4200002 0x4000802 0 0x800 0x4000802 0x200802 0x4200800 0x4200802 0x200000 0 0x4000002 0x2 0x4000000 0x4200002 0x802 0x4000800 0x200802 0x200002 0x4000800 0x4000002 0x4200000 0x4200800 0x200002 0x4200000 0x800 0x802 0x4200802 0x200800 0x2 0x4000000 0x200800 0x4000000 0x200800 0x200000 0x4000802 0x4000802 0x4200002 0x4200002 0x2 0x200002 0x4000000 0x4000800 0x200000 0x4200800 0x802 0x200802 0x4200800 0x802 0x4000002 0x4200802 0x4200000 0x200800 0 0x2 0x4200802 0 0x200802 0x4200000 0x800 0x4000002 0x4000800 0x800 0x200002];
    variable spfunction8 [list 0x10001040 0x1000 0x40000 0x10041040 0x10000000 0x10001040 0x40 0x10000000 0x40040 0x10040000 0x10041040 0x41000 0x10041000 0x41040 0x1000 0x40 0x10040000 0x10000040 0x10001000 0x1040 0x41000 0x40040 0x10040040 0x10041000 0x1040 0 0 0x10040040 0x10000040 0x10001000 0x41040 0x40000 0x41040 0x40000 0x10041000 0x1000 0x40 0x10040040 0x1000 0x41040 0x10001000 0x40 0x10000040 0x10040000 0x10040040 0x10000000 0x40000 0x10001040 0 0x10041040 0x40040 0x10000040 0x10040000 0x10001000 0x10001040 0 0x10041040 0x41000 0x41000 0x1040 0x1040 0x40040 0x10000000 0x10041000];

    variable desEncrypt {0 32 2}
    variable desDecrypt {30 -2 -2}

    # Procedure: block - DES ECB and CBC mode support
    # Inputs:
    #   keyset   : Handle to an existing keyset.
    #   message  : String to be encrypted or decrypted (Note: For encryption,
    #              the string is extended with null characters to an integral
    #              multiple of eight bytes.  For decryption, the string length
    #              must be an integral multiple of eight bytes.
    #   encrypt  : Perform encryption (1) or decryption (0)
    #   mode     : DES mode 1=CBC, 0=ECB (default).
    #   iv       : Name of the variable containing the initialization vector
    #              used in CBC mode.  The value must be 64 bits in length.
    # Output:
    #   The encrypted or decrypted data string.
    proc block {keyset message encrypt {mode 0} {iv {}}} {
	variable spfunction1
	variable spfunction2
	variable spfunction3
	variable spfunction4
	variable spfunction5
	variable spfunction6
	variable spfunction7
	variable spfunction8
	variable desEncrypt
	variable desDecrypt
	variable keysets

	# Determine if the keyset handle is valid.
	if {[array names keysets $keyset] != {}} {
	    # Acquire the 16 or 48 subkeys we will need
	    set keys $keysets($keyset)
	} else {
	    error "The keyset handle \"$keyset\" is invalid!"
	}
	set m 0
	set cbcleft 0x00; set cbcleft2 0x00
	set cbcright 0x00; set cbcright2 0x00
	set len [string length $message];
        if {$len == 0} {
            return -code error "invalid message size: the message may not be empty"
        }
	set chunk 0;
	# Set up the loops for des
	expr {$encrypt ? [set looping $desEncrypt] : [set looping $desDecrypt]}

	# Pad the message out with null bytes.
	append message "\0\0\0\0\0\0\0\0"

	# Store the result here
	set result {};
	set tempresult {};

	# CBC mode
	if {$mode == 1} {
	    # Is the initialization/feedback vector variable is valid?
	    if {[string length $iv] < 1} {
		error "An initialization variable must be specified."
	    } else {
		upvar $iv ivec
		if {![info exists ivec]} {
		    error "The variable $iv does not exist."
		}
                if {[string length $ivec] != 8} {
                    return -code error "invalid initialization vector size:\
                        the initialization vector must be 8 bytes"
                }
	    }
	    # Use the input vector as the intial vector.
	    binary scan $ivec H8H8 cbcleftTemp cbcrightTemp
	    set cbcleft "0x$cbcleftTemp"
	    set cbcright "0x$cbcrightTemp"
	}

	# Loop through each 64 bit chunk of the message
	while {$m < $len} {
	    binary scan $message x${m}H8H8 lefttemp righttemp
	    set left {}
	    append left "0x" $lefttemp
	    set right {}
	    append right "0x" $righttemp
	    incr m 8

	    #puts "Left start: $left";
	    #puts "Right start: $right";
	    # For Cipher Block Chaining mode, xor the
	    # message with the previous result.
	    if {$mode == 1} {
		if {$encrypt} {
		    set left [expr {$left ^ $cbcleft}]
		    set right [expr {$right ^ $cbcright}]
		} else {
		    set cbcleft2 $cbcleft;
		    set cbcright2 $cbcright;
		    set cbcleft $left;
		    set cbcright $right;
		}
	    }

	    #puts "Left mode: $left";
	    #puts "Right mode: $right";
	    #puts "cbcleft: $cbcleft";
	    #puts "cbcleft2: $cbcleft2";
	    #puts "cbcright: $cbcright";
	    #puts "cbcright2: $cbcright2";

	    # First each 64 but chunk of the message
	    # must be permuted according to IP.
	    set temp [expr {(($left >> 4) ^ $right) & 0x0f0f0f0f}];
	    set right [expr {$right ^ $temp}];
	    set left [expr {$left ^ ($temp << 4)}];
	    set temp [expr {(($left >> 16) ^ $right) & 0x0000ffff}];
	    set right [expr {$right ^ $temp}];
	    set left [expr {$left ^ ($temp << 16)}];
	    set temp [expr {(($right >> 2) ^ $left) & 0x33333333}];
	    set left [expr {$left ^ $temp}]
	    set right [expr {$right ^ ($temp << 2)}];

	    set temp [expr {(($right >> 8) ^ $left) & 0x00ff00ff}];
	    set left [expr {$left ^ $temp}];
	    set right [expr {$right ^ ($temp << 8)}];
	    set temp [expr {(($left >> 1) ^ $right) & 0x55555555}];
	    set right [expr {$right ^ $temp}];
	    set left [expr {$left ^ ($temp << 1)}];

	    set left [expr {((($left << 1) & 0xffffffff) | \
				 (($left >> 31) & 0x00000001))}]; 
	    set right [expr {((($right << 1) & 0xffffffff) | \
				  (($right >> 31) & 0x00000001))}]; 

	    #puts "Left IP: [format %x $left]";
	    #puts "Right IP: [format %x $right]";

	    # Do this 1 time for each chunk of the message.
	    set endloop [lindex $looping 1];
	    set loopinc [lindex $looping 2];

	    #puts "endloop: $endloop";
	    #puts "loopinc: $loopinc";

	    # Now go through and perform the encryption or decryption. 
	    for {set i [lindex $looping 0]} \
		{$i != $endloop} {incr i $loopinc} {
		# For efficiency
		set right1 [expr {$right ^ [lindex $keys $i]}]; 
		set right2 [expr {((($right >> 4) & 0x0fffffff) | \
				       (($right << 28) & 0xffffffff)) ^ \
				      [lindex $keys [expr {$i + 1}]]}];
 
		# puts "right1: [format %x $right1]";
		# puts "right2: [format %x $right2]";

		# The result is attained by passing these
		# bytes through the S selection functions.
		set temp $left;
		set left $right;
		set right [expr {$temp ^ ([lindex $spfunction2 [expr {($right1 >> 24) & 0x3f}]] | \
					      [lindex $spfunction4 [expr {($right1 >> 16) & 0x3f}]] | \
					      [lindex $spfunction6 [expr {($right1 >>  8) & 0x3f}]] | \
					      [lindex $spfunction8 [expr {$right1 & 0x3f}]] | \
					      [lindex $spfunction1 [expr {($right2 >> 24) & 0x3f}]] | \
					      [lindex $spfunction3 [expr {($right2 >> 16) & 0x3f}]] | \
					      [lindex $spfunction5 [expr {($right2 >>  8) & 0x3f}]] | \
					      [lindex $spfunction7 [expr {$right2 & 0x3f}]])}];
 
		# puts "Left iter: [format %x $left]";
		# puts "Right iter: [format %x $right]";
		
	    }
	    set temp $left;
	    set left $right;
	    set right $temp; # Unreverse left and right.

	    #puts "Left Iterated: [format %x $left]";
	    #puts "Right Iterated: [format %x $right]";

	    # Move then each one bit to the right
	    set left [expr {((($left >> 1) & 0x7fffffff) \
				 | (($left << 31) & 0xffffffff))}]; 
	    set right [expr {((($right >> 1) & 0x7fffffff) \
				  | (($right << 31) & 0xffffffff))}]; 

	    #puts "Left shifted: [format %x $left]";
	    #puts "Right shifted: [format %x $right]";

	    # Now perform IP-1, which is IP in the opposite direction
	    set temp [expr {((($left >> 1) & 0x7fffffff) ^ $right) & 0x55555555}];
	    set right [expr {$right ^ $temp}];
	    set left [expr {$left ^ ($temp << 1)}];
	    set temp [expr {((($right >> 8) & 0x00ffffff) ^ $left) & 0x00ff00ff}];
	    set left [expr {$left ^ $temp}];
	    set right [expr {$right ^ ($temp << 8)}];
	    set temp [expr {((($right >> 2) & 0x3fffffff) ^ $left) & 0x33333333}]; 
	    set left [expr {$left ^ $temp}];
	    set right [expr {$right ^ ($temp << 2)}];
	    set temp [expr {((($left >> 16) & 0x0000ffff) ^ $right) & 0x0000ffff}];
	    set right [expr {$right ^ $temp}];
	    set left [expr {$left ^ ($temp << 16)}];
	    set temp [expr {((($left >> 4) & 0x0fffffff) ^ $right) & 0x0f0f0f0f}];
	    set right [expr {$right ^ $temp}];
	    set left [expr {$left ^ ($temp << 4)}];

	    #puts "Left IP-1: [format %x $left]";
	    #puts "Right IP-1: [format %x $right]";

	    # For Cipher Block Chaining mode, xor
	    # the message with the previous result.
	    if {$mode == 1} {
		if {$encrypt} {
		    set cbcleft $left;
		    set cbcright $right;
		} else {
		    set left [expr {$left ^ $cbcleft2}];
		    set right [expr {$right ^ $cbcright2}];
		}
	    }

	    append tempresult \
		[binary format H16 [format %08x%08x $left $right]]

	    #puts "Left final: [format %x $left]";
	    #puts "Right final: [format %x $right]";

	    incr chunk 8;
	    if {$chunk == 512} {
		append result $tempresult
		set tempresult {};
		set chunk 0;
	    }
	}; # For every 8 characters, or 64 bits in the message

	if {$mode == 1} {
	    if {$encrypt} {
		# Save the left and right registers to the feedback vector.
		set ivec [binary format H* \
			      [format %08x $left][format %08x $right]]
	    } else {
		set ivec [binary format H* \
			      [format %08x $cbcleft][format %08x $cbcright]]
	    }
	}

	# Return the result as an array
	return ${result}$tempresult
    }; # End of block

    # Procedure: stream - DES CFB and OFB mode support
    # Inputs:
    #   keyset   : Handle to an existing keyset.
    #   message  : String to be encrypted or decrypted (Note: The length of the
    #              string is dependent upon the value of kbits.  Remember that
    #              the string is part of a stream of data, so it must be sized
    #              properly for subsequent encryptions/decryptions to be
    #              correct.  See the man page for correct message lengths for
    #              values of kbits).
    #   encrypt  : Perform encryption (1) or decryption (0)
    #   mode     : DES mode 0=OFB, 1=CFB.
    #   iv       : Name of variable containing the initialization vector.  The
    #              value must be 64 bits in length with the first 64-L bits set
    #              to zero.
    #   kbits    : Number of bits in a data block (default of 64).
    # Output:
    #   The encrypted or decrypted data string.
    proc stream {keyset message encrypt mode iv {kbits 64}} {
	variable spfunction1
	variable spfunction2
	variable spfunction3
	variable spfunction4
	variable spfunction5
	variable spfunction6
	variable spfunction7
	variable spfunction8
	variable desEncrypt
	variable keysets

	# Determine if the keyset handle is valid.
	if {[array names keysets $keyset] != {}} {
	    # Acquire the 16 subkeys we will need.
	    set keys $keysets($keyset)
	} else {
	    error "The keyset handle \"$keyset\" is invalid!"
	}

	# Is the initialization/feedback vector variable is valid?
	if {[string length $iv] < 1} {
	    error "An initialization variable must be specified."
	} else {
	    upvar $iv ivec
	    if {![info exists ivec]} {
		error "The variable $iv does not exist."
	    }
	}

        # Determine if message length (in bits)
	# is not an integral number of kbits.
	set len [string length $message];
        #puts "len: $len, kbits: $kbits"
	if {($kbits < 1) || ($kbits > 64)} {
	    error "The valid values of kbits are 1 through 64."
        } elseif {($kbits % 8) != 0} {
	    set blockSize [expr {$kbits + (8 - ($kbits % 8))}]
	    set fail [expr {(($len * 8) / $blockSize) % $kbits}]
	} else {
	    set blockSize [expr {$kbits / 8}]
	    set fail [expr {$len % $blockSize}]
	}
        if {$fail} {
	    error "Data length (in bits) is not an integral number of kbits."
	}

	set m 0
	set n 0
	set chunk 0;
	# Set up the loops for des
	set looping $desEncrypt

        # Set up shifting values.  Used for both CFB and OFB modes.
        if {$kbits < 32} {
	    # Only some bits from left output are needed.
	    set kOutShift [expr {32 - $kbits}]
	    set kOutMask [expr {0x7fffffff >> (31 - $kbits)}]
	    # Determine number of message bytes needed per iteration.
	    set msgBytes [expr {int(ceil(double($kbits) / 8.0))}]
	    # Determine number of message bits needed per iteration.
	    set msgBits [expr {$msgBytes * 8}]
	    set msgBitsSub1 [expr {$msgBits - 1}]
	    # Define bit caches.
	    set bitCacheIn {}
	    set bitCacheOut {}
	    # Variable used to remove bits 0 through
	    # kbits-1 in the input bit cache.
	    set kbitsSub1 [expr {$kbits - 1}]
	    # Variable used to remove leading dummy binary bits.
	    set xbits [expr {32 - $kbits}]
	} elseif {$kbits == 32} {
	    # Only bits of left output are used.
	    # Four messages bytes are needed per iteration.
	    set msgBytes 4
	    set xbits 32
	} elseif {$kbits < 64} {
	    # All bits from left output are needed.
	    set kOutShiftLeft [expr {$kbits - 32}]
	    # Some bits from right output are needed.
	    set kOutShiftRight [expr {64 - $kbits}]
	    set kOutMaskRight [expr {0x7fffffff >> (63 - $kbits)}]
	    # Determine number of message bytes needed per iteration.
	    set msgBytes [expr {int(ceil(double($kbits) / 8.0))}]
	    # Determine number of message bits needed per iteration.
	    set msgBits [expr {$msgBytes * 8}]
	    set msgBitsSub1 [expr {$msgBits - 1}]
	    # Define bit caches.
	    set bitCacheIn {}
	    set bitCacheOut {}
	    # Variable used to remove bits 0 through
	    # kbits-1 in the input bit cache.
	    set kbitsSub1 [expr {$kbits - 1}]
	    # Variable used to remove leading dummy binary bits.
	    set xbits [expr {64 - $kbits}]
	} else {
	    # All 64 bits of output are used.
	    # Eight messages bytes are needed per iteration.
	    set msgBytes 8
	    set xbits 0
	}

	# Store the result here
	set result {}
	set tempresult {}

	# Set up the initialization vector bitstream
	binary scan $ivec H8H8 leftTemp rightTemp
	set left "0x$leftTemp"
	set right "0x$rightTemp"
        #puts "Retrieved Feedback vector: $fbvec"
        #puts "Start: |$left| |$right|"
	
	# Loop through each 64 bit chunk of the message
	while {$m < $len} {
	    # puts "Left start: $left";
	    # puts "Right start: $right";

	    # First each 64 but chunk of the
	    # message must be permuted according to IP.
	    set temp [expr {(($left >> 4) ^ $right) & 0x0f0f0f0f}];
	    set right [expr {$right ^ $temp}];
	    set left [expr {$left ^ ($temp << 4)}];
	    set temp [expr {(($left >> 16) ^ $right) & 0x0000ffff}];
	    set right [expr {$right ^ $temp}];
	    set left [expr {$left ^ ($temp << 16)}];
	    set temp [expr {(($right >> 2) ^ $left) & 0x33333333}];
	    set left [expr {$left ^ $temp}];
	    set right [expr {$right ^ ($temp << 2)}];

	    set temp [expr {(($right >> 8) ^ $left) & 0x00ff00ff}];
	    set left [expr {$left ^ $temp}];
	    set right [expr {$right ^ ($temp << 8)}];
	    set temp [expr {(($left >> 1) ^ $right) & 0x55555555}];
	    set right [expr {$right ^ $temp}];
	    set left [expr {$left ^ ($temp << 1)}];

	    set left [expr {((($left << 1) & 0xffffffff) | \
				 (($left >> 31) & 0x00000001))}]; 
	    set right [expr {((($right << 1) & 0xffffffff) | \
				  (($right >> 31) & 0x00000001))}]; 

	    #puts "Left IP: [format %x $left]";
	    #puts "Right IP: [format %x $right]";

	    # Do this 1 time for each chunk of the message
	    set endloop [lindex $looping 1];
	    set loopinc [lindex $looping 2];

	    # puts "endloop: $endloop";
	    # puts "loopinc: $loopinc";

	    # Now go through and perform the encryption or decryption  
	    for {set i [lindex $looping 0]} \
		{$i != $endloop} {incr i $loopinc} {
		# For efficiency
		set right1 [expr {$right ^ [lindex $keys $i]}]; 
		set right2 [expr {((($right >> 4) & 0x0fffffff) | \
				       (($right << 28) & 0xffffffff)) ^ \
				      [lindex $keys [expr {$i + 1}]]}];
 
		# puts "right1: [format %x $right1]";
		# puts "right2: [format %x $right2]";

		# The result is attained by passing these
		# bytes through the S selection functions.
		set temp $left;
		set left $right;
		set right [expr {$temp ^ ([lindex $spfunction2 [expr {($right1 >> 24) & 0x3f}]] | \
					      [lindex $spfunction4 [expr {($right1 >> 16) & 0x3f}]] | \
					      [lindex $spfunction6 [expr {($right1 >>  8) & 0x3f}]] | \
					      [lindex $spfunction8 [expr {$right1 & 0x3f}]] | \
					      [lindex $spfunction1 [expr {($right2 >> 24) & 0x3f}]] | \
					      [lindex $spfunction3 [expr {($right2 >> 16) & 0x3f}]] | \
					      [lindex $spfunction5 [expr {($right2 >>  8) & 0x3f}]] | \
					      [lindex $spfunction7 [expr {$right2 & 0x3f}]])}];
 
		# puts "Left iter: [format %x $left]";
		# puts "Right iter: [format %x $right]";
	    }
	    set temp $left;
	    set left $right;
	    set right $temp; # Unreverse left and right

	    #puts "Left Iterated: [format %x $left]";
	    #puts "Right Iterated: [format %x $right]";

	    # Move then each one bit to the right
	    set left [expr {((($left >> 1) & 0x7fffffff) | \
				 (($left << 31) & 0xffffffff))}]; 
	    set right [expr {((($right >> 1) & 0x7fffffff) | \
				  (($right << 31) & 0xffffffff))}]; 

	    #puts "Left shifted: [format %x $left]";
	    #puts "Right shifted: [format %x $right]";

	    # Now perform IP-1, which is IP in the opposite direction
	    set temp [expr {((($left >> 1) & 0x7fffffff) ^ $right) & 0x55555555}];
	    set right [expr {$right ^ $temp}];
	    set left [expr {$left ^ ($temp << 1)}];
	    set temp [expr {((($right >> 8) & 0x00ffffff) ^ $left) & 0x00ff00ff}];
	    set left [expr {$left ^ $temp}];
	    set right [expr {$right ^ ($temp << 8)}];
	    set temp [expr {((($right >> 2) & 0x3fffffff) ^ $left) & 0x33333333}]; 
	    set left [expr {$left ^ $temp}];
	    set right [expr {$right ^ ($temp << 2)}];
	    set temp [expr {((($left >> 16) & 0x0000ffff) ^ $right) & 0x0000ffff}];
	    set right [expr {$right ^ $temp}];
	    set left [expr {$left ^ ($temp << 16)}];
	    set temp [expr {((($left >> 4) & 0x0fffffff) ^ $right) & 0x0f0f0f0f}];
	    set right [expr {$right ^ $temp}];
	    set left [expr {$left ^ ($temp << 4)}];

	    #puts "Left IP-1: [format %x $left]";
	    #puts "Right IP-1: [format %x $right]";

	    # Extract the "kbits" most significant bits from the output block.
	    if {$kbits < 32} {
		# Only some bits from left output are needed.
		set kData [expr {($left >> $kOutShift) & $kOutMask}]
		set newBits {}
		# If necessary, copy message bytes into input bit cache.
		if {([string length $bitCacheIn] < $kbits) && ($n < $len)} {
		    if {$len - $n < $msgBytes} {
			set lastBits [expr {($len - $n) * 8}]
			###puts -nonewline [binary scan $message x${n}B$lastBits newBits]
			binary scan $message x${n}B$lastBits newBits
		    } else {
			# Extract "msgBytes" whole bytes as bits
			###puts -nonewline [binary scan $message x${n}B$msgBits newBits]
			binary scan $message x${n}B$msgBits newBits
		    }
		    incr n $msgBytes
		    #puts " $newBits  $n [expr {$len - $n}]"
		    # Add the bits to the input bit cache.
		    append bitCacheIn $newBits
		}
		#puts -nonewline "In bit cache: $bitCacheIn"
		# Set up message data from input bit cache.
		binary scan [binary format B32 [format %032s [string range $bitCacheIn 0 $kbitsSub1]]] H8 temp
		set msgData "0x$temp"
		# Mix message bits with crypto bits.
		set mixData [expr {$msgData ^ $kData}]
		# Discard collected bits from the input bit cache.
		set bitCacheIn [string range $bitCacheIn $kbits end]
		#puts "  After: $bitCacheIn"
		# Convert back to a bit stream and append to the output bit cache.
		# Only the lower kbits are wanted.
		binary scan [binary format H8 [format %08x $mixData]] B32 msgOut
		append bitCacheOut [string range $msgOut $xbits end]
		#puts -nonewline "Out bit cache: $bitCacheOut"
		# If there are sufficient bits, move bytes to the temporary holding string.
		if {[string length $bitCacheOut] >= $msgBits} {
		    append tempresult [binary format B$msgBits [string range $bitCacheOut 0 $msgBitsSub1]]
		    set bitCacheOut [string range $bitCacheOut $msgBits end]
                    #puts -nonewline "  After: $bitCacheOut"
		    incr m $msgBytes
		    ###puts "$m bytes output"
		    incr chunk $msgBytes
		}
		#puts ""
		# For CFB mode
		if {$mode == 1} {
		    if {$encrypt} {
			set temp [expr {($right << $kbits) & 0xffffffff}]
			set left [expr {(($left << $kbits) & 0xffffffff) | (($right >> $kOutShift) & $kOutMask)}]
			set right [expr {$temp | $mixData}]
		    } else {
			set temp [expr {($right << $kbits) & 0xffffffff}]
			set left [expr {(($left << $kbits) & 0xffffffff) | (($right >> $kOutShift) & $kOutMask)}]
			set right [expr {$temp | $msgData}]
		    }
		}
	    } elseif {$kbits == 32} {
		# Only bits of left output are used.
		set kData $left
		# Four messages bytes are needed per iteration.
		binary scan $message x${m}H8 temp
		incr m 4
		incr chunk 4
		set msgData "0x$temp"
		# Mix message bits with crypto bits.
		set mixData [expr {$msgData ^ $kData}]
		# Move bytes to the temporary holding string.
		append tempresult [binary format H8 [format %08x $mixData]]
		# For CFB mode
		if {$mode == 1} {
		    set left $right
		    if {$encrypt} {
			set right $mixData
		    } else {
			set right $msgData
		    }
		}
	    } elseif {$kbits < 64} {
		set kDataLeft [expr {($left >> $kOutShiftRight) & $kOutMaskRight}]
		set temp [expr {($left << $kOutShiftLeft) & 0xffffffff}]
		set kDataRight [expr {(($right >> $kOutShiftRight) & $kOutMaskRight) | $temp}]
		# If necessary, copy message bytes into input bit cache.
		if {([string length $bitCacheIn] < $kbits)  && ($n < $len)} {
		    if {$len - $n < $msgBytes} {
			set lastBits [expr {($len - $n) * 8}]
			###puts -nonewline [binary scan $message x${n}B$lastBits newBits]
			binary scan $message x${n}B$lastBits newBits
		    } else {
			# Extract "msgBytes" whole bytes as bits
			###puts -nonewline [binary scan $message x${n}B$msgBits newBits]
			binary scan $message x${n}B$msgBits newBits
		    }
		    incr n $msgBytes
		    # Add the bits to the input bit cache.
		    append bitCacheIn $newBits
		}
		# Set up message data from input bit cache.
		# puts "Bits from cache: [set temp [string range $bitCacheIn 0 $kbitsSub1]]"
		# puts "Length of bit string: [string length $temp]"
		binary scan [binary format B64 [format %064s [string range $bitCacheIn 0 $kbitsSub1]]] H8H8 leftTemp rightTemp
		set msgDataLeft "0x$leftTemp"
		set msgDataRight "0x$rightTemp"
		# puts "msgDataLeft: $msgDataLeft"
		# puts "msgDataRight: $msgDataRight"
		# puts "kDataLeft: [format 0x%08x $kDataLeft]"
		# puts "kDataRight: [format 0x%08x $kDataRight]"
		# Mix message bits with crypto bits.
		set mixDataLeft [expr {$msgDataLeft ^ $kDataLeft}]
		set mixDataRight [expr {$msgDataRight ^ $kDataRight}]
		# puts "mixDataLeft: $mixDataLeft"
		# puts "mixDataRight: $mixDataRight"
		# puts "mixDataLeft: [format 0x%08x $mixDataLeft]"
		# puts "mixDataRight: [format 0x%08x $mixDataRight]"
		# Discard collected bits from the input bit cache.
		set bitCacheIn [string range $bitCacheIn $kbits end]
		# Convert back to a bit stream and
		# append to the output bit cache.
		# Only the lower kbits are wanted.
		binary scan \
		    [binary format H8H8 \
			 [format %08x $mixDataLeft] \
			 [format %08x $mixDataRight]] B64 msgOut
		append bitCacheOut [string range $msgOut $xbits end]
		# If there are sufficient bits, move
		# bytes to the temporary holding string.
		if {[string length $bitCacheOut] >= $msgBits} {
		    append tempresult \
			[binary format B$msgBits \
			     [string range $bitCacheOut 0 $msgBitsSub1]]
		    set bitCacheOut [string range $bitCacheOut $msgBits end]
		    incr m $msgBytes
		    incr chunk $msgBytes
		}
		# For CFB mode
		if {$mode == 1} {
		    if {$encrypt} {
			set temp \
			    [expr {($right << $kOutShiftRight) & 0xffffffff}]
			set left [expr {$temp | $mixDataLeft}]
			set right $mixDataRight
		    } else {
			set temp \
			    [expr {($right << $kOutShiftRight) & 0xffffffff}]
			set left [expr {$temp | $msgDataLeft}]
			set right $msgDataRight
		    }
		}
	    } else {
		# All 64 bits of output are used.
		set kDataLeft $left
		set kDataRight $right
		# Eight messages bytes are needed per iteration.
		binary scan $message x${m}H8H8 leftTemp rightTemp
		incr m 8
		incr chunk 8
		set msgDataLeft "0x$leftTemp"
		set msgDataRight "0x$rightTemp"
		# Mix message bits with crypto bits.
		set mixDataLeft [expr {$msgDataLeft ^ $kDataLeft}]
		set mixDataRight [expr {$msgDataRight ^ $kDataRight}]
		# Move bytes to the temporary holding string.
		append tempresult \
		    [binary format H16 \
			 [format %08x%08x $mixDataLeft $mixDataRight]]
		# For CFB mode
		if {$mode == 1} {
		    if {$encrypt} {
			set left $mixDataLeft
			set right $mixDataRight
		    } else {
			set left $msgDataLeft
			set right $msgDataRight
		    }
		}
	    }

	    #puts "Left final: [format %08x $left]";
	    #puts "Right final: [format %08x $right]"

	    if {$chunk >= 512} {
		append result $tempresult
		set tempresult {};
		set chunk 0;
	    }
	}; # For every 8 characters, or 64 bits in the message
        #puts "End: |[format 0x%08x $left]| |[format 0x%08x $right]|"
	# Save the left and right registers to the feedback vector.
	set ivec [binary format H* [format %08x $left][format %08x $right]]
	#puts "Saved Feedback vector: $fbvectors($fbvector)"

        append result $tempresult
	if {[string length $result] > $len} {
	    set result [string replace $result $len end]
	}
	# Return the result as an array
	return $result
    }; # End of stream

    variable pc2bytes0 [list 0 0x4 0x20000000 0x20000004 0x10000 0x10004 0x20010000 0x20010004 0x200 0x204 0x20000200 0x20000204 0x10200 0x10204 0x20010200 0x20010204]
    variable pc2bytes1 [list 0 0x1 0x100000 0x100001 0x4000000 0x4000001 0x4100000 0x4100001 0x100 0x101 0x100100 0x100101 0x4000100 0x4000101 0x4100100 0x4100101]
    variable pc2bytes2 [list 0 0x8 0x800 0x808 0x1000000 0x1000008 0x1000800 0x1000808 0 0x8 0x800 0x808 0x1000000 0x1000008 0x1000800 0x1000808]
    variable pc2bytes3 [list 0 0x200000 0x8000000 0x8200000 0x2000 0x202000 0x8002000 0x8202000 0x20000 0x220000 0x8020000 0x8220000 0x22000 0x222000 0x8022000 0x8222000]
    variable pc2bytes4 [list 0 0x40000 0x10 0x40010 0 0x40000 0x10 0x40010 0x1000 0x41000 0x1010 0x41010 0x1000 0x41000 0x1010 0x41010]
    variable pc2bytes5 [list 0 0x400 0x20 0x420 0 0x400 0x20 0x420 0x2000000 0x2000400 0x2000020 0x2000420 0x2000000 0x2000400 0x2000020 0x2000420]
    variable pc2bytes6 [list 0 0x10000000 0x80000 0x10080000 0x2 0x10000002 0x80002 0x10080002 0 0x10000000 0x80000 0x10080000 0x2 0x10000002 0x80002 0x10080002]
    variable pc2bytes7 [list 0 0x10000 0x800 0x10800 0x20000000 0x20010000 0x20000800 0x20010800 0x20000 0x30000 0x20800 0x30800 0x20020000 0x20030000 0x20020800 0x20030800]
    variable pc2bytes8 [list 0 0x40000 0 0x40000 0x2 0x40002 0x2 0x40002 0x2000000 0x2040000 0x2000000 0x2040000 0x2000002 0x2040002 0x2000002 0x2040002]
    variable pc2bytes9 [list 0 0x10000000 0x8 0x10000008 0 0x10000000 0x8 0x10000008 0x400 0x10000400 0x408 0x10000408 0x400 0x10000400 0x408 0x10000408]
    variable pc2bytes10 [list 0 0x20 0 0x20 0x100000 0x100020 0x100000 0x100020 0x2000 0x2020 0x2000 0x2020 0x102000 0x102020 0x102000 0x102020]
    variable pc2bytes11 [list 0 0x1000000 0x200 0x1000200 0x200000 0x1200000 0x200200 0x1200200 0x4000000 0x5000000 0x4000200 0x5000200 0x4200000 0x5200000 0x4200200 0x5200200]
    variable pc2bytes12 [list 0 0x1000 0x8000000 0x8001000 0x80000 0x81000 0x8080000 0x8081000 0x10 0x1010 0x8000010 0x8001010 0x80010 0x81010 0x8080010 0x8081010]
    variable pc2bytes13 [list 0 0x4 0x100 0x104 0 0x4 0x100 0x104 0x1 0x5 0x101 0x105 0x1 0x5 0x101 0x105]

    # Now define the left shifts which need to be done
    variable shifts {0  0  1  1  1  1  1  1  0  1  1  1  1  1  1  0};

    # Procedure: createKeys
    # Input:
    #   key     : The 64-bit DES key (Note: The lsb of each byte
    #             is ignored; odd parity is not required).
    #
    #   weak:   If true then weak keys are allowed. The default is to raise an
    #           error when a weak key is seen.
    # Output:
    # The 16 (DES) subkeys.
    proc createKeys {key {weak 0}} {
	variable pc2bytes0
	variable pc2bytes1
	variable pc2bytes2
	variable pc2bytes3
	variable pc2bytes4
	variable pc2bytes5
	variable pc2bytes6
	variable pc2bytes7
	variable pc2bytes8
	variable pc2bytes9
	variable pc2bytes10
	variable pc2bytes11
	variable pc2bytes12
	variable pc2bytes13
	variable shifts

	# Stores the return keys
	set keys {}
	# Other variables
	set lefttemp {}; set righttemp {}
	binary scan $key H8H8 lefttemp righttemp
	set left {}
	append left "0x" $lefttemp
	set right {}
	append right "0x" $righttemp

	#puts "Left key: $left"
	#puts "Right key: $right"

	# Test for weak keys
        if {! $weak} {
            set maskedLeft [expr {$left & 0xfefefefe}]
            set maskedRight [expr {$right & 0xfefefefe}]
            if {($maskedLeft == 0x00000000) \
                    && ($maskedRight == 0x00000000)} {
                error "The key is weak!"
            } elseif {($maskedLeft == 0x1e1e1e1e) \
                          && ($maskedRight == 0x0e0e0e0e)} {
                error "The key is weak!"
            } elseif {($maskedLeft == 0xe0e0e0e0) \
                          && ($maskedRight == 0xf0f0f0f0)} {
                error "The key is weak!"
            } elseif {($maskedLeft == 0xfefefefe) \
                          && ($maskedRight == 0xfefefefe)} {
                error "The key is weak!"
            }
        }

	set temp [expr {(($left >> 4) ^ $right) & 0x0f0f0f0f}]
	set right [expr {$right ^ $temp}]
	set left [expr {$left ^ ($temp << 4)}]
	set temp [expr {(($right >> 16) ^ $left) & 0x0000ffff}]
	set left [expr {$left ^ $temp}]
	set right [expr {$right ^ ($temp << 16)}]
	set temp [expr {(($left >> 2) ^ $right) & 0x33333333}]
	set right [expr {$right ^ $temp}]
	set left [expr {$left ^ ($temp << 2)}]
	set temp [expr {(($right >> 16) ^ $left) & 0x0000ffff}]
	set left [expr {$left ^ $temp}]
	set right [expr {$right ^ ($temp << 16)}]
	set temp [expr {(($left >> 1) ^ $right) & 0x55555555}]
	set right [expr {$right ^ $temp}]
	set left [expr {$left ^ ($temp << 1)}]
	set temp [expr {(($right >> 8) ^ $left) & 0x00ff00ff}]
	set left [expr {$left ^ $temp}]
	set right [expr {$right ^ ($temp << 8)}]
	set temp [expr {(($left >> 1) ^ $right) & 0x55555555}]
	set right [expr $right ^ $temp]
	set left [expr {$left ^ ($temp << 1)}]
	    
	# puts "Left key PC1: [format %x $left]"
	# puts "Right key PC1: [format %x $right]"

	# The right side needs to be shifted and to get
	# the last four bits of the left side
	set temp [expr {($left << 8) | (($right >> 20) & 0x000000f0)}];
	# Left needs to be put upside down
	set left [expr {($right << 24) | (($right << 8) & 0x00ff0000) | \
			    (($right >> 8) & 0x0000ff00) \
			    | (($right >> 24) & 0x000000f0)}];
	set right $temp;

	#puts "Left key juggle: [format %x $left]"
	#puts "Right key juggle: [format %x $right]"

	# Now go through and perform these
	# shifts on the left and right keys.
	foreach i $shifts  {
	    # Shift the keys either one or two bits to the left.
	    if {$i} {
		set left [expr {($left << 2) \
				    | (($left >> 26) & 0x0000003f)}];
		set right [expr {($right << 2) \
				     | (($right >> 26) & 0x0000003f)}];
	    } else {
		set left [expr {($left << 1) \
				    | (($left >> 27) & 0x0000001f)}];
		set right [expr {($right << 1) \
				     | (($right >> 27) & 0x0000001f)}];
	    }
	    set left [expr {$left & 0xfffffff0}];
	    set right [expr {$right & 0xfffffff0}];

	    # Now apply PC-2, in such a way that E is easier when encrypting or
	    # decrypting this conversion will look like PC-2 except only the
	    # last 6 bits of each byte are used rather than 48 consecutive bits
	    # and the order of lines will be according to how the S selection
	    # functions will be applied: S2, S4, S6, S8, S1, S3, S5, S7.
	    set lefttemp [expr {[lindex $pc2bytes0 [expr {($left >> 28) & 0x0000000f}]] | \
				    [lindex $pc2bytes1 [expr {($left >> 24) & 0x0000000f}]] | \
				    [lindex $pc2bytes2 [expr {($left >> 20) & 0x0000000f}]] | \
				    [lindex $pc2bytes3 [expr {($left >> 16) & 0x0000000f}]] | \
				    [lindex $pc2bytes4 [expr {($left >> 12) & 0x0000000f}]] | \
				    [lindex $pc2bytes5 [expr {($left >> 8) & 0x0000000f}]] | \
				    [lindex $pc2bytes6 [expr {($left >> 4) & 0x0000000f}]]}];
	    set righttemp [expr {[lindex $pc2bytes7 [expr {($right >> 28) & 0x0000000f}]] | \
				     [lindex $pc2bytes8 [expr {($right >> 24) & 0x0000000f}]] | \
				     [lindex $pc2bytes9 [expr {($right >> 20) & 0x0000000f}]] | \
				     [lindex $pc2bytes10 [expr {($right >> 16) & 0x0000000f}]] | \
				     [lindex $pc2bytes11 [expr {($right >> 12) & 0x0000000f}]] | \
				     [lindex $pc2bytes12 [expr {($right >> 8) & 0x0000000f}]] | \
				     [lindex $pc2bytes13 [expr {($right >> 4) & 0x0000000f}]]}];
	    set temp [expr {(($righttemp >> 16) ^ $lefttemp) & 0x0000ffff}];
	    lappend keys [expr {$lefttemp ^ $temp}];
	    lappend keys [expr {$righttemp ^ ($temp << 16)}];
	}
	# Return the keys we've created.
	return $keys;
    }; # End of createKeys.
}; # End of des namespace eval.

package provide tclDESjr 1.0.0
