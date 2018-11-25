
require ('parsers/netstat')
require ('misc')

pprint = require ( 'pprint' )

local netstat1_str = "\n"
local netstat1 = parse_netstat ( netstat1_str )

--[[ netstat -antu
Aktive Internetverbindungen (Server und stehende Verbindungen)
Proto Recv-Q Send-Q Local Address           Foreign Address         State      
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:631           0.0.0.0:*               LISTEN     
tcp        0      0 192.168.2.110:39500     8.8.8.8:5222            VERBUNDEN  
tcp6       0      0 :::22                   :::*                    LISTEN     
tcp6       0      0 ::1:631                 :::*                    LISTEN     
tcp6       1      0 ::1:39644               ::1:631                 CLOSE_WAIT 
tcp6       1      0 ::1:38082               ::1:631                 CLOSE_WAIT 
udp        0      0 0.0.0.0:68              0.0.0.0:*                          
udp        0      0 0.0.0.0:68              0.0.0.0:*                          
udp        0      0 0.0.0.0:631             0.0.0.0:*                          
udp6       0      0 :::37192                :::*                               
udp6       0      0 aa11:bb22:cc33:1:dd:546 :::*                               
udp6       0      0 aa11:bb22:cc33:1:ab:546 :::*                               
udp6       0      0 ff66::f66f:00aa:aa00:546 :::*                               
udp6       0      0 ff66::f66f:aa00:00aa:546 :::*                               
]]--

local netstat2_str = "Aktive Internetverbindungen (Server und stehende Verbindungen)\nProto Recv-Q Send-Q Local Address           Foreign Address         State      \ntcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN     \ntcp        0      0 127.0.0.1:631           0.0.0.0:*               LISTEN     \ntcp        0      0 192.168.2.110:39500     8.8.8.8:5222         VERBUNDEN  \ntcp6       0      0 :::22                   :::*                    LISTEN     \ntcp6       0      0 ::1:631                 :::*                    LISTEN     \ntcp6       1      0 ::1:39644               ::1:631                 CLOSE_WAIT \ntcp6       1      0 ::1:38082               ::1:631                 CLOSE_WAIT \nudp        0      0 0.0.0.0:68              0.0.0.0:*                          \nudp        0      0 0.0.0.0:68              0.0.0.0:*                          \nudp        0      0 0.0.0.0:631             0.0.0.0:*                          \nudp6       0      0 :::37192                :::*                               \nudp6       0      0 aa11:bb22:cc33:1:dd:546 :::*                               \nudp6       0      0 aa11:bb22:cc33:1:ab:546 :::*                               \nudp6       0      0 ff66::f66f:00aa:aa00:546 :::*                               \nudp6       0      0 ff66::f66f:aa00:00aa:546 :::*                               \n"
local netstat2 = parse_netstat ( netstat2_str )
assert ( #netstat2 == 6 )
assert ( netstat2 [ 1 ].local_port == "22" )
assert ( netstat2 [ 1 ].foreign_port == "*" )
assert ( netstat2 [ 2 ].local_port == "631" )
assert ( netstat2 [ 2 ].foreign_port == "*" )
assert ( netstat2 [ 3 ].local_port == "39500" )
assert ( netstat2 [ 3 ].foreign_port == "5222" )
assert ( netstat2 [ 4 ].local_port == "68" )
assert ( netstat2 [ 4 ].foreign_port == "*" )
assert ( netstat2 [ 5 ].local_port == "68" )
assert ( netstat2 [ 5 ].foreign_port == "*" )
assert ( netstat2 [ 6 ].local_port == "631" )
assert ( netstat2 [ 6 ].foreign_port == "*" )

--[[ netstat -antu
Active Internet connections (servers and established)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      
tcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN      
tcp        0      0 192.168.2.209:53        0.0.0.0:*               LISTEN      
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      
tcp        0      0 192.168.2.209:22        192.168.2.110:51438     ESTABLISHED 
tcp        0      0 192.168.2.209:80        192.168.2.110:57462     ESTABLISHED 
tcp        0      0 :::80                   :::*                    LISTEN      
tcp        0      0 ::1:53                  :::*                    LISTEN      
tcp        0      0 :::22                   :::*                    LISTEN      
udp        0      0 127.0.0.1:53            0.0.0.0:*                           
udp        0      0 192.168.2.209:53        0.0.0.0:*                           
udp        0      0 :::547                  :::*                                
udp        0      0 ::1:53                  :::*                                
--]]

local netstat3_str = "Active Internet connections (servers and established)\nProto Recv-Q Send-Q Local Address           Foreign Address         State       \ntcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      \ntcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN      \ntcp        0      0 192.168.2.209:53        0.0.0.0:*               LISTEN      \ntcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      \ntcp        0      0 192.168.2.209:22        192.168.2.110:51438     ESTABLISHED \ntcp        0      0 192.168.2.209:80        192.168.2.110:57462     ESTABLISHED \ntcp        0      0 :::80                   :::*                    LISTEN      \ntcp        0      0 ::1:53                  :::*                    LISTEN      \ntcp        0      0 :::22                   :::*                    LISTEN      \nudp        0      0 127.0.0.1:53            0.0.0.0:*                           \nudp        0      0 192.168.2.209:53        0.0.0.0:*                           \nudp        0      0 :::547                  :::*                                \nudp        0      0 ::1:53                  :::*                                \n"

local netstat3 = parse_netstat ( netstat3_str )
assert ( #netstat3 == 8 )
assert ( netstat3 [ 1 ].local_port == "80" )
assert ( netstat3 [ 1 ].foreign_port == "*" )
assert ( netstat3 [ 2 ].local_port == "53" )
assert ( netstat3 [ 2 ].foreign_port == "*" )
assert ( netstat3 [ 3 ].local_port == "53" )
assert ( netstat3 [ 3 ].foreign_port == "*" )
assert ( netstat3 [ 4 ].local_port == "22" )
assert ( netstat3 [ 4 ].foreign_port == "*" )
assert ( netstat3 [ 5 ].local_port == "22" )
assert ( netstat3 [ 5 ].foreign_port == "51438" )
assert ( netstat3 [ 6 ].local_port == "80" )
assert ( netstat3 [ 6 ].foreign_port == "57462" )
assert ( netstat3 [ 7 ].local_port == "53" )
assert ( netstat3 [ 7 ].foreign_port == "*" )
assert ( netstat3 [ 8 ].local_port == "53" )
assert ( netstat3 [ 8 ].foreign_port == "*" )

--[[ netstat -antup
PID/Program name
6738/firefox
-
--]]

--[[ netstat -antup
(Es konnten nicht alle Prozesse identifiziert werden; Informationen über
nicht-eigene Processe werden nicht angezeigt; Root kann sie anzeigen.)
Aktive Internetverbindungen (Server und stehende Verbindungen)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      -                   
tcp        0      0 127.0.0.1:631           0.0.0.0:*               LISTEN      -                   
tcp        0      0 192.168.2.110:39500     8.8.8.8:5222            VERBUNDEN   6588/pidgin         
tcp6       0      0 :::22                   :::*                    LISTEN      -                   
tcp6       0      0 ::1:631                 :::*                    LISTEN      -                   
tcp6       1      0 ::1:39644               ::1:631                 CLOSE_WAIT  -                   
tcp6       1      0 ::1:38082               ::1:631                 CLOSE_WAIT  -                   
udp        0      0 0.0.0.0:68              0.0.0.0:*                           -                   
udp        0      0 0.0.0.0:68              0.0.0.0:*                           -                   
udp        0      0 0.0.0.0:631             0.0.0.0:*                           -                   
udp6       0      0 :::35145                :::*                                -                   
--]]

local netstat4_str = "(Es konnten nicht alle Prozesse identifiziert werden; Informationen über\nnicht-eigene Processe werden nicht angezeigt; Root kann sie anzeigen.)\nAktive Internetverbindungen (Server und stehende Verbindungen)\nProto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    \ntcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      -                   \ntcp        0      0 127.0.0.1:631           0.0.0.0:*               LISTEN      -                   \ntcp        0      0 192.168.2.110:39500     8.8.8.8:5222      VERBUNDEN   6588/pidgin         \ntcp6       0      0 :::22                   :::*                    LISTEN      -                   \ntcp6       0      0 ::1:631                 :::*                    LISTEN      -                   \ntcp6       1      0 ::1:39644               ::1:631                 CLOSE_WAIT  -                   \ntcp6       1      0 ::1:38082               ::1:631                 CLOSE_WAIT  -                   \nudp        0      0 0.0.0.0:68              0.0.0.0:*                           -                   \nudp        0      0 0.0.0.0:68              0.0.0.0:*                           -                   \nudp        0      0 0.0.0.0:631             0.0.0.0:*                           -                   \nudp6       0      0 :::35145                :::*                                -                   \n"
local netstat4 = parse_netstat ( netstat4_str )
assert ( netstat4 [ 3 ].process == "6588" )
assert ( netstat4 [ 3 ].program == "pidgin" )

local netstat_lua_str = "Aktive Internetverbindungen (Server und stehende Verbindungen)\nProto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name   \ntcp        0      0 0.0.0.0:12346           0.0.0.0:*               LISTEN      8491/lua            \ntcp        0      0 0.0.0.0:12347           0.0.0.0:*               LISTEN      8490/lua            \n"
local netstat_lua = parse_netstat ( netstat_lua_str )
--pprint ( netstat_lua )
assert ( netstat_lua [1].local_port == "12346" )
assert ( netstat_lua [1].process == "8491" )
assert ( netstat_lua [1].program == "lua" )
assert ( netstat_lua [2].local_port == "12347" )
assert ( netstat_lua [2].process == "8490" )
assert ( netstat_lua [2].program == "lua" )
