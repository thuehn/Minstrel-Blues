
EAPI=5
inherit multilib toolchain-funcs

DESCRIPTION="Lua BitOp is a C extension module for Lua 5.1/5.2 which adds bitwise operations on numbers"
HOMEPAGE="http://bitop.luajit.org/"
SRC_URI="http://bitop.luajit.org/download/LuaBitOp-${PV}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm ~hppa ~mips ~ppc ~ppc64 ~x86 ~x86-fbsd"
IUSE=""

DEPEND=">=dev-lang/lua-5.1"
RDEPEND="${DEPEND}"

src_unpack() {
	unpack ${A}
	mv ${WORKDIR}/LuaBitOp-${PV} ${WORKDIR}/${PN}-${PV}
}

src_prepare() {
	sed -i \
		-e "s|gcc|$(tc-getCC)|" \
		-e "s|/usr/local|/usr|" \
		-e "s|/lib|/$(get_libdir)|" \
		-e "s|-O2|${CFLAGS}|" \
		Makefile || die
}

src_install() {
#	emake PREFIX="${ED}usr" install
	dodir /usr/lib/lua/5.1
	cp -R "${S}/bit.so" "${D}/usr/lib/lua/5.1/bit.so" || die "Install failed!"
	dodoc README
}
