# This is a BSD make file - please run it with bsdmake.

SUBDIR= doc src
all:
	@for subdir in $(SUBDIR); do\
		echo making $@ in $$subdir; \
		( cd $$subdir && $(MAKE) $@) || exit 1; \
	done

clean:
	@for subdir in $(SUBDIR); do\
		echo making $@ in $$subdir; \
		( cd $$subdir && $(MAKE) $@) || exit 1; \
	done

install:
	@for subdir in $(SUBDIR); do\
		echo making $@ in $$subdir; \
		( cd $$subdir && $(MAKE) $@) || exit 1; \
	done
