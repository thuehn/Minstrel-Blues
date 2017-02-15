#
# Copyright (C) 2017 LEDE project (Denis Roeper)
#
# This is free software, licensed under the GNU General Public License v3.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=pcap-lua
PKG_VERSION:=0.1
PKG_RELEASE:=1
PKG_MAINTAINER:=Denis Roeper <denis.roeper@posteo.de>
PKG_LICENSE:=GPL-3.0+
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

define Package/pcap-lua
	SUBMENU:=Lua
	SECTION:=lang
	CATEGORY:=Languages
	TITLE:=pcap-lua
	DEPENDS:=+lua
	MAINTAINER:=Denis Roeper <denis.roeper@posteo.de>
	PKGARCH:=all
endef

define Package/pcap-lua/description
  lua bindings for libpcap
endef

define Build/Prepare 
	mkdir -p $(PKG_BUILD_DIR)/pcap-lua 
	$(CP) -r ./pcap-lua/* $(PKG_BUILD_DIR)/pcap-lua
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR)/pcap-lua \
		CC="$(TARGET_CC) $(TARGET_CFLAGS) -s" \
		PRECOMPILED_FILTER=1 \
		STAGING_DIR="$(STAGING_DIR)" \
		install
endef
##		CFLAGS="$(TARGET_CFLAGS)" \
##		CC="$(TARGET_CC)" \
##		$(MAKE_FLAGS) \


define Package/pcap-lua/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/pcap-lua/pcap.so $(1)/usr/lib/lua
endef

$(eval $(call BuildPackage,pcap-lua))
