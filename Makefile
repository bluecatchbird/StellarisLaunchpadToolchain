BASE                = $(PWD)
PREFIX              = $(BASE)/output
SOURCE              = $(BASE)/source/
TARGET              = arm-none-eabi
JOBS                = $(shell cat /proc/cpuinfo | grep MHz | wc -l)
MAKE                = PATH=$(PREFIX)/bin:$${PATH} make -j $(JOBS)

# newlib needs makeinfo from texinfo sources
TEXINFO_VERSION     = 5.2
TEXINFO_DIR         = $(SOURCE)/texinfo-$(TEXINFO_VERSION)/

BINUTILS_VERSION     = 2.22
BINUTILS_DIR         = $(SOURCE)/binutils-$(BINUTILS_VERSION)/

GCC_VERSION          = 4.9.0
GCC_DIR              = $(SOURCE)/gcc-$(GCC_VERSION)/

LM4TOOLS_BRANCH      = master
LM4TOOLS_DIR         = $(SOURCE)/lm4tools-$(LM4TOOLS_BRANCH)/

STELLARISWARE_BRANCH = master
STELLARISWARE_DIR    = $(SOURCE)/stellarisWare-$(STELLARISWARE_BRANCH)/

GDB_VERSION      = 7.8
GDB_DIR          = $(SOURCE)/gdb-$(GDB_VERSION)/

NEWLIB_VERSION   = 2.1.0
NEWLIB_DIR       = $(SOURCE)/newlib-$(NEWLIB_VERSION)/
# patch for the missing header
define NEWLIB_PATCH
--- libgloss/arm/cpu-init/Makefile.in	2013-10-14 17:15:12.000000000 +0200
+++ libgloss/arm/cpu-init/Makefile.in	2014-10-17 21:38:32.623317260 +0200
@@ -18,6 +18,7 @@
 tooldir = $(exec_prefix)/$(target_alias)
 
 objtype = @objtype@
+host_makefile_frag = /../../config/default.mh
 
 INSTALL = @INSTALL@
 INSTALL_PROGRAM = @INSTALL_PROGRAM@
@@ -80,7 +81,7 @@
 install-info:
 clean-info:
 
-Makefile: Makefile.in ../config.status @host_makefile_frag_path@
+Makefile: Makefile.in ../config.status $${host_makefile_frag_path}
 	$$(SHELL) ../config.status --file cpu-init/Makefile
 
 ../config.status: ../configure
endef




all: toolchain flashtools debugtools

toolchain: texinfo binutils gcc-initial newlib gcc-final

flashtools: lm4tools

debugtools: gdb

example: flash-blinky





texinfo:
	cd $(TEXINFO_DIR) && ./configure \
	  --prefix=$(PREFIX)
	$(MAKE) -C $(TEXINFO_DIR) all
	$(MAKE) -C $(TEXINFO_DIR) install

binutils:
	cd $(BINUTILS_DIR) && ./configure  \
	  --target=$(TARGET) \
	  --prefix=$(PREFIX) \
	  --disable-nls	     \
	  --enable-multilib  \
	  --with-gnu-as	     \
	  --with-gnu-ld	     \
	  --disable-libssp   \
	  --disable-werror
	$(MAKE) -C $(BINUTILS_DIR) all
	$(MAKE) -C $(BINUTILS_DIR) install


gcc-initial:
	mkdir -p $(GCC_DIR)/build
	cd $(GCC_DIR)/build && PATH=$(PREFIX)/bin:$${PATH} ../configure	\
	  --target=$(TARGET)	    \
	  --prefix=$(PREFIX)	    \
	  --enable-languages=c	    \
	  --disable-bootstrap	    \
	  --disable-libgomp         \
	  --disable-libmudflap	    \
	  --enable-multilib	        \
	  --disable-libphobos 	    \
	  --disable-decimal-float   \
	  --disable-libffi	        \
	  --disable-libmudflap	    \
	  --disable-libquadmath	    \
	  --disable-libssp	        \
	  --disable-libstdcxx-pch   \
	  --disable-nls		        \
	  --disable-shared	        \
	  --disable-threads	        \
	  --disable-tls		        \
	  --with-gnu-as		        \
	  --with-gnu-ld		        \
	  --with-cpu=cortex-m4	    \
	  --with-tune=cortex-m4	    \
	  --with-mode=thumb	        \
	  --with-newlib             \
	  --with-headers=$(NEWLIB_DIR)/newlib/libc/include/
	$(MAKE) -C $(GCC_DIR)/build/ all-gcc 
	$(MAKE) -C $(GCC_DIR)/build/ install-gcc

gcc-final:
	$(MAKE) -C $(GCC_DIR)/build/ all
	$(MAKE) -C $(GCC_DIR)/build/ install

lm4tools:
	echo "lm4tools needs libusb dev and pkg(try apt-get install libusb-dev pkg)"
	make -C $(LM4TOOLS_DIR)/lm4flash
	cp $(LM4TOOLS_DIR)/lm4flash/lm4flash $(PREFIX)/bin/
	
stellarisWare:
	$(MAKE) -C $(STELLARISWARE_DIR)/boards/ek-lm4fl20xl/blinky 

newlib:
	cd $(NEWLIB_DIR) && PATH=$${PATH}/:$(PREFIX)/bin/ ./configure \
	  --target=$(TARGET) \
	  --prefix=$(PREFIX) \
	  --enable-multilib \
	  --disable-libssp \
	  --disable-nls
	$(MAKE) -C $(NEWLIB_DIR) all
	# use normal make without jobs because of issues with multiple jobs
	PATH=$(PREFIX)/bin:$${PATH} make -C $(NEWLIB_DIR) install

gdb:
	cd $(GDB_DIR) && ./configure \
	  --target=$(TARGET) \
	  --prefix=$(PREFIX) \
	  --enable-interwork \
	  --enable-multilib
	$(MAKE) -C $(GDB_DIR) all
	$(MAKE) -C $(GDB_DIR) install

blinky:
	$(MAKE) -C $(STELLARISWARE_DIR)/boards/ek-lm4f120xl/blinky/

flash-blinky: blinky
	$(PREFIX)/bin/lm4flash $(STELLARISWARE_DIR)/boards/ek-lm4f120xl/blinky/gcc/blinky.bin

initial: export NEWLIB_PATCH:=$(NEWLIB_PATCH)
initial:
	mkdir -p $(SOURCE) $(PREFIX)
	wget http://ftp.gnu.org/gnu/texinfo/texinfo-$(TEXINFO_VERSION).tar.gz -O-              | tar xz  -C $(SOURCE)
	wget http://ftp.gnu.org/gnu/binutils/binutils-$(BINUTILS_VERSION).tar.bz2 -O-          | tar xj -C $(SOURCE)
	wget http://ftp.gnu.org/gnu/gcc/gcc-$(GCC_VERSION)/gcc-$(GCC_VERSION).tar.bz2 -O-      | tar xj -C $(SOURCE)
	cd $(GCC_DIR) && ./contrib/download_prerequisites
	wget http://ftp.gnu.org/gnu/gdb/gdb-$(GDB_VERSION).tar.gz -O-                          | tar xz -C $(SOURCE)
	wget ftp://sourceware.org/pub/newlib/newlib-$(NEWLIB_VERSION).tar.gz -O-               | tar xz -C $(SOURCE)
	echo "$${NEWLIB_PATCH}" | patch -p0 -d $(NEWLIB_DIR) --verbose
	git clone https://github.com/yuvadm/stellaris.git -b $(STELLARISWARE_BRANCH)           $(STELLARISWARE_DIR)
	git clone https://github.com/utzig/lm4tools.git   -b $(LM4TOOLS_BRANCH)                $(LM4TOOLS_DIR)
	@echo "ready, you can build now with \"make all\""

distclean: clean
	rm -rf $(SOURCE)/*
	
clean:
	make clean -C $(BINUTILS_DIR)                                  || echo "ignore error"
	make clean -C $(NEWLIB_DIR)                                    || echo "ignore error"
	make clean -C $(OPENOCD_DIR)                                   || echo "ignore error"
	make clean -C $(GDB_DIR)                                       || echo "ignore error"
	make clean -C $(STELLARISWARE_DIR)/boards/ek-lm4f120xl/blinky/ || echo "ignore error"
	make clean -C $(GCC_DIR)/build/                                || echo "ignore error"
	rm -rf $(GCC_DIR)/build/*
	rm -rf $(PREFIX)/*

help:
	@echo "run \"make initial\" to download the sources"
	@echo "run \"make\" to build all"
