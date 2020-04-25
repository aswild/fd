# Makefile for fd, a wrapper for cargo plus install/dist targets

# don't let make do anything in parallel, cargo build handles that
.NOTPARALLEL:

# install paths
prefix  ?= /usr/local
bindir  ?= $(prefix)/bin
mandir  ?= $(prefix)/man
datadir ?= $(prefix)/share
bashcompdir ?= $(datadir)/bash-completions/completions
fishcompdir ?= $(datadir)/fish/vendor_completions.d/fd.fish
zshcompdir  ?= $(datadir)/zsh/site-functions

# tools
CARGO   ?= cargo
INSTALL ?= install
ifeq ($(NOSTRIP),)
INSTALL_STRIP ?= $(INSTALL) -s
else
INSTALL_STRIP ?= $(INSTALL)
endif
TAR ?= tar

# build configuration
# release build default for install/dist, otherwise debug build
ifneq ($(filter install dist,$(MAKECMDGOALS)),)
BUILD_TYPE ?= release
else
BUILD_TYPE ?= debug
endif
# 'make R=1' as a shortcut for 'make BUILD_TYPE=release'
ifeq ($(R),1)
BUILD_TYPE := release
endif
# set flags for release build
ifeq ($(BUILD_TYPE),release)
CARGO_BUILD_FLAGS += --release --locked
endif

TARGET := target/$(BUILD_TYPE)/fd

# easy hack to avoid re-running cargo when not needed
SOURCES = $(shell find src -type f) build.rs Cargo.toml

.PHONY: build
build: $(TARGET)
$(TARGET): $(SOURCES)
	$(CARGO) build $(CARGO_BUILD_FLAGS)

.PHONY: clean
clean:
	$(CARGO) clean

.PHONY: install
install: $(TARGET)
	$(INSTALL) -d $(DESTDIR)$(bindir)
	$(INSTALL_STRIP) -m755 $(TARGET) $(DESTDIR)$(bindir)/
	$(INSTALL) -Dm644 target/$(BUILD_TYPE)/build/fd-find-*/out/fd.bash $(DESTDIR)$(bashcompdir)/fd
	$(INSTALL) -Dm644 target/$(BUILD_TYPE)/build/fd-find-*/out/fd.fish $(DESTDIR)$(fishcompdir)/fd.fish
	$(INSTALL) -Dm644 target/$(BUILD_TYPE)/build/fd-find-*/out/_fd $(DESTDIR)$(zshcompdir)/_fd
	$(INSTALL) -Dm644 doc/fd.1 $(DESTDIR)$(mandir)/man1/fd.1

.PHONY: dist
dist: fd_version = $(shell $(TARGET) -V | sed 's/^fd //')
dist: $(TARGET)
	$(INSTALL) -d target/dist/$(fd_version)
	$(MAKE) --no-print-directory prefix= DESTDIR=$(PWD)/target/dist/$(fd_version) install
	$(TAR) -cvzf fd-$(fd_version).tar.gz -C target/dist $(fd_version)
