/*
 * filemap.h
 * $Id: filemap.h,v 1.2 2004/07/01 17:43:20 wbb4 Exp $
 *
 * Copyright (c) 2004 Paul Guyot, Darwinports Team.
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
 * 3. Neither the name of Darwinports Team nor the names of its contributors
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

#ifndef _FILEMAP_H
#define _FILEMAP_H

#include <tcl.h>

/**
 * A native command to handle filemaps.
 * filemaps are dictionaries (what Tcl calls arrays) with case unsensitive keys
 * that are file paths and values that are port names.
 * This object is not thread safe (i.e. calls are not synchronous).
 * Get/Set/Unset operations depend on the number of elements in each directory,
 * they are nevertheless very fast.
 * List is a O(n) operation (the slow operation).
 *
 * The syntax is:
 * filemap open filemapVarName filemapPath
 *	open or create filemap database at filemapPath and put the handle to access
 *	it in variable filemapVarName.
 *	The database should be writable.
 *
 * filemap close filemapVarName
 *	close and save filemap database.
 *
 * filemap exists filemapVarName path
 *	test if a given path exists in the database.
 *
 * filemap get filemapVarName path
 *	return the value associated with a given path in the database.
 *	return an error if the key is not in the database.
 *
 * filemap list filemapVarName value
 *	return a list of all the keys that match with this value.
 *  comparison is case sensitive.
 *
 * filemap revert filemapVarName
 *	revert the filemap to the previous version saved on disk (without closing it)
 *
 * filemap save filemapVarName
 *	save the filemap to disk (without closing it)
 *
 * filemap set filemapVarName path value
 *	set a key,value pair in the database.
 *
 * filemap unset filemapVarName path
 *	remove a key,value pair from the database.
 *
 */
int FilemapCmd(ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);

#endif
		/* _FILEMAP_H */

/* ====================================================================== **
** Has everyone noticed that all the letters of the word "database" are   **
** typed with the left hand?  Now the layout of the QWERTYUIOP typewriter **
** keyboard was designed, among other things, to facilitate the even use  **
** of both hands.  It follows, therefore, that writing about databases is **
** not only unnatural, but a lot harder than it appears.                  **
** ====================================================================== */
