#
# Copyright (C) 2017 LEDE project (Denis Roeper)
#
# This is free software, licensed under the GNU General Public License v3.
#
# file libc.provides should contain libc.so.6
#

include $(TOPDIR)/rules.mk

PKG_NAME:=minstrel-measurement
PKG_VERSION:=0.1
PKG_RELEASE:=1
PKG_MAINTAINER:=Denis Roeper <denis.roeper@posteo.de>
PKG_LICENSE:=GPL-3.0+
PKG_LICENSE_FILES:=LICENSE

#MAKE_PATH:=luarpc

include $(INCLUDE_DIR)/package.mk

define Package/minstrel-measurement
	SUBMENU:=Lua
	SECTION:=lang
	CATEGORY:=Languages
	TITLE:=minstrel-measurement
	DEPENDS:=+lua +lua-rpc +lua-argparse +lua-ex +luaposix +luafilesystem
	MAINTAINER:=Denis Roeper <denis.roeper@posteo.de>
	PKGARCH:=all
endef
#	DEPENDS:=+lua +libc +USE_UCLIBC:librpc

define Package/minstrel-measurement/description
  Minstrel Blues Measurement
endef

define Build/Prepare 
	mkdir -p $(PKG_BUILD_DIR)/parsers 
	mkdir -p $(PKG_BUILD_DIR)/bin 
	mkdir -p $(PKG_BUILD_DIR)/tests 
	$(CP) ./*.lua $(PKG_BUILD_DIR)/
	$(CP) ./bin/* $(PKG_BUILD_DIR)/bin
	$(CP) ./parsers/*.lua $(PKG_BUILD_DIR)/parsers
	$(CP) ./tests/*.lua $(PKG_BUILD_DIR)/tests
endef

define Build/Compile
endef

define Package/minstrel-measurement/install
	$(INSTALL_DIR) $(1)/root
	$(CP) $(PKG_BUILD_DIR)/*.lua $(1)/root
	$(INSTALL_DIR) $(1)/root/parsers
	$(CP) $(PKG_BUILD_DIR)/parsers/*.lua $(1)/root/parsers
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/bin/cpusage_single $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/bin/fetch_file.lua $(1)/usr/bin
	$(INSTALL_DIR) $(1)/root/bin
	$(CP) $(PKG_BUILD_DIR)/bin/* $(1)/root/bin
	$(INSTALL_DIR) $(1)/root/tests
	$(CP) $(PKG_BUILD_DIR)/tests/*.lua $(1)/root/tests

endef

$(eval $(call BuildPackage,minstrel-measurement))
