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

define Build/Prepare 
	mkdir -p $(PKG_BUILD_DIR)/lua-ex 
	$(CP) -r ./lua-ex/* $(PKG_BUILD_DIR)/lua-ex
endef

define Build/Compile
	$(CP) $(PKG_BUILD_DIR)/lua-ex/conf.in $(PKG_BUILD_DIR)/lua-ex/conf
	$(MAKE) -C $(PKG_BUILD_DIR)/lua-ex \
		CC="$(TARGET_CC) $(TARGET_CFLAGS) -s" \
		PRECOMPILED_FILTER=1 \
		STAGING_DIR="$(STAGING_DIR)" \
		linux
endef
##		CFLAGS="$(TARGET_CFLAGS)" \
##		CC="$(TARGET_CC)" \
##		$(MAKE_FLAGS) \


define Package/lua-ex/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/lua-ex/posix/ex.so $(1)/usr/lib/lua
endef

$(eval $(call BuildPackage,lua-ex))
