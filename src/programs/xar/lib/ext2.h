/*
 * Rob Braun <bbraun@synack.net>
 * 26-Oct-2004
 * Copyright (c) 2004 Rob Braun.  All rights reserved.
 */
#ifndef _XAR_EXT2_H_
#define _XAR_EXT2_H_
#define XAR_ATTR_FORK "attribute"
int xar_ext2attr_archive(xar_t x, xar_file_t f, const char* file);
int xar_ext2attr_extract(xar_t x, xar_file_t f, const char* file);
#endif /* _XAR_EXT2_H_ */
