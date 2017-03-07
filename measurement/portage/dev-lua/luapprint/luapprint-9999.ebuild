
EAPI=5
inherit multilib toolchain-funcs git-2

DESCRIPTION="yet another lua pretty printer"
HOMEPAGE="https://github.com/jagt/pprint.lua"
SRC_URI=""
EGIT_REPO_URI="https://github.com/jagt/pprint.lua.git"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm ~hppa ~mips ~ppc ~ppc64 ~x86 ~x86-fbsd"
IUSE=""

DEPEND=">=dev-lang/lua-5.1"
RDEPEND="${DEPEND}"

src_install() {
	dodir /usr/lib/lua/5.1
	cp "${S}/pprint.lua" "${D}/usr/lib/lua/5.1/" || die "Install failed!"
	dodoc README.md
}
