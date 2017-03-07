#
# Copyright (C) 2017 LEDE project (Denis Roeper)
#
# This is free software, licensed under the GNU General Public License v3.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=lua-pprint
PKG_VERSION:=0.1
PKG_RELEASE:=1
PKG_MAINTAINER:=Denis Roeper <denis.roeper@posteo.de>
PKG_LICENSE:=GPL-3.0+
PKG_LICENSE_FILES:=LICENSE

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-git.tar.gz
PKG_SOURCE_PROTO:=git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_URL:=https://github.com/jagt/pprint.lua.git
PKG_SOURCE_VERSION:=master

include $(INCLUDE_DIR)/package.mk

define Package/lua-pprint
	SUBMENU:=Lua
	SECTION:=lang
	CATEGORY:=Languages
	TITLE:=lua-pprint
	DEPENDS:=+lua
	MAINTAINER:=Denis Roeper <denis.roeper@posteo.de>
	PKGARCH:=all
endef

define Package/lua-pprint/description
  yet another lua pretty printer 
endef

define Build/Compile
endef

define Package/lua-pprint/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/pprint.lua $(1)/usr/lib/lua
endef

$(eval $(call BuildPackage,lua-pprint))
