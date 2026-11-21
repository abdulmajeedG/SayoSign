CC ?= cc
CFLAGS ?= -O2 -g -Wall -Wextra -Wno-unused-parameter -Wno-sign-compare
LIBS := -lcrypto -lz -llzma
ifeq ($(shell uname -s),Darwin)
LIBS += -lcompression
endif
CORE_SRC := $(wildcard core/src/*.c)
CORE_OBJ := $(patsubst core/src/%.c,build/core/%.o,$(CORE_SRC))

all: build/sayosign

build/core/%.o: core/src/%.c core/include/sayo.h core/src/internal.h
	@mkdir -p build/core
	$(CC) $(CFLAGS) -D_GNU_SOURCE -Icore/include -c $< -o $@

build/libsayocore.a: $(CORE_OBJ)
	ar rcs $@ $^

build/sayosign: cli/main.c build/libsayocore.a
	$(CC) $(CFLAGS) -Icore/include $< build/libsayocore.a $(LDFLAGS) $(LIBS) -o $@

clean:
	rm -rf build

.PHONY: all clean
