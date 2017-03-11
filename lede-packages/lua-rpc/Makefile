
include $(TOPDIR)/rules.mk

PKG_NAME:=lua-rpc
PKG_VERSION:=git
PKG_RELEASE:=1
PKG_MAINTAINER:=Denis Roeper <denis.roeper@posteo.de>
PKG_LICENSE:=GPL-3.0+
PKG_LICENSE_FILES:=LICENSE

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-git.tar.gz
PKG_SOURCE_PROTO:=git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_URL:=https://github.com/jsnyder/luarpc.git
PKG_SOURCE_VERSION:=master

include $(INCLUDE_DIR)/uclibc++.mk
include $(INCLUDE_DIR)/package.mk

define Package/lua-rpc
	SUBMENU:=Lua
	SECTION:=lang
	CATEGORY:=Languages
	TITLE:=lua-rpc
	DEPENDS:=+libc +lua
	MAINTAINER:=Denis Roeper <denis.roeper@posteo.de>
	PKGARCH:=all
endef

define Package/lua-rpc/description
  LuaRPC for Lua 5.1.x 
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) \
		CC="$(TARGET_CC) $(TARGET_CFLAGS) -s" \
		PRECOMPILED_FILTER=1 \
		STAGING_DIR="$(STAGING_DIR)" \
		socket
endef

define Package/lua-rpc/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/rpc.so $(1)/usr/lib/lua
endef

$(eval $(call BuildPackage,lua-rpc,+libc))

# add "libc.so.6" to staging_dir/target-mips_24kc_musl/pkginfo/libc.provides
# or do more patching
