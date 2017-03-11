require ('parsers/dig')

-- # dig apfel
local answer1 ="; <<>> DiG 9.11.0-P2 <<>> apfel\n;; global options: +cmd\n;; Got answer:\n;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 31008\n;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1\n\n;; OPT PSEUDOSECTION:\n; EDNS: version: 0, flags:; udp: 4096\n;; QUESTION SECTION:\n;apfel.				IN	A\n\n;; ANSWER SECTION:\napfel.			0	IN	A	192.168.2.2\n\n;; Query time: 2 msec\n;; SERVER: 192.168.2.2#53(192.168.2.2)\n;; WHEN: Sat Feb 04 20:31:14 CET 2017\n;; MSG SIZE  rcvd: 50"

local dig = parse_dig ( answer1 )
assert ( dig.name == "apfel." )
assert ( dig.addr == "192.168.2.2" )


-- # dig apfel2
local answer2 = "; <<>> DiG 9.11.0-P2 <<>> apfel2\n;; global options: +cmd\n;; Got answer:\n;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 13048\n;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1\n\n;; OPT PSEUDOSECTION:\n; EDNS: version: 0, flags:; udp: 1460\n;; QUESTION SECTION:\n;apfel2.				IN	A\n\n;; AUTHORITY SECTION:\n.			3600	IN	SOA	a.root-servers.net. nstld.verisign-grs.com. 2017020401 1800 900 604800 86400\n\n;; Query time: 52 msec\n;; SERVER: 192.168.2.2#53(192.168.2.2)\n;; WHEN: Sat Feb 04 20:31:27 CET 2017\n;; MSG SIZE  rcvd: 110"

local dig = parse_dig ( answer2 )
assert ( dig.name == nil )
assert ( dig.addr == nil )

local answer3 = "localhost.local.	3409	IN	A	127.0.0.1"
local dig = parse_dig ( answer3 )
assert ( dig.name == "localhost.local." )
assert ( dig.addr == "127.0.0.1" )
