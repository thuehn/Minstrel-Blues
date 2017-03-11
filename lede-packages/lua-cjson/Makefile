
include $(TOPDIR)/rules.mk

PKG_NAME:=lua-cjson
PKG_VERSION:=git
PKG_RELEASE:=1
PKG_MAINTAINER:=Denis Roeper <denis.roeper@posteo.de>
PKG_LICENSE:=GPL-3.0+
PKG_LICENSE_FILES:=LICENSE

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-git.tar.gz
PKG_SOURCE_PROTO:=git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_URL:=https://github.com/mpx/lua-cjson.git
PKG_SOURCE_VERSION:=master

include $(INCLUDE_DIR)/package.mk

define Package/lua-cjson
	SUBMENU:=Lua
	SECTION:=lang
	CATEGORY:=Languages
	TITLE:=lua-cjson
	DEPENDS:=+libc +lua
	MAINTAINER:=Denis Roeper <denis.roeper@posteo.de>
	PKGARCH:=all
endef

define Package/lua-cjson/description
  Lua CJSON is a fast JSON encoding/parsing module for Lua
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) \
		CC="$(TARGET_CC)"
		CFLAGS="$(TARGET_CFLAGS) -s" \
		PRECOMPILED_FILTER=1 \
		STAGING_DIR="$(STAGING_DIR)" \
		cjson.so
endef

define Package/lua-cjson/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cjson.so $(1)/usr/lib/lua
endef

$(eval $(call BuildPackage,lua-cjson))
