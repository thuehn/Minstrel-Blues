#
# Copyright (C) 2017 LEDE project (Denis Roeper)
#
# This is free software, licensed under the GNU General Public License v3.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=lua-argparse
PKG_VERSION:=git
PKG_RELEASE:=1
PKG_MAINTAINER:=Denis Roeper <denis.roeper@posteo.de>
PKG_LICENSE:=GPL-3.0+
PKG_LICENSE_FILES:=LICENSE

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-git.tar.gz
PKG_SOURCE_PROTO:=git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_URL:=https://github.com/mpeterv/argparse.git
PKG_SOURCE_VERSION:=master

include $(INCLUDE_DIR)/package.mk

define Package/lua-argparse
	SUBMENU:=Lua
	SECTION:=lang
	CATEGORY:=Languages
	TITLE:=lua-argparse
	DEPENDS:=+lua
	MAINTAINER:=Denis Roeper <denis.roeper@posteo.de>
	PKGARCH:=all
endef

define Package/lua-argparse/description
  Feature-rich command line parser for Lua 
endef

define Build/Compile
endef


define Package/lua-argparse/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/argparse.lua $(1)/usr/lib/lua
endef

$(eval $(call BuildPackage,lua-argparse))
