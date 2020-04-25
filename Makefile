version   := $(shell swipl -s pack.pl -g 'version(X), writeln(X).' -t halt)
packname  := $(shell basename $$(pwd))

DOCKER_SWIPL=8.1.12
DOCKER_JANSSON=2.12
DOCKER_LIBJWT=1.12.0

JWTLDFLAGS=$(shell pkg-config --libs libjwt)
JWTCFLAGS=$(shell pkg-config --cflags libjwt)
SSLLDFLAGS=-lssl -lcrypto
SSLCFLAGS=
CFLAGS=-D_GNU_SOURCE $(JWTCFLAGS) $(SSLCFLAGS) -pedantic -Wall -Wno-unused-result -fpic -c
LDFLAGS=$(JWTLDFLAGS) $(SSLLDFLAGS) -shared

LIBEXT=$(shell swipl -q -g 'current_prolog_flag(shared_object_extension, Ext), writeln(Ext)' -t halt)
LIBNAME=jwt_io

testfiles := $(wildcard tests/*.plt)

all: $(LIBNAME).$(LIBEXT)

$(LIBNAME).$(LIBEXT): src/$(LIBNAME).o
	swipl-ld $(LDFLAGS) -o $@ $<

%.o: %.c
	swipl-ld $(CFLAGS) $<

check: $(LIBNAME).$(LIBEXT) $(testfiles)

%.plt: FORCE
	swipl -s $@ -g run_tests -t halt

install:
	mkdir -p $(PACKSODIR)
	cp $(LIBNAME).$(LIBEXT) $(PACKSODIR)
	swipl -q -g 'doc_pack($(packname))' -t halt

FORCE:

clean:
	rm -f src/$(LIBNAME).o $(LIBNAME).$(LIBEXT) Dockerfile .gitlab-ci.yml

make_tgz: FORCE
	rm -f ../$(packname)-$(version).tgz
	find ../$(packname) -name '*.pl' -o -name '*.plt' -o -name '*.pem' -o -name 'rs.*' -o -name 'test_file*' -o -name LICENSE -o -name Makefile -o -name '*.c' -o -name '*.h'|sed -e 's/^...//'|xargs tar cvzfp ../$(packname)-$(version).tgz -C ..

release: check make_tgz clean releasebranch
	mv -n ../$(packname)-$(version).tgz .
	git add $(packname)-$(version).tgz
	git commit -m "release $(version)"

releasebranch: FORCE
	git checkout releases

dockerimage: FORCE Dockerfile
	docker build -t registry.gitlab.com/canbican/jwt_io:$(version) .
	docker push registry.gitlab.com/canbican/jwt_io:$(version)

Dockerfile: Dockerfile.in
	sed -e 's/DOCKER_SWIPL/$(DOCKER_SWIPL)/g' \
		  -e 's/DOCKER_JANSSON/$(DOCKER_JANSSON)/g' \
			-e 's/DOCKER_LIBJWT/$(DOCKER_LIBJWT)/g' \
			-e 's/VERSION/$(version)/g' \
			< $< > $@

.gitlab-ci.yml: .gitlab-ci.yml.in
	sed -e 's/VERSION/$(version)/g' \
			< $< > $@
