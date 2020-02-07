SHM_DIR := $(abspath ../)

CC     = clang
CFLAGS = -O3 -Wall -Wextra -fsanitize=address -I$(SHM_DIR)

LIBS = $(SHM_DIR)/libshm_alloc.a

example.out: example.c $(LIBS)
	$(CC) $(CFLAGS) -o $@ $< $(LIBS)

example_with_ptr.out: example_with_ptr.c $(LIBS)
	$(CC) $(CFLAGS) -o $@ $< $(LIBS)

clean:
	rm *.dbgfl *.so *.out *.o .*.swp *.dylib shm_temp_file
