/*
 * get_systemconfiguration_proxies.c
 *
 * Copyright (c) 2008-2009, The MacPorts Project.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of MacPorts Team nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif


#include "get_systemconfiguration_proxies.h"


#ifdef HAVE_FRAMEWORK_SYSTEMCONFIGURATION
#include <CoreFoundation/CoreFoundation.h>
#include <SystemConfiguration/SystemConfiguration.h>

int appendProxyInformationForKeys( CFDictionaryRef proxies, Tcl_Obj *tclList, const char *listKey, const void *proxyEnabledKey, const void *proxyHostKey, const void *proxyPortKey );
char *cfStringToCStringASCII( CFStringRef cfString );

#endif   /* HAVE_FRAMEWORK_SYSTEMCONFIGURATION */


/**
 *
 * Query SystemConfiguration for proxy information, returning this
 * information in a Tcl list ready to be 'array set' (key, name pairs).
 *
 * Synopsis: array set someArray get_systemconfiguration_proxies
 */
#ifdef HAVE_FRAMEWORK_SYSTEMCONFIGURATION
int GetSystemConfigurationProxiesCmd( ClientData clientData UNUSED, Tcl_Interp *interp, int objc UNUSED, Tcl_Obj *CONST objv[] UNUSED )
#else
int GetSystemConfigurationProxiesCmd( ClientData clientData UNUSED, Tcl_Interp *interp UNUSED, int objc UNUSED, Tcl_Obj *CONST objv[] UNUSED )
#endif
{
    int cmdResult = TCL_OK;
#ifdef HAVE_FRAMEWORK_SYSTEMCONFIGURATION
    CFDictionaryRef proxies = SCDynamicStoreCopyProxies( NULL );
    if( proxies != NULL )
    {
        Tcl_Obj *proxyList = Tcl_NewListObj( 0, NULL );
        if( appendProxyInformationForKeys( proxies, proxyList, "proxy_http", kSCPropNetProxiesHTTPEnable, kSCPropNetProxiesHTTPProxy, kSCPropNetProxiesHTTPPort ) == 0 &&
            appendProxyInformationForKeys( proxies, proxyList, "proxy_https", kSCPropNetProxiesHTTPSEnable, kSCPropNetProxiesHTTPSProxy, kSCPropNetProxiesHTTPSPort ) == 0 &&
            appendProxyInformationForKeys( proxies, proxyList, "proxy_ftp", kSCPropNetProxiesFTPEnable, kSCPropNetProxiesFTPProxy, kSCPropNetProxiesFTPPort ) == 0 )
        {
            CFArrayRef exceptionsCFArray = CFDictionaryGetValue( proxies, kSCPropNetProxiesExceptionsList );
            if( exceptionsCFArray != NULL )
            {
                CFStringRef exceptionsCFString = CFStringCreateByCombiningStrings( kCFAllocatorDefault, exceptionsCFArray, CFSTR( "," ) );
                char *exceptionsString = cfStringToCStringASCII( exceptionsCFString );
                if( exceptionsString != NULL )
                {
                    Tcl_Obj *exceptionsKey = Tcl_NewStringObj( "proxy_skip", 10 );
                    Tcl_Obj *exceptionsTclString = Tcl_NewStringObj( exceptionsString, strlen( exceptionsString ) );
                    Tcl_ListObjAppendElement( interp, proxyList, exceptionsKey );
                    Tcl_ListObjAppendElement( interp, proxyList, exceptionsTclString );
                    free( exceptionsString );
                }
                else
                    cmdResult = TCL_ERROR;
                CFRelease( exceptionsCFString );
            }
            Tcl_SetObjResult( interp, proxyList );
        }
        else
            cmdResult = TCL_ERROR;
        CFRelease( proxies );
    }
    if( cmdResult == TCL_ERROR ) {
        Tcl_SetErrno( errno );
        Tcl_SetResult( interp, (char *) Tcl_PosixError( interp ), TCL_STATIC );
    }
#endif
   return cmdResult;
}


#ifdef HAVE_FRAMEWORK_SYSTEMCONFIGURATION
/**
 *
 * Extract the proxy information (given by proxyEnabledKey, proxyHostKey,
 * and proxyPortKey) from the proxies dictionary, then append listKey and
 * the pertinent proxy information to the Tcl list.
 *
 * Returns 0 on success; -1 on failure
 */
int appendProxyInformationForKeys( CFDictionaryRef proxies, Tcl_Obj *tclList, const char *listKey, const void *proxyEnabledKey, const void *proxyHostKey, const void *proxyPortKey )
{
    int result = 0;
    CFNumberRef proxyEnabledNumber = CFDictionaryGetValue( proxies, proxyEnabledKey );
    int proxyEnabled = 0;
    if( proxyEnabledNumber != NULL &&
        CFNumberGetValue( proxyEnabledNumber, kCFNumberIntType, &proxyEnabled ) &&
        proxyEnabled )
    {
        CFStringRef proxyHostString = CFDictionaryGetValue( proxies, proxyHostKey );
        char *hostname = NULL;
        if( proxyHostString != NULL &&
            ( hostname = cfStringToCStringASCII( proxyHostString ) ) != NULL )
        {
            CFNumberRef proxyPortNumber = CFDictionaryGetValue( proxies, proxyPortKey );
            int proxyPort = 0;
            if( proxyPortNumber != NULL &&
                CFNumberGetValue( proxyPortNumber, kCFNumberIntType, &proxyPort ) &&
                proxyPort > 0 )
            {
                /*
                 * We are adding :<port>\0 to the end, which is up to 7
                 * bytes additional (up to 5 for the port)
                 */
                size_t newLength = strlen( hostname ) + 7;
                char *hostnameAndPort = calloc( 1, newLength );
                if( hostnameAndPort != NULL )
                {
                    Tcl_Obj *hostnameAndPortTcl;
                    Tcl_Obj *listKeyTcl = Tcl_NewStringObj( listKey, strlen( listKey ) );
                    Tcl_ListObjAppendElement( NULL, tclList, listKeyTcl );
                    snprintf( hostnameAndPort, newLength, "%s:%d", hostname, proxyPort );
                    hostnameAndPortTcl = Tcl_NewStringObj( hostnameAndPort, strlen( hostnameAndPort ) );
                    Tcl_ListObjAppendElement( NULL, tclList, hostnameAndPortTcl );
                    free( hostnameAndPort );
                }
                else
                    result = -1;
            }
            else
                result = -1;

            free( hostname );
        }
        else
            result = -1;
    }

    return result;
}


/**
 *
 * Convert a CFStringRef to an ASCII-encoded C string; be sure to free()
 * the returned string when done with it.
 */
char *cfStringToCStringASCII( CFStringRef cfString )
{
    CFIndex strLen = CFStringGetMaximumSizeForEncoding( CFStringGetLength( cfString ), kCFStringEncodingASCII ) + 1;
    char *cString = calloc( 1, (size_t)strLen );
    if( cString != NULL )
        CFStringGetCString( cfString, cString, strLen, kCFStringEncodingASCII );

   return cString;
}

#endif

