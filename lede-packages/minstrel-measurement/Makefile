#
# Copyright (C) 2017 LEDE project (Denis Roeper)
#
# This is free software, licensed under the GNU General Public License v3.
#
# file libc.provides should contain libc.so.6
#

include $(TOPDIR)/rules.mk

PKG_NAME:=minstrel-measurement
PKG_VERSION:=git
PKG_RELEASE:=1
PKG_MAINTAINER:=Denis Roeper <denis.roeper@posteo.de>
PKG_LICENSE:=GPL-3.0+
PKG_LICENSE_FILES:=LICENSE

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-git.tar.gz
PKG_SOURCE_PROTO:=git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_URL:=https://github.com/thuehn/Minstrel-Blues.git
PKG_SOURCE_VERSION:=master

include $(INCLUDE_DIR)/package.mk

define Package/minstrel-measurement
	SUBMENU:=Lua
	SECTION:=lang
	CATEGORY:=Languages
	TITLE:=minstrel-measurement
	DEPENDS:=+lua +lua-rpc +lua-argparse +lua-ex +luaposix +luafilesystem +pcap-lua +cpusage +bind-dig
	MAINTAINER:=Denis Roeper <denis.roeper@posteo.de>
	PKGARCH:=all
endef

define Package/minstrel-measurement/description
  Minstrel Blues Measurement
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR)/measurement/minstrel-measurement all
endef

define Package/minstrel-measurement/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/measurement/minstrel-measurement/bin/cpusage_single $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/measurement/minstrel-measurement/bin/fetch_file $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/measurement/minstrel-measurement/bin/netRun $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/measurement/minstrel-measurement/bin/runLogger $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/measurement/minstrel-measurement/bin/runNode $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/measurement/minstrel-measurement/bin/runControl $(1)/usr/bin
endef

$(eval $(call BuildPackage,minstrel-measurement))
