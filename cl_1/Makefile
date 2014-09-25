CC = gcc
CFLAGS = -std=gnu99 -lOpenCL -Wall

all: demo

demo: main.o
	$(CC) $(CFLAGS) main.c -o demo

.PHONY: clean
clean:
	rm -rf *o demo
