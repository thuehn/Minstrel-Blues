
EAPI=5
inherit multilib toolchain-funcs git-2

DESCRIPTION="Allows Lua scripts to call external processes while capturing both their input and output."
HOMEPAGE="https://github.com/LuaDist/lpc"
SRC_URI=""
EGIT_REPO_URI="https://github.com/LuaDist/lpc.git"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm ~hppa ~mips ~ppc ~ppc64 ~x86 ~x86-fbsd"
IUSE=""

DEPEND=">=dev-lang/lua-5.1"
RDEPEND="${DEPEND}"

src_install() {
	dodir /usr/lib/lua/5.1
	cp "${S}/lpc.so" "${D}/usr/lib/lua/5.1/" || die "Install failed!"
}
