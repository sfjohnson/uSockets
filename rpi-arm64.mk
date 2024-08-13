AR = $(HOME)/aarch64-rpi4-linux-gnu/bin/aarch64-rpi4-linux-gnu-ar
CC = $(HOME)/aarch64-rpi4-linux-gnu/bin/aarch64-rpi4-linux-gnu-gcc
CXX = $(HOME)/aarch64-rpi4-linux-gnu/bin/aarch64-rpi4-linux-gnu-g++

override CXXFLAGS += -ffunction-sections \
-fdata-sections \
-D__aarch64__ \
--sysroot="$(HOME)/aarch64-rpi4-linux-gnu/aarch64-rpi4-linux-gnu/sysroot" \
-B"$(HOME)/aarch64-rpi4-linux-gnu/bin/aarch64-rpi4-linux-gnu-" \
-fPIC \
-Wpedantic \
-Wall

# WITH_OPENSSL=1 enables OpenSSL 1.1+ support or BoringSSL
# For now we need to link with C++ for OpenSSL support, but should be removed with time
ifeq ($(WITH_OPENSSL),1)
	override CFLAGS += -DLIBUS_USE_OPENSSL
	# With problems on macOS, make sure to pass needed LDFLAGS required to find these
	override LDFLAGS += -lssl -lcrypto -lstdc++
else
	# WITH_WOLFSSL=1 enables WolfSSL 4.2.0 support (mutually exclusive with OpenSSL)
	ifeq ($(WITH_WOLFSSL),1)
		# todo: change these
		override CFLAGS += -DLIBUS_USE_WOLFSSL -I/usr/local/include
		override LDFLAGS += -L/usr/local/lib -lwolfssl
	else
		override CFLAGS += -DLIBUS_NO_SSL
	endif
endif

# WITH_LIBUV=1 builds with libuv as event-loop
ifeq ($(WITH_LIBUV),1)
	override CFLAGS += -DLIBUS_USE_LIBUV
	override LDFLAGS += -luv
endif

# WITH_GCD=1 builds with libdispatch as event-loop
ifeq ($(WITH_GCD),1)
	override CFLAGS += -DLIBUS_USE_GCD
	override LDFLAGS += -framework CoreFoundation
endif

# WITH_ASAN builds with sanitizers
ifeq ($(WITH_ASAN),1)
	override CFLAGS += -fsanitize=address -g
	override LDFLAGS += -fsanitize=address
endif

override CFLAGS += -std=c11 -Isrc \
--sysroot="$(HOME)/aarch64-rpi4-linux-gnu/aarch64-rpi4-linux-gnu/sysroot" \
-B"$(HOME)/aarch64-rpi4-linux-gnu/bin/aarch64-rpi4-linux-gnu-"

override LDFLAGS += uSockets.a \
--sysroot="$(HOME)/aarch64-rpi4-linux-gnu/aarch64-rpi4-linux-gnu/sysroot" \
-B"$(HOME)/aarch64-rpi4-linux-gnu/bin/aarch64-rpi4-linux-gnu-"

# By default we build the uSockets.a static library
default:
	rm -f *.o
	$(CC) $(CFLAGS) -O3 -c src/*.c src/eventing/*.c src/crypto/*.c
# For now we do rely on C++17 for OpenSSL support but we will be porting this work to C11
ifeq ($(WITH_OPENSSL),1)
	$(CXX) $(CXXFLAGS) -std=c++17 -O3 -c src/crypto/*.cpp
endif
	$(AR) rvs uSockets.a *.o

# Builds all examples
.PHONY: examples
examples: default
	for f in examples/*.c; do $(CC) -O3 $(CFLAGS) -o $$(basename "$$f" ".c") "$$f" $(LDFLAGS); done

swift_examples:
	swiftc -O -I . examples/swift_http_server/main.swift uSockets.a -o swift_http_server

clean:
	rm -f *.o
	rm -f *.a
	rm -rf .certs
