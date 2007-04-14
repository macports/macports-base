#ifndef _SCRIPT_H_
#define _SCRIPT_H_

int32_t xar_script_in(xar_t x, xar_file_t f, const char *attr, void **in, size_t *inlen);
int32_t xar_script_done(xar_t x, xar_file_t f, const char *attr);

#endif /* _SCRIPT_H_ */
