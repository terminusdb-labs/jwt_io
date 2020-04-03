version   := $(shell swipl -s pack.pl -g 'version(X), writeln(X).' -t halt)
packname  := $(shell basename $$(pwd))

JWTLDFLAGS=$(shell pkg-config --libs libjwt)
JWTCFLAGS=$(shell pkg-config --cflags libjwt)
SSLLDFLAGS=-lssl -lcrypto
SSLCFLAGS=
CFLAGS=-D_GNU_SOURCE $(JWTCFLAGS) $(SSLCFLAGS) -pedantic -Wall -Wno-unused-result -fpic -c
LDFLAGS=$(JWTLDFLAGS) $(SSLLDFLAGS) -shared -Wl,-rpath='$$ORIGIN'

LIBEXT=$(shell swipl -q -g 'current_prolog_flag(shared_object_extension, Ext), writeln(Ext)' -t halt)
LIBNAME=jwt_io
TARGET=lib/x86_64-linux/$(LIBNAME).$(LIBEXT)

testfiles := $(wildcard tests/*.plt)

all: $(TARGET)

$(TARGET): src/$(LIBNAME).o
	gcc $(LDFLAGS) -o $@ $<

%.o: %.c
	swipl-ld $(CFLAGS) $<

check: $(TARGET)$(testfiles)

%.plt: FORCE
	swipl -s $@ -g run_tests -t halt

install:
	mkdir -p $(PACKSODIR)
	cp $(LIBNAME).$(LIBEXT) $(PACKSODIR)
	swipl -q -g 'doc_pack($(packname))' -t halt

FORCE:

clean:
	rm -f src/$(LIBNAME).o $(LIBNAME).$(LIBEXT)
	-rmdir src

make_tgz: FORCE
	rm -f ../$(packname)-$(version).tgz
	find ../$(packname) -name '*.pl' -o -name '*.plt' -o -name '*.pem' -o -name 'rs.*' -o -name 'test_file*' -o -name LICENSE -o -name Makefile -o -name '*.c' -o -name '*.h'|sed -e 's/^...//'|xargs tar cvzfp ../$(packname)-$(version).tgz -C ..

release: check make_tgz clean releasebranch
	mv -n ../$(packname)-$(version).tgz .
	git add $(packname)-$(version).tgz
	git commit -m "release $(version)"

releasebranch: FORCE
	git checkout releases

dockerimage: FORCE
	docker build -t registry.gitlab.com/canbican/jwt_io .
	docker push registry.gitlab.com/canbican/jwt_io

