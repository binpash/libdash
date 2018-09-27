ACLOCAL_AMFLAGS=-I m4

SUBDIRS = src

lib : libdash.a libdash.so.1.0.1

libdash.a : 
	ar rcs $@ src/*.o

libdash.so.1.0.1 : 
	gcc -shared -o $@ src/*.o
