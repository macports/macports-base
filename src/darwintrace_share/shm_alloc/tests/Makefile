SHM_DIR := $(abspath ../)

CC      = clang
CFLAGS  = -O3 -D TEST_THE_TEST=0 -Wall -Wextra -fsanitize=address -I$(SHM_DIR)

LIBS = $(SHM_DIR)/libshm_alloc.a
OBJS = rand_string_generator.o

test_shm_alloc.out: test_shm_alloc.c $(LIBS) $(OBJS)
	$(CC) $(CFLAGS) -o $@ $< $(OBJS) $(LIBS)

clean:
	rm *.dbgfl *.so *.out *.o .*.swp *.dylib "test_shm_file"
