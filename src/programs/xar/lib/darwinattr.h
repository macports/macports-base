/*
 * Rob Braun <bbraun@synack.net>
 * 23-Apr-2005
 * Copyright (c) 2004 Rob Braun.  All rights reserved.
 */
#ifndef _XAR_DARWINATTR_H_
#define _XAR_DARWINATTR_H_
int32_t xar_underbar_check(xar_t x, xar_file_t f, const char* file);
int32_t xar_darwinattr_archive(xar_t x, xar_file_t f, const char* file);
int32_t xar_darwinattr_extract(xar_t x, xar_file_t f, const char* file);
#endif /* _XAR_DARWINATTR_H_ */
