SHM_DIR  := ../../shm_alloc/
TRIE_DIR := ../
SRC_DIR  := ../../../

CC     = clang
CFLAGS = -O3 -Wall -Wextra -fsanitize=address -I$(TRIE_DIR) -I$(SHM_DIR) -I$(SRC_DIR)

OBJS = rand_string_generator.o
LIBS = \
	$(SHM_DIR)libshm_alloc.a \
	$(TRIE_DIR)libtrie.a

test_trie.out: test_trie.c $(LIBS) $(OBJS)
	$(CC) $(CFLAGS) -o $@ $< $(OBJS) $(LIBS)

clean:
	rm *.dbgfl *.so *.out *.o .*.swp *.dylib "test_shm_file"

