##############################################################################
##                                                                          ##
##                              GNATCOLL LIBRARY                            ##
##                                                                          ##
##                         Copyright (C) 2017, AdaCore.                     ##
##                                                                          ##
## This library is free software;  you can redistribute it and/or modify it ##
## under terms of the  GNU General Public License  as published by the Free ##
## Software  Foundation;  either version 3,  or (at your  option) any later ##
## version. This library is distributed in the hope that it will be useful, ##
## but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN# ##
## TABILITY or FITNESS FOR A PARTICULAR PURPOSE.                            ##
##                                                                          ##
## As a special exception under Section 7 of GPL version 3, you are granted ##
## additional permissions described in the GCC Runtime Library Exception,   ##
## version 3.1, as published by the Free Software Foundation.               ##
##                                                                          ##
## You should have received a copy of the GNU General Public License and    ##
## a copy of the GCC Runtime Library Exception along with this program;     ##
## see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    ##
## <http://www.gnu.org/licenses/>.                                          ##
##                                                                          ##
##############################################################################

# Makefile targets
# ----------------
#
# Setup:                   make [VAR=VALUE] setup (see below)
# Build:                   make
# Install:                 make install

# Variables which can be set:
#
# General:
#
#   prefix        : root install directory
#   ENABLE_SHARED : yes / no (or empty)
#   BUILD         : DEBUG PROD
#   PROCESSORS    : nb parallel compilations (0 to use all cores)
#   TARGET        : target triplet for cross-compilation
#   INTEGRATED    : installs the project as part of the compiler installation;
#                   this adds NORMALIZED_TARGET subdir to prefix
#
# Project specific:
#
#   GNATCOLL_MMAP    : whether MMAP is supported (yes/no)
#                      default is "yes"; has no effect on Windows
#   GNATCOLL_MADVISE : whether MADVISE is supported (yes/no)
#                      default is "yes"; has no effect on Windows

# helper programs
CAT := cat
ECHO  := echo
WHICH := which
DESTDIR?=

# check for out-of-tree build
SOURCE_DIR := $(dir $(MAKEFILE_LIST))
ifeq ($(SOURCE_DIR),./)
  RBD=
  GNATCOLL_GPR=gnatcoll.gpr
  MAKEPREFIX=
else
  RBD=--relocate-build-tree
  GNATCOLL_GPR=$(SOURCE_DIR)/gnatcoll.gpr
  MAKEPREFIX=$(SOURCE_DIR)/
endif

TARGET := $(shell gcc -dumpmachine)
NORMALIZED_TARGET := $(subst normalized_target:,,$(wordlist 6,6,$(shell gprconfig  --config=ada --target=$(TARGET) --mi-show-compilers)))
ifeq ($(NORMALIZED_TARGET),)
  $(error No toolchain found for target "$(TARGET)")
endif

GNATCOLL_OS := $(if $(findstring darwin,$(NORMALIZED_TARGET)),osx,$(if $(findstring windows,$(NORMALIZED_TARGET)),windows,unix))

prefix := $(dir $(shell $(WHICH) gnatls))..
GNATCOLL_VERSION := $(shell $(CAT) $(SOURCE_DIR)/version_information)
GNATCOLL_MMAP := yes
GNATCOLL_MADVISE := yes

BUILD         = PROD
PROCESSORS    = 0
BUILD_DIR     =
ENABLE_SHARED = yes
INTEGRATED    = no

all: build

# Load current setup if any
-include makefile.setup

GTARGET=--target=$(NORMALIZED_TARGET)

ifeq ($(ENABLE_SHARED), yes)
   LIBRARY_TYPES=static relocatable
else
   LIBRARY_TYPES=static
endif

ifeq ($(INTEGRATED), yes)
   integrated_install=/$(NORMALIZED_TARGET)
endif


GPR_VARS=-XGNATCOLL_MMAP=$(GNATCOLL_MMAP) \
	 -XGNATCOLL_MADVISE=$(GNATCOLL_MADVISE) \
	 -XGNATCOLL_VERSION=$(GNATCOLL_VERSION) \
	 -XGNATCOLL_OS=$(GNATCOLL_OS) \
	 -XBUILD=$(BUILD)

# Used to pass extra options to GPRBUILD, like -d for instance
GPRBUILD_OPTIONS=

BUILDER=gprbuild -p -m $(GTARGET) $(RBD) -j$(PROCESSORS) $(GPR_VARS) \
	$(GPRBUILD_OPTIONS)
INSTALLER=gprinstall -p -f $(GTARGET) $(GPR_VARS) \
	$(RBD) --sources-subdir=include/gnatcoll --prefix=$(DESTDIR)$(prefix)$(integrated_install)
CLEANER=gprclean -q $(RBD) $(GTARGET)
UNINSTALLER=$(INSTALLER) -p -f --install-name=gnatcoll --uninstall

#########
# build #
#########

build: $(LIBRARY_TYPES:%=build-%)
	make build-rts-adalabs-static

build-%:
	$(BUILDER) -XLIBRARY_TYPE=$* -XXMLADA_BUILD=$* -XGPR_BUILD=$* \
		$(GPR_VARS) $(GNATCOLL_GPR) -XRTS_TYPE=default

build-rts-adalabs-%:
	$(BUILDER) -XLIBRARY_TYPE=$* -XXMLADA_BUILD=$* -XGPR_BUILD=$* \
		$(GPR_VARS) $(GNATCOLL_GPR) -XRTS_TYPE=adalabs --RTS=adalabs


###########
# Install #
###########

uninstall:
ifneq (,$(wildcard $(DESTDIR)$(prefix)$(integrated_install)/share/gpr/manifests/gnatcoll))
	$(UNINSTALLER) $(GNATCOLL_GPR)
endif

install: uninstall $(LIBRARY_TYPES:%=install-%)
	make install-rts-adalabs-static
	mkdir -p $(DESTDIR)$(prefix)/bin
	sed -i 's/with \"gpr\";/with \"gpr\";\nwith \"rts\";/' $(DESTDIR)$(prefix)/share/gpr/gnatcoll.gpr
	sed -i 's/BUILD : BUILD_KIND := external(\"GNATCOLL_CORE_BUILD\", external(\"GNATCOLL_BUILD\", external(\"LIBRARY_TYPE\", \"static\")));/BUILD : BUILD_KIND := external(\"GNATCOLL_CORE_BUILD\", external(\"GNATCOLL_BUILD\", \"static\"));/' $(DESTDIR)$(prefix)/share/gpr/gnatcoll.gpr
	sed -i 's/for Languages use (\"Ada\", \"C\");/for Languages use (\"Ada\", \"C\");\n   case RTS.RTS_Type is\n      when \"adalabs\" =>\n         BUILD := \"rts-adalabs\";\n      when others =>\n         null;\n   end case;/'    $(DESTDIR)$(prefix)/share/gpr/gnatcoll.gpr

install-%:
	$(INSTALLER) -XLIBRARY_TYPE=$* -XXMLADA_BUILD=$* -XGPR_BUILD=$* \
		--build-name=$* $(GPR_VARS) \
		--build-var=LIBRARY_TYPE --build-var=GNATCOLL_BUILD \
		--build-var=GNATCOLL_CORE_BUILD $(GNATCOLL_GPR) -XRTS_TYPE=default

install-rts-adalabs-%:
	$(INSTALLER) -XLIBRARY_TYPE=$* -XXMLADA_BUILD=$* -XGPR_BUILD=$* \
		--build-name=rts-adalabs $(GPR_VARS) \
		--build-var=LIBRARY_TYPE --build-var=GNATCOLL_BUILD \
		--build-var=GNATCOLL_CORE_BUILD $(GNATCOLL_GPR) -XRTS_TYPE=adalabs --RTS=adalabs


###########
# Cleanup #
###########

clean: $(LIBRARY_TYPES:%=clean-%)
	make clean-rts-adalabs-static

clean-%:
	-$(CLEANER) -XLIBRARY_TYPE=$* -XXMLADA_BUILD=$* -XGPR_BUILD=$* \
		$(GPR_VARS) $(GNATCOLL_GPR)

clean-rts-adalabs-%:
	-$(CLEANER) -XLIBRARY_TYPE=$* -XXMLADA_BUILD=$* -XGPR_BUILD=$* \
		$(GPR_VARS) $(GNATCOLL_GPR) -XRTS_TYPE=adalabs --RTS=adalabs



#########
# setup #
#########

.SILENT: setup

setup:
	$(ECHO) "prefix=$(DESTDIR)$(prefix)" > makefile.setup
	$(ECHO) "ENABLE_SHARED=$(ENABLE_SHARED)" >> makefile.setup
	$(ECHO) "INTEGRATED=$(INTEGRATED)" >> makefile.setup
	$(ECHO) "BUILD=$(BUILD)" >> makefile.setup
	$(ECHO) "PROCESSORS=$(PROCESSORS)" >> makefile.setup
	$(ECHO) "TARGET=$(TARGET)" >> makefile.setup
	$(ECHO) "SOURCE_DIR=$(SOURCE_DIR)" >> makefile.setup
	$(ECHO) "GNATCOLL_OS=$(GNATCOLL_OS)" >> makefile.setup
	$(ECHO) "GNATCOLL_VERSION=$(GNATCOLL_VERSION)" >> makefile.setup
	$(ECHO) "GNATCOLL_MMAP=$(GNATCOLL_MMAP)" >> makefile.setup
	$(ECHO) "GNATCOLL_MADVISE=$(GNATCOLL_MADVISE)" >> makefile.setup

# Let gprbuild handle parallelisation. In general, we don't support parallel
# runs in this Makefile, as concurrent gprinstall processes may crash.
.NOTPARALLEL:
