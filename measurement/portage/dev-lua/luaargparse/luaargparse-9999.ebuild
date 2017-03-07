
EAPI=5
inherit multilib toolchain-funcs git-2

DESCRIPTION="Feature-rich command line parser for Lua"
HOMEPAGE="https://github.com/mpeterv/argparse"
SRC_URI=""
EGIT_REPO_URI="https://github.com/mpeterv/argparse.git"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm ~hppa ~mips ~ppc ~ppc64 ~x86 ~x86-fbsd"
IUSE=""

DEPEND=">=dev-lang/lua-5.1"
RDEPEND="${DEPEND}"

src_install() {
	dodir /usr/lib/lua/5.1
	cp "${S}/src/argparse.lua" "${D}/usr/lib/lua/5.1/" || die "Install failed!"
	dodoc README.md
}
