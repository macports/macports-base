/*
 * Rob Braun <bbraun@synack.net>
 * 26-Oct-2004
 * Copyright (c) 2004 Rob Braun.  All rights reserved.
 */
#ifndef _XAR_LINUXATTR_H_
#define _XAR_LINUXATTR_H_
int32_t xar_linuxattr_archive(xar_t x, xar_file_t f, const char* file);
int32_t xar_linuxattr_extract(xar_t x, xar_file_t f, const char* file);
#endif /* _XAR_LINUXATTR_H_ */
