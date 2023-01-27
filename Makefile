# Makefile for fd, a wrapper for cargo plus install/dist targets

# don't let make do anything in parallel, cargo build handles that
.NOTPARALLEL:

# install paths
prefix  ?= /usr/local
bindir  ?= $(prefix)/bin
datadir ?= $(prefix)/share
mandir  ?= $(datadir)/man
bashcompdir ?= $(datadir)/bash-completion/completions
fishcompdir ?= $(datadir)/fish/vendor_completions.d
zshcompdir  ?= $(datadir)/zsh/site-functions

# tools
CARGO   ?= cargo
INSTALL ?= install
STRIP   ?= strip
ifeq ($(NOSTRIP),)
INSTALL_STRIP ?= $(INSTALL) -s --strip-program=$(STRIP)
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

# whether to run install commands with sudo
ifeq ($(SUDO_INSTALL),1)
INSTALL := sudo $(INSTALL)
endif

ifneq ($(TARGET),)
TARGET_DIR = target/$(TARGET)
CARGO_BUILD_FLAGS += --target $(TARGET)
else
TARGET_DIR = target
TARGET := $(shell ci/default_target.bash)
endif

ifeq ($(findstring windows,$(TARGET)),windows)
EXEEXT := .exe
else
EXEEXT :=
endif

EXE := $(TARGET_DIR)/$(BUILD_TYPE)/fd$(EXEEXT)

# easy hack to avoid re-running cargo when not needed
SOURCES = $(shell find src -type f) build.rs Cargo.toml

.PHONY: build
build: $(EXE)
$(EXE): $(SOURCES)
	$(CARGO) build $(CARGO_BUILD_FLAGS)

.PHONY: clean
clean:
	$(CARGO) clean

.PHONY: completions
completions: autocomplete/fd.bash autocomplete/fd.fish autocomplete/fd.ps1 autocomplete/_fd

comp_dir=@mkdir -p autocomplete

autocomplete/fd.bash: $(EXE)
	$(comp_dir)
	$(EXE) --gen-completions bash > $@

autocomplete/fd.fish: $(EXE)
	$(comp_dir)
	$(EXE) --gen-completions fish > $@

autocomplete/fd.ps1: $(EXE)
	$(comp_dir)
	$(EXE) --gen-completions powershell > $@

autocomplete/_fd: contrib/completion/_fd
	$(comp_dir)
	cp $< $@

.PHONY: install
install: completions
	$(INSTALL) -d $(DESTDIR)$(bindir)
	$(INSTALL_STRIP) -m755 $(EXE) $(DESTDIR)$(bindir)/
	$(INSTALL) -Dm644 autocomplete/fd.bash $(DESTDIR)$(bashcompdir)/fd
	$(INSTALL) -Dm644 autocomplete/fd.fish $(DESTDIR)$(fishcompdir)/fd.fish
	$(INSTALL) -Dm644 autocomplete/_fd $(DESTDIR)$(zshcompdir)/_fd
	$(INSTALL) -Dm644 doc/fd.1 $(DESTDIR)$(mandir)/man1/fd.1

.PHONY: dist
dist: output_file = $(shell  find $(TARGET_DIR)/$(BUILD_TYPE) -path '*/fd-find-*/output' -type f -exec ls -dt {} + | head -n1)
dist: fd_dist_name = fd-$(shell sed -n 's/.*FD_GIT_VERSION=\(.*\)/\1/p' '$(output_file)')-$(TARGET)
dist: $(EXE)
	$(INSTALL) -d $(TARGET_DIR)/dist/$(fd_dist_name)
	$(MAKE) --no-print-directory prefix= DESTDIR=$(PWD)/$(TARGET_DIR)/dist/$(fd_dist_name) install
	$(TAR) -cvzf $(fd_dist_name).tar.gz --owner=root:0 --group=root:0 -C $(TARGET_DIR)/dist $(fd_dist_name)

# this has no dependencies, the build-deb script handles building everything.
# The leading + silences jobserver warnings, since build-deb internally calls "make completions"
.PHONY: deb
deb:
	+ci/build-deb
