require ('parsers/dig')
pprint = require ('pprint')

-- # dig apfel
local answer1 ="; <<>> DiG 9.11.0-P2 <<>> apfel\n;; global options: +cmd\n;; Got answer:\n;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 31008\n;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1\n\n;; OPT PSEUDOSECTION:\n; EDNS: version: 0, flags:; udp: 4096\n;; QUESTION SECTION:\n;apfel.				IN	A\n\n;; ANSWER SECTION:\napfel.			0	IN	A	192.168.2.2\n\n;; Query time: 2 msec\n;; SERVER: 192.168.2.2#53(192.168.2.2)\n;; WHEN: Sat Feb 04 20:31:14 CET 2017\n;; MSG SIZE  rcvd: 50\n"

local dig = parse_dig ( answer1 )
assert ( dig.name == "apfel." )
assert ( dig.addr [ 1 ] == "192.168.2.2" )


-- # dig apfel2
local answer2 = "; <<>> DiG 9.11.0-P2 <<>> apfel2\n;; global options: +cmd\n;; Got answer:\n;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 13048\n;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1\n\n;; OPT PSEUDOSECTION:\n; EDNS: version: 0, flags:; udp: 1460\n;; QUESTION SECTION:\n;apfel2.				IN	A\n\n;; AUTHORITY SECTION:\n.			3600	IN	SOA	a.root-servers.net. nstld.verisign-grs.com. 2017020401 1800 900 604800 86400\n\n;; Query time: 52 msec\n;; SERVER: 192.168.2.2#53(192.168.2.2)\n;; WHEN: Sat Feb 04 20:31:27 CET 2017\n;; MSG SIZE  rcvd: 110\n"

local dig = parse_dig ( answer2 )
assert ( dig.name == nil )
assert ( table_size ( dig.addr ) == 0 )

local answer3 = "localhost.local.	3409	IN	A	127.0.0.1"
local dig = parse_dig ( answer3 )
assert ( dig.name == "localhost.local." )
assert ( dig.addr [ 1 ] == "127.0.0.1" )

-- # dig multiple ip
local answer4 = "; <<>> DiG 9.11.1-P3 <<>> birne.local\n;; global options: +cmd\n;; Got answer:\n;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 33380\n;; flags: qr aa rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1\n\n;; OPT PSEUDOSECTION:\n; EDNS: version: 0, flags:; udp: 4096\n;; QUESTION SECTION:\n;birne.local.			IN	A\n\n;; ANSWER SECTION:\nbirne.local.		0	IN	A	192.168.0.22\nbirne.local.		0	IN	A	192.168.0.21\n\n;; Query time: 1 msec\n;; SERVER: 192.168.0.12#53(192.168.0.12)\n;; WHEN: Fri Dec 01 08:56:46 CET 2017\n;; MSG SIZE  rcvd: 73\n"

local dig = parse_dig ( answer4 )
pprint ( dig )
assert ( dig.name == "birne.local." )
assert ( dig.addr [ 1 ] == "192.168.0.22" )
assert ( dig.addr [ 2 ] == "192.168.0.21" )
