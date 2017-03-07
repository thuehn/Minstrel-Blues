
EAPI=5
inherit multilib toolchain-funcs git-2

DESCRIPTION="The Lua Extension API"
HOMEPAGE="https://github.com/luaforge/lua-ex"
SRC_URI=""
EGIT_REPO_URI="https://github.com/luaforge/lua-ex.git"


LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm ~hppa ~mips ~ppc ~ppc64 ~x86 ~x86-fbsd"
IUSE=""

DEPEND=">=dev-lang/lua-5.1"
RDEPEND="${DEPEND}"

src_prepare() {
	cp ${WORKDIR}/${P}/conf.in ${WORKDIR}/${P}/conf
	sed -i \
		-e "s|LUA=|#LUA=|" \
		-e "s|LUAINC=|#LUAINC=|" \
		-e "s|LUALIB=|#LUALIB=|" \
		conf
	sed -i \
		-e "s|gcc|$(tc-getCC)|" \
		-e "s|/usr/local|/usr|" \
		-e "s|/lib|/$(get_libdir)|" \
		-e "s|CFLAGS=|CFLAGS= ${CFLAGS} -fPIC|" \
		-e "s|-shared|-shared -fPIC|" \
		posix/Makefile || die
}

src_install() {
	emake PREFIX="${ED}usr" linux
	dodir /usr/lib/lua/5.1
	cp "${S}/posix/ex.so" "${D}/usr/lib/lua/5.1/ex.so" || die "Install failed!"
	dodoc README
}
