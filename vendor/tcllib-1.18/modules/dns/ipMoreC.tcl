# Skip this for window and a specific version of Solaris
# 
# This could do with an explanation -- why are we avoiding these platforms
# and perhaps using critcl's platform::platform command might be better?
#
if {[string equal $::tcl_platform(platform) windows] ||
    ([string equal $::tcl_platform(os)      SunOS] &&
     [string equal $::tcl_platform(osVersion) 5.6])
} {
    # avoid warnings about nothing to compile
    critcl::ccode {
        /* nothing to do */
    }
    return
}

package require critcl;

namespace eval ::ip {

critcl::ccode {
#include <stdlib.h>
#include <stdio.h>
#include <tcl.h>
#include <inttypes.h>
#include <arpa/inet.h>
#include <string.h>
#include <sys/socket.h>
}

critcl::ccommand prefixToNativec {clientData interp objc objv} { 
    int elemLen, maskLen, ipLen, mask;
	int rval,convertListc,i;
	Tcl_Obj **convertListv;
	Tcl_Obj *listPtr,*returnPtr, *addrList;
	char *stringIP, *slashPos, *stringMask;
	char v4HEX[11];
	
	uint32_t inaddr;
	listPtr = NULL;

	/* printf ("\n in prefixToNativeC"); */
	/* printf ("\n objc = %d",objc); */

	if (objc != 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "<ipaddress>/<mask>");
		return TCL_ERROR;
	}


	if (Tcl_ListObjGetElements (interp, objv[1], 
								&convertListc, &convertListv) != TCL_OK) {
		return TCL_ERROR;
	}
	returnPtr = Tcl_NewListObj(0, (Tcl_Obj **) NULL);
	for (i = 0; i < convertListc; i++) {
		/*  need to create a duplicate here because when we modify */
		/*  the stringIP it'll mess up the original in the calling */
		/*  context */
		addrList = Tcl_DuplicateObj(convertListv[i]);
		stringIP = Tcl_GetStringFromObj(addrList, &elemLen);
		listPtr = Tcl_NewListObj(0, (Tcl_Obj **) NULL);
		/* printf ("\n  ### %s ### string \n", stringIP); */
		/*  split the ip address and mask */
		slashPos = strchr(stringIP, (int) '/');
		if (slashPos == NULL) {
			/*  straight ip address without mask */
			mask = 0xffffffff;
			ipLen = strlen(stringIP);
		} else {
			/* ipaddress has the mask, handle the mask and seperate out the  */
			/*  ip address */
			/* printf ("\n ** %d ",(uintptr_t)slashPos); */
			stringMask = slashPos +1;
			maskLen =strlen(stringMask);
			/* put mask in hex form */
			if (maskLen < 3) {
				mask = atoi(stringMask);
				mask = (0xFFFFFFFF << (32 - mask)) & 0xFFFFFFFF;
			} else {
				/* mask is in dotted form */
				if ((rval = inet_pton(AF_INET,stringMask,&mask)) < 1 ) {
					Tcl_AddErrorInfo(interp, "\n    bad format encountered in mask conversion");
					return TCL_ERROR;	
				}
				mask = htonl(mask);
			}
			ipLen = (uintptr_t)slashPos  - (uintptr_t)stringIP;
			/* divide the string into ip and mask portion */
			*slashPos = '\0';
			/* printf("\n %d %d %d %d", (uintptr_t)stringMask, maskLen, (uintptr_t)stringIP, ipLen); */
		}
		if ( (rval = inet_pton(AF_INET,stringIP,&inaddr)) < 1) {
			Tcl_AddErrorInfo(interp, 
							 "\n    bad format encountered in ip conversion");
			return TCL_ERROR;
		};
		inaddr = htonl(inaddr);
		/* apply the mask the to the ip portion, just to make sure  */
		/*  what we return is cleaned up */
		inaddr = inaddr & mask;
		sprintf(v4HEX,"0x%08X",inaddr);
		/* printf ("\n\n ### %s",v4HEX); */
		Tcl_ListObjAppendElement(interp, listPtr,
								 Tcl_NewStringObj(v4HEX,-1));
		sprintf(v4HEX,"0x%08X",mask);
		Tcl_ListObjAppendElement(interp, listPtr,
								 Tcl_NewStringObj(v4HEX,-1));
		Tcl_ListObjAppendElement(interp, returnPtr, listPtr);
		Tcl_DecrRefCount(addrList);
	}
	
	if (convertListc==1) {
		Tcl_SetObjResult(interp,listPtr);
	} else {
		Tcl_SetObjResult(interp,returnPtr);
	}
	
	return TCL_OK;
}

critcl::ccommand isOverlapNativec {clientData interp objc objv} {
        int i; 
        unsigned int ipaddr,ipMask, mask1mask2;
        unsigned int ipaddr2,ipMask2;
        int compareListc,comparePrefixMaskc;
        int allSet,inlineSet,index;
        Tcl_Obj **compareListv,**comparePrefixMaskv, *listPtr;
        Tcl_Obj *result;
    static CONST char *options[] = {
                "-all",     "-inline", "-ipv4", NULL
    };
    enum options {
		OVERLAP_ALL, OVERLAP_INLINE, OVERLAP_IPV4
    };

        allSet = 0;
        inlineSet = 0;
        listPtr = NULL;

        /* printf ("\n objc = %d",objc); */
        if (objc < 3) {
                Tcl_WrongNumArgs(interp, 1, objv, "?options? <hexIP> <hexMask> <hexList>");
                return TCL_ERROR;
        }
        for (i = 1; i < objc-3; i++) {
           if (Tcl_GetIndexFromObj(interp, objv[i], options, "option", 0, &index)
                   != TCL_OK) {
                   return TCL_ERROR;
           }
           switch (index) {
           case OVERLAP_ALL:
                   allSet = 1;
                   /* printf ("\n all selected"); */
                   break;
           case OVERLAP_INLINE:
                   inlineSet = 1;
                   /* printf ("\n inline selected"); */
                   break;
		   case OVERLAP_IPV4:
			   break;
           }
        }
        /* options are parsed */

        /* create return obj */
        result = Tcl_GetObjResult (interp);

        /* set ipaddr and ipmask */
        Tcl_GetIntFromObj(interp,objv[objc-3],(int*)&ipaddr);
        Tcl_GetIntFromObj(interp,objv[objc-2],(int*)&ipMask);

        /* split the 3rd argument into <ipaddr> <mask> pairs */
        if (Tcl_ListObjGetElements (interp, objv[objc-1], &compareListc, &compareListv) != TCL_OK) {
                return TCL_ERROR;
        }
/*       printf("comparing %x/%x \n",ipaddr,ipMask); */

        if (allSet || inlineSet) {
                listPtr = Tcl_NewListObj(0, (Tcl_Obj **) NULL);
        }

        for (i = 0; i < compareListc; i++) {
					    /* split the ipaddr2 and ipmask2  */
                if (Tcl_ListObjGetElements (interp, 
					    compareListv[i], 
					    &comparePrefixMaskc, 
					    &comparePrefixMaskv) != TCL_OK) {
		    return TCL_ERROR;
                }
                if (comparePrefixMaskc != 2) {
		    Tcl_AddErrorInfo(interp,"need format {{<ipaddr> <mask>} {<ipad..}}");
                        return TCL_ERROR;
                }
                Tcl_GetIntFromObj(interp,comparePrefixMaskv[0],(int*)&ipaddr2);
                Tcl_GetIntFromObj(interp,comparePrefixMaskv[1],(int*)&ipMask2);
/*               printf(" with %x/%x \n",ipaddr2,ipMask2); */
                mask1mask2 = ipMask & ipMask2;
/*               printf("  mask1mask2 %x \n",mask1mask2); */
/*               printf("  ipaddr & mask1mask2  %x\n",ipaddr & mask1mask2); */
/*               printf("  ipaddr2 & mask1mask2 %x\n",ipaddr2 & mask1mask2); */
                if ((ipaddr & mask1mask2) == (ipaddr2 & mask1mask2)) {
		    if (allSet) {
			if (inlineSet) {
			    Tcl_ListObjAppendElement(interp, listPtr,
						     compareListv[i]);
			} else {
			    /* printf("\n appending %d",i+1); */
			    Tcl_ListObjAppendElement(interp, listPtr,
						     Tcl_NewIntObj(i+1));
			};
		    } else {
			if (inlineSet) {
			    Tcl_ListObjAppendElement(interp, listPtr,
						     compareListv[i]);
			    Tcl_SetObjResult(interp,listPtr);
			} else {
			    Tcl_SetIntObj (result, i+1);
			}
			return TCL_OK;
		    };
                };
					};

        if (allSet || inlineSet) {
                Tcl_SetObjResult(interp, listPtr);
                return TCL_OK;
        } else {
                Tcl_SetIntObj (result, 0);
                return TCL_OK;
        }
        return TCL_OK;



}


}

# @sak notprovided ipMorec
package provide ipMorec 1.0
