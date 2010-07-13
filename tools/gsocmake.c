#include <unistd.h>

int main(int argc, char *argv[]) {
setuid(geteuid());
system("/usr/local/bin/gsocmake.sh");
return 0;
}
