SUBDIR= doc src

.PHONY : all
.PHONY : clean
.PHONY : install

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
