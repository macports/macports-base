#ifdef __MACH__

#include <libmachista.h>
#include <limits.h>
#include <mach-o/arch.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#define TEST_LIB_PATH "tests/libmachista-test-lib.dylib"
#define OTOOL_PATH "/usr/bin/otool"

// check helper
static bool check(bool condition, char *msg) {
	if (!condition)
		printf("Assertion failed: %s\n", msg);
	return condition;
}

// forking helper
static bool fork_test(void (*fp)(void), char *msg) {
	pid_t p = fork();

	switch (p) {
		case -1:
			perror("\tfork");
			return false;
		case 0:
			fp();
			exit(EXIT_SUCCESS);
			break;
		default: {
			int status;
			if (p != waitpid(p, &status, 0)) {
				perror("\twaitpid");
				return false;
			}
			if (WIFSIGNALED(status)) {
				printf("\tProcess was terminated by signal %d: %s\n", WTERMSIG(status), msg);
				return false;
			}
			if (WIFEXITED(status) && WEXITSTATUS(status) != 0) {
				printf("\tProcess was terminated with non-zero return value %d: %s\n", WEXITSTATUS(status), msg);
				return false;
			}
		}
	}

	return true;
}

#define nullterminate(x) do { \
	x[sizeof(x) - 1] = '\0'; \
} while (false);

// otool call helper
static bool compare_to_otool_output(char *path, const macho_t *ref) {
	FILE *tmpf = tmpfile();
	int tmpfd;
	if (tmpf == NULL) {
		perror("\ttmpfile");
		return false;
	}

	tmpfd = fileno(tmpf);

	pid_t p = fork();
	switch (p) {
		case -1:
			perror("\tfork");
			goto error_out;
		case 0:
			if (-1 == dup2(tmpfd, STDOUT_FILENO)) {
				perror("\tdup2");
				exit(EXIT_FAILURE);
			}
			execl(OTOOL_PATH, OTOOL_PATH, "-L", "-arch", "all", path, NULL);
			perror("\texecl");
			exit(EXIT_FAILURE);
		default: {
			int status;
			if (p != waitpid(p, &status, 0)) {
				perror("\twaitpid");
				goto error_out;
			}
			if (WIFSIGNALED(status)) {
				fprintf(stderr, "\totool was signaled by signal %d\n", WTERMSIG(status));
				goto error_out;
			}
			if (WIFEXITED(status) && WEXITSTATUS(status) != 0) {
				fprintf(stderr, "\totool terminated with non-zero return value %d\n", WEXITSTATUS(status));
				goto error_out;
			}
		}
	}

	rewind(tmpf);

	size_t libmachista_archs = 0;
	for (macho_arch_t *mat = ref->mt_archs; mat; mat = mat->next) {
		libmachista_archs++;
	}
	size_t found_archs = 0;

	while (!feof(tmpf)) {
		char architecture_name[32];
		char install_name[_POSIX_PATH_MAX];
		char compatibility_version[256];
		char current_version[256];

		// discard header line, read architecture
		if (1 != fscanf(tmpf, "%*s (architecture %31[^)]):", architecture_name)) {
			fprintf(stderr, "\tError getting arch header from otool output\n");
			goto error_out;
		}
		nullterminate(architecture_name);
		//printf("\tarch: %s\n", architecture_name);

		// search for the found architecture in libmachista output
		const NXArchInfo *archInfo = NXGetArchInfoFromName(architecture_name);	
		if (!archInfo) {
			fprintf(stderr, "\tUnknown arch string in otool output: `%s'\n", architecture_name);
			goto error_out;
		}
		macho_arch_t *mat;
		for (mat = ref->mt_archs; mat; mat = mat->next) {
			if (archInfo->cputype == mat->mat_arch) {
				found_archs++;
				break;
			}
		}
		if (mat == NULL) {
			printf("\tArchitecture `%s' found by otool not in libmachista output\n", architecture_name);
			goto error_out;
		}

		// get install name
		if (3 != fscanf(tmpf, "%*[\n]%*[\t]%255s (compatibility version %255[^,], current version %255[^)])", install_name, compatibility_version, current_version)) {
			fprintf(stderr, "\tError getting install name from otool output\n");
			goto error_out;
		}
		nullterminate(install_name);
		nullterminate(compatibility_version);
		nullterminate(current_version);

		// format compatibility version for easier comparison
		char *ref_current_version = macho_format_dylib_version(mat->mat_version);
		char *ref_compatibility_version = macho_format_dylib_version(mat->mat_comp_version);

		// compare compatibility versions
		if (strcmp(current_version, ref_current_version) != 0) {
			printf("\tCurrent version mismatch. Expected `%s', was `%s'\n", current_version, ref_current_version);
			exit(EXIT_FAILURE);
		}
		if (strcmp(compatibility_version, ref_compatibility_version) != 0) {
			printf("\tCurrent version mismatch. Expected `%s', was `%s'\n", compatibility_version, ref_compatibility_version);
			exit(EXIT_FAILURE);
		}

		free(ref_current_version);
		free(ref_compatibility_version);

		// loop through loadcommands
		size_t libmachista_libs = 0;
		for (macho_loadcmd_t *mlt = mat->mat_loadcmds; mlt; mlt = mlt->next) {
			libmachista_libs++;
		}
		size_t found_libs = 0;

		do {
			char lib_path[_POSIX_PATH_MAX];
			char lib_comp_version[256];
			char lib_curr_version[256];

			// read loadcommand output line from otool
			if (3 != fscanf(tmpf, "%*[\n]%*[\t]%255s (compatibility version %255[^,], current version %255[^),]%*[^\n]", lib_path, lib_comp_version, lib_curr_version)) {
				// error out silently, probably been the last line
				break;
			}

			nullterminate(lib_path);
			nullterminate(lib_comp_version);
			nullterminate(lib_curr_version);

			//printf("\t\t%s, %s, %s\n", lib_path, lib_comp_version, lib_curr_version);

			// try to find the library in this architecture's list of loadcommands
			macho_loadcmd_t *mlt;
			for (mlt = mat->mat_loadcmds; mlt; mlt = mlt->next) {
				if (strcmp(mlt->mlt_install_name, lib_path) == 0) {
					// found library
					found_libs++;

					// check versions
					char *ref_lib_curr_version = macho_format_dylib_version(mlt->mlt_version);
					char *ref_lib_comp_version = macho_format_dylib_version(mlt->mlt_comp_version);

					if (strcmp(lib_comp_version, ref_lib_comp_version) != 0) {
						printf("\tLibrary compatibility version mismatch. Expected `%s', was `%s'\n", lib_comp_version, ref_lib_comp_version);
						exit(EXIT_FAILURE);
					}
					if (strcmp(lib_curr_version, ref_lib_curr_version) != 0) {
						printf("\tLibrary current version mismatch. Expected `%s', was `%s'\n", lib_curr_version, ref_lib_curr_version);
						exit(EXIT_FAILURE);
					}

					free(ref_lib_curr_version);
					free(ref_lib_comp_version);
					break;
				}
			}
			if (mlt == NULL) {
				printf("\tLoadcommand for file `%s' found by otool not present in libmachista output\n", lib_path);
				exit(EXIT_FAILURE);
			}
		} while (true);

		// make sure we found the exact same number of loadcommands
		if (libmachista_libs != found_libs) {
			printf("\totool didn't return all libs found by libmachista. Was: %zu, expected %zu\n", found_libs, libmachista_libs);
			exit(EXIT_FAILURE);
		}
	}

	// make sure we found the exact same number of architectures
	if (libmachista_archs != found_archs) {
		printf("\totool didn't return all architectures found by libmachista. Was: %zu, expected %zu\n", found_archs, libmachista_archs);
	}

	// if we arrive here, everything went fine
	return true;

error_out:
	fclose(tmpf);
	return false;
}

/**
 * Test creating and destroying a handle
 */
static void forked_test_handle(void) {
	macho_handle_t *handle = macho_create_handle();
	bool result = check(handle != NULL, "Error creating handle (epxected non-NULL, but was NULL)");
	macho_destroy_handle(handle);
	exit(!result);
}
static bool test_handle(void) {
	puts("Testing creating and destroying handles");
	if (fork_test(forked_test_handle, "Error creating or destroying handle")) {
		puts("\tOK");
		return true;
	}
	puts("\tError");
	return false;
}


/**
 * Test destroying a NULL handle
 */
static void forked_test_destroy_null(void) {
	macho_destroy_handle(NULL);
	exit(EXIT_SUCCESS);
}
static bool test_destroy_null(void) {
	puts("Testing destroying NULL handle");
	if (fork_test(forked_test_destroy_null, "Error destroying NULL handle")) {
		puts("\tOK");
		return true;
	}
	puts("\tError");
	return false;
}

/**
 * Test reading TEST_LIB_PATH
 */
static void forked_test_libsystem(void) {
	macho_handle_t *handle = macho_create_handle();
	const macho_t *result;
	int ret = 0;

	// parse file
	if ((ret = macho_parse_file(handle, TEST_LIB_PATH, &result)) != MACHO_SUCCESS) {
		printf("\tError parsing `%s': %s\n", TEST_LIB_PATH, macho_strerror(ret));
	}

	// get otool reference output
	bool success = compare_to_otool_output(TEST_LIB_PATH, result);

	macho_destroy_handle(handle);
	
	exit(!success);
}
static bool test_libsystem(void) {
	puts("Testing parsing " TEST_LIB_PATH);
	if (fork_test(forked_test_libsystem, "Error parsing " TEST_LIB_PATH)) {
		puts("\tOK");
		return true;
	}
	puts("\tError");
	return false;
}

/**
 * Test macho_format_dylib_version
 */
static bool test_format_dylib_version(void) {
	puts("Testing macho_format_dylib_version");

	char *version_string;

	// testing range
	version_string = macho_format_dylib_version(0xffffffff);
	if (strcmp(version_string, "65535.255.255") != 0) {
		printf("\tmacho_format_dylib_version(0xffffffff) should be 65535.255.255, but is `%s'\n", version_string);
		goto error_out;
	}
	free(version_string);

	version_string = macho_format_dylib_version(0x80008080);
	if (strcmp(version_string, "32768.128.128") != 0) {
		printf("\tmacho_format_dylib_version(0x80008080) should be 32768.128.128, but is `%s'\n", version_string);
		goto error_out;
	}
	free(version_string);

	version_string = macho_format_dylib_version(0x1);
	if (strcmp(version_string, "0.0.1") != 0) {
		printf("\tmacho_format_dylib_version(0x1) should be 0.0.1, but is `%s'\n", version_string);
		goto error_out;
	}
	free(version_string);

	puts("\tOK");
	return true;
error_out:
	puts("\tError");
	free(version_string);
	return false;
}
#endif

int main() {
#ifdef __MACH__
	bool result = true;
	result &= test_destroy_null();
	result &= test_handle();
	result &= test_format_dylib_version();
	result &= test_libsystem();
	return !result;
#else
	return 0;
#endif
}

