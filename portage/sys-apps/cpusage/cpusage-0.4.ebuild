# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6
inherit multilib toolchain-funcs

DESCRIPTION="Monitoring the CPU usage"
HOMEPAGE="https://www.net.t-labs.tu-berlin.de/~fabian/software_en.html#cpusage"
SRC_URI="https://www.net.t-labs.tu-berlin.de/~fabian/sources/${PV}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm ~hppa ~mips ~ppc ~ppc64 ~x86 ~x86-fbsd"
IUSE=""

DEPEND=""
RDEPEND="${DEPEND}"
