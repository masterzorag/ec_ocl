CC = gcc
CFLAGS = -std=gnu99 -lOpenCL -Wall

all: demo

# clang -S -emit-llvm -o test.ll -x cl test.cl
# gcc -o demo main.c -Wall -std=gnu99 -lOpenCL

#demo_amd: main.o
#	$(CC) -v $(CFLAGS) main.c \

#gcc -o demo_amd main.c -Wall -std=gnu99 \
#        -I/opt/AMDAPPSDK-2.9-1/lib \
#        -L/opt/AMDAPPSDK-2.9-1/lib/x86/libOpenCL.so -lrt -Wl,-rpath,/opt/AMDAPPSDK-2.9-1/lib/x86 -lOpenCL

demo: main.o
	$(CC) $(CFLAGS) main.c -o demo

.PHONY: clean
clean:
	rm -rf *o demo*
