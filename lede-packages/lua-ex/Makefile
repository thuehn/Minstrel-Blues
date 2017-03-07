#
# Copyright (C) 2017 LEDE project (Denis Roeper)
#
# This is free software, licensed under the GNU General Public License v3.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=lua-ex
PKG_VERSION:=0.1
PKG_RELEASE:=1
PKG_MAINTAINER:=Denis Roeper <denis.roeper@posteo.de>
PKG_LICENSE:=GPL-3.0+
PKG_LICENSE_FILES:=LICENSE

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-git.tar.gz
PKG_SOURCE_PROTO:=git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_URL:=https://github.com/jjensen/lua-ex.git
PKG_SOURCE_VERSION:=master

include $(INCLUDE_DIR)/package.mk

define Package/lua-ex
	SUBMENU:=Lua
	SECTION:=lang
	CATEGORY:=Languages
	TITLE:=lua-ex
	DEPENDS:=+lua
	MAINTAINER:=Denis Roeper <denis.roeper@posteo.de>
	PKGARCH:=all
endef

define Package/lua-ex/description
  The Lua Extension API is a proposal for a standard set of functions to provide a more complete programming environment for Lua.
endef

define Build/Compile
	$(CP) $(PKG_BUILD_DIR)/conf.in $(PKG_BUILD_DIR)/conf
	$(MAKE) -C $(PKG_BUILD_DIR) \
		CC="$(TARGET_CC) $(TARGET_CFLAGS) -s" \
		PRECOMPILED_FILTER=1 \
		STAGING_DIR="$(STAGING_DIR)" \
		linux
endef

define Package/lua-ex/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/posix/ex.so $(1)/usr/lib/lua
endef

$(eval $(call BuildPackage,lua-ex))
