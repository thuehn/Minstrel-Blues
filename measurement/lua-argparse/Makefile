#
# Copyright (C) 2017 LEDE project (Denis Roeper)
#
# This is free software, licensed under the GNU General Public License v3.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=lua-argparse
PKG_VERSION:=0.1
PKG_RELEASE:=1
PKG_MAINTAINER:=Denis Roeper <denis.roeper@posteo.de>
PKG_LICENSE:=GPL-3.0+
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

define Package/lua-argparse
	SECTION:=LuCI
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=Lua command line arguments parser
	DEPENDS:=+lua
	MAINTAINER:=Denis Roeper <denis.roeper@posteo.de>
	PKGARCH:=all
endef

define Package/lua-argparse/description
Lua command line arguments parser
endef

define Build/Prepare 
	mkdir -p $(PKG_BUILD_DIR)/argparse
	$(CP) -r ./argparse/* $(PKG_BUILD_DIR)/argparse

endef

define Build/Compile

endef


define Package/lua-ex/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/argparse/src/argparse.lua $(1)/usr/lib/lua

endef

$(eval $(call BuildPackage,lua-argpaargparsee))
