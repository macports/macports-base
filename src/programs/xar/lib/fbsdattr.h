/*
 * Rob Braun <bbraun@synack.net>
 * 26-Oct-2004
 * Copyright (c) 2004 Rob Braun.  All rights reserved.
 */
#ifndef _XAR_FBSDATTR_H_
#define _XAR_FBSDATTR_H_
int32_t xar_fbsdattr_archive(xar_t x, xar_file_t f, const char* file);
int32_t xar_fbsdattr_extract(xar_t x, xar_file_t f, const char* file);
#endif /* _XAR_FBSDATTR_H_ */
