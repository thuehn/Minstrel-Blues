
include $(TOPDIR)/rules.mk

PKG_NAME:=lua-rpc
PKG_VERSION:=0.1
PKG_RELEASE:=1
PKG_MAINTAINER:=Denis Roeper <denis.roeper@posteo.de>
PKG_LICENSE:=GPL-3.0+
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

define Package/lua-rpc
	SUBMENU:=Lua
	SECTION:=lang
	CATEGORY:=Languages
	TITLE:=lua-rpc
	DEPENDS:=+lua
	MAINTAINER:=Denis Roeper <denis.roeper@posteo.de>
	PKGARCH:=all
endef
#	PKG_BUILD_DEPENDS:=+lua/host

define Package/lua-rpc/description
  Lua remote procedure calls
endef

define Build/Prepare 
	mkdir -p $(PKG_BUILD_DIR)/luarpc 
	$(CP) ./luarpc/* $(PKG_BUILD_DIR)/luarpc
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR)/luarpc \
		CC="$(TARGET_CC) $(TARGET_CFLAGS) -s" \
		PRECOMPILED_FILTER=1 \
		STAGING_DIR="$(STAGING_DIR)" \
		socket
endef
#		CFLAGS="$(TARGET_CFLAGS)" \
#		CC="$(TARGET_CC)" \
#		$(MAKE_FLAGS) \


define Package/lua-rpc/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/luarpc/rpc.so $(1)/usr/lib/lua
endef

$(eval $(call BuildPackage,lua-rpc))
