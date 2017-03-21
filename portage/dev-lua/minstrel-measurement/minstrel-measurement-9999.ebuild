
EAPI=5
inherit multilib toolchain-funcs git-2

DESCRIPTION="Minstrel measurement for Lua 5.1"
HOMEPAGE="https://github.com/thuehn/Minstrel-Blues"
SRC_URI=""
EGIT_REPO_URI="https://github.com/thuehn/Minstrel-Blues.git"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm ~hppa ~mips ~ppc ~ppc64 ~x86 ~x86-fbsd"
IUSE=""

DEPEND=">=dev-lang/lua-5.1
		dev-lua/luafilesystem
		dev-lua/luaposix
		dev-lua/LuaBitOp
		dev-lua/pcap-lua
		dev-lua/lpc
		dev-lua/luaargparse
		dev-lua/luapprint
		dev-lua/luarpc
		dev-lua/luasystem
		dev-lua/lua-cjson
		net-dns/bind-tools"
RDEPEND="${DEPEND}"

src_compile() {
	cd ${S}/measurement/minstrel-measurement
	emake || die "compile failed"
}

src_install() {
	cd ${S}/measurement/minstrel-measurement
	emake ROOT=${D} install || die "install failed"
}
