.PHONY: all build-x86_64-linux build-aarch64-linux build-x86_64-macos build-aarch64-macos build-installer clean

BUILD_DIR := build
VERSION ?= $(shell git rev-parse --short HEAD || echo unknown)
VERSION := $(patsubst v%,%,$(VERSION))

all: build-x86_64-linux build-aarch64-linux build-x86_64-macos build-aarch64-macos build-installer

build-x86_64-linux:
	zig build --release=small --prefix $(BUILD_DIR)/x86_64-linux -Dtarget=x86_64-linux -Dversion=$(VERSION)

build-aarch64-linux:
	zig build --release=small --prefix $(BUILD_DIR)/aarch64-linux -Dtarget=aarch64-linux -Dversion=$(VERSION)

build-x86_64-macos:
	zig build --release=small --prefix $(BUILD_DIR)/x86_64-macos -Dtarget=x86_64-macos -Dversion=$(VERSION)

build-aarch64-macos:
	zig build --release=small --prefix $(BUILD_DIR)/aarch64-macos -Dtarget=aarch64-macos -Dversion=$(VERSION)

build-installer:
	sed -e 's|$${RESGR_LATEST_VERSION:-latest}|$(VERSION)|g' install.sh > $(BUILD_DIR)/install.sh

clean:
	rm -rf $(BUILD_DIR)
