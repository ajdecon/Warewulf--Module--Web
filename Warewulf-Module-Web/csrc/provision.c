#include <stdlib.h>
#include <stdio.h>

int main(int argc, char *argv[]) {
	char command[32];
	sprintf(command, "./provision.pl %s", argv[1]);

	setuid(0);
	system(command);
	return 1;
}
