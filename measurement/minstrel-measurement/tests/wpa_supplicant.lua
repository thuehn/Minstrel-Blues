
require ('parsers/wpa_supplicant')
local pprint = require ('pprint')

local conf1 = "#\n###### Global Configuration ######\n\nnetwork={\nssid=\"test\"\nmode=0\n}\n\n"

local wpa1 = parse_wpa_supplicant_conf ( conf1 )
pprint ( wpa1 )
