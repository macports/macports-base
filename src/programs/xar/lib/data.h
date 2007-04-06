/*
 * Rob Braun <bbraun@synack.net>
 * 21-Apr-2004
 * Copyright (c) 2004 Rob Braun.  All rights reserved.
 */
#ifndef _XAR_DATA_H_
#define _XAR_DATA_H_
int32_t xar_data_archive(xar_t x, xar_file_t f, const char* file);
int32_t xar_data_extract(xar_t x, xar_file_t f, const char* file);
#endif /* _XAR_DATA_H_ */
