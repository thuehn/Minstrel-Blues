
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
		dev-lua/luaex
		dev-lua/luaargparse
		dev-lua/luapprint
		dev-lua/luarpc"
RDEPEND="${DEPEND}"

src_install() {
	dodir /usr/bin
	insinto /usr/bin
	dobin measurement/minstrel-measurement/bin/cpusage_single
	dobin measurement/minstrel-measurement/bin/fetch_file.lua
	dobin measurement/minstrel-measurement/bin/netRun.lua
	dobin measurement/minstrel-measurement/bin/runControl.lua
	dobin measurement/minstrel-measurement/bin/runLogger.lua
	dobin measurement/minstrel-measurement/bin/runNode.lua
	dodir /usr/lib/lua/5.1
	insinto /usr/lib/lua/5.1
	doins measurement/minstrel-measurement/AccessPointRef.lua
	doins measurement/minstrel-measurement/DYNsnrAnalyser.lua
	doins measurement/minstrel-measurement/Measurement.lua
	doins measurement/minstrel-measurement/NodeBase.lua
	doins measurement/minstrel-measurement/Uci.lua
	doins measurement/minstrel-measurement/misc.lua
	doins measurement/minstrel-measurement/udpExperiment.lua
	doins measurement/minstrel-measurement/Config.lua
	doins measurement/minstrel-measurement/Experiment.lua
	doins measurement/minstrel-measurement/Net.lua
	doins measurement/minstrel-measurement/NodeRef.lua
	doins measurement/minstrel-measurement/config.lua
	doins measurement/minstrel-measurement/parentpid.lua
	doins measurement/minstrel-measurement/ControlNode.lua
	doins measurement/minstrel-measurement/FXsnrAnalyser.lua
	doins measurement/minstrel-measurement/NetIF.lua
	doins measurement/minstrel-measurement/SNRRenderer.lua
	doins measurement/minstrel-measurement/functional.lua
	doins measurement/minstrel-measurement/spawn_pipe.lua
	doins measurement/minstrel-measurement/ControlNodeRef.lua
	doins measurement/minstrel-measurement/LogNode.lua
	doins measurement/minstrel-measurement/Node.lua
	doins measurement/minstrel-measurement/StationRef.lua
	doins measurement/minstrel-measurement/mcastExperiment.lua
	doins measurement/minstrel-measurement/tcpExperiment.lua
	dodir /usr/lib/lua/5.1/parsers
	insinto /usr/lib/lua5.1/parsers
	doins measurement/minstrel-measurement/parsers/argparse_con.lua
	doins measurement/minstrel-measurement/parsers/dhcp_lease.lua
	doins measurement/minstrel-measurement/parsers/ex_process.lua
	doins measurement/minstrel-measurement/parsers/ifconfig.lua
	doins measurement/minstrel-measurement/parsers/parsers.lua       
	doins measurement/minstrel-measurement/parsers/radiotap.lua
	doins measurement/minstrel-measurement/parsers/cpusage.lua
	doins measurement/minstrel-measurement/parsers/dig.lua
	doins measurement/minstrel-measurement/parsers/free.lua
	doins measurement/minstrel-measurement/parsers/iw_link.lua
	doins measurement/minstrel-measurement/parsers/proc_version.lua
	doins measurement/minstrel-measurement/parsers/rc_stats_csv.lua
}
