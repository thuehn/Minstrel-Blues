
EAPI=5
inherit multilib toolchain-funcs git-2 linux-info

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
		sys-process/procps
		sys-apps/coreutils
		sys-apps/net-tools
		net-dns/bind-tools
		net-wireless/iw
		net-analyzer/tcpdump
		<net-misc/iperf-3.0
		virtual/ssh"
RDEPEND="${DEPEND}"

# https://devmanual.gentoo.org/eclass-reference/linux-info.eclass/
# CFG80211
# RT2800USB
# RT2X00_LIB_DEBUGFS
CONFIG_CHECK="
	~ATH9K_DEBUGFS
	CFG80211_DEBUGFS"

src_compile() {
	cd ${S}/measurement/minstrel-measurement
	emake || die "compile failed"
}

src_install() {
	cd ${S}/measurement/minstrel-measurement
	emake ROOT=${D} install || die "install failed"
}
