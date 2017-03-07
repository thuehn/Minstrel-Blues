
EAPI=5
inherit multilib toolchain-funcs git-2

DESCRIPTION="LuaRPC for Lua 5.1.x"
HOMEPAGE="https://github.com/jsnyder/luarpc"
SRC_URI=""
EGIT_REPO_URI="https://github.com/jsnyder/luarpc.git"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm ~hppa ~mips ~ppc ~ppc64 ~x86 ~x86-fbsd"
IUSE=""

DEPEND=">=dev-lang/lua-5.1"
RDEPEND="${DEPEND}"

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
	cp -R "${S}/rpc.so" "${D}/usr/lib/lua/5.1/rpc.so" || die "Install failed!"
	dodoc README
}
