#
# Copyright (C) 2017 LEDE project (Denis Roeper)
#
# This is free software, licensed under the GNU General Public License v3.
#
# file libc.provides should contain libc.so.6
#

include $(TOPDIR)/rules.mk
#include $(INCLUDE_DIR)/uclibc++.mk

PKG_NAME:=minstrel-measurement
PKG_VERSION:=0.1
PKG_RELEASE:=1
PKG_MAINTAINER:=Denis Roeper <denis.roeper@posteo.de>
PKG_LICENSE:=GPL-3.0+
PKG_LICENSE_FILES:=LICENSE

#MAKE_PATH:=luarpc

include $(INCLUDE_DIR)/package.mk

define Package/minstrel-measurement
	SECTION:=LuCI
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=Minstrel (Blues) Measurement
	DEPENDS:=+lua
	MAINTAINER:=Denis Roeper <denis.roeper@posteo.de>
	PKGARCH:=all
endef
#	DEPENDS:=+lua +libc +USE_UCLIBC:librpc

define Package/minstrel-measurement/description
Minstrel Blues Measurement
endef

define Build/Prepare 
	mkdir -p $(PKG_BUILD_DIR)/luarpc 
	mkdir -p $(PKG_BUILD_DIR)/parsers 
	mkdir -p $(PKG_BUILD_DIR)/bin 
	mkdir -p $(PKG_BUILD_DIR)/tests 
	$(CP) ./luarpc/* $(PKG_BUILD_DIR)/luarpc
	$(CP) ./*.lua $(PKG_BUILD_DIR)/
	$(CP) ./parsers/*.lua $(PKG_BUILD_DIR)/parsers
	$(CP) ./tests/*.lua $(PKG_BUILD_DIR)/tests

endef

define Build/Compile
	echo $(TARGET_CFLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/luarpc \
		CC="$(TARGET_CC) $(TARGET_CFLAGS) -s" \
		PRECOMPILED_FILTER=1 \
		STAGING_DIR="$(STAGING_DIR)" \
		socket

endef
#		CFLAGS="$(TARGET_CFLAGS)" \
#		CC="$(TARGET_CC)" \
#		$(MAKE_FLAGS) \


define Package/minstrel-measurement/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/luarpc/rpc.so $(1)/usr/lib/lua
	$(INSTALL_DIR) $(1)/root
	$(CP) $(PKG_BUILD_DIR)/*.lua $(1)/root
	$(INSTALL_DIR) $(1)/root/parsers
	$(CP) $(PKG_BUILD_DIR)/parsers/*.lua $(1)/root/parsers
	$(INSTALL_DIR) $(1)/usr/bin
	$(CP) $(PKG_BUILD_DIR)/bin/cpusage_single $(1)/usr/bin
	$(CP) $(PKG_BUILD_DIR)/bin/fetch_file.lua $(1)/usr/bin
	$(INSTALL_DIR) $(1)/root/tests
	$(CP) $(PKG_BUILD_DIR)/tests/*.lua $(1)/root/tests
endef

$(eval $(call BuildPackage,minstrel-measurement))
