# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit eutils

DESCRIPTION="Bindings for POSIX APIs"
HOMEPAGE="https://luaposix.github.io/luaposix/ https://github.com/luaposix/luaposix"
SRC_URI="https://github.com/luaposix/luaposix/archive/release-v${PV}.tar.gz -> ${P}.tar.gz"

SLOT="0"
LICENSE="public-domain"
KEYWORDS="~amd64 ~x86 ~amd64-linux ~x86-linux"
IUSE=""

RDEPEND="dev-lang/lua:0= =sys-devel/automake-1.14.1-r2"
DEPEND="${RDEPEND}"

S="${WORKDIR}"/${PN}-release-v${PV}

src_unpack() {
	unpack ${A}
	cd "${S}"
	epatch "${FILESDIR}/0001-no-la-delete.patch"
}

