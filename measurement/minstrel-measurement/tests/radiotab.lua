require ('pcap')
require ('parsers/radiotab')
local pprint = require ('pprint')

local snrs = {}
snrs[1] = -82
snrs[2] = -82
snrs[3] = -47
snrs[4] = -79
snrs[5] = -88
snrs[6] = nil
snrs[7] = -87


local fname = "tests/test.pcap"
local cap = pcap.open_offline( fname )
if (cap ~= nil) then
	cap:set_filter ("type mgt subtype beacon", nooptimize)
    local i = 1
    for capdata, timestamp, wirelen in cap.next, cap do

        --print ( PCAP.to_bytes_hex ( capdata ) )

        local rest = capdata
        local radiotab_header
        local radiotab_data
        radiotab_header, rest = PCAP.parse_radiotab_header ( rest )
        radiotab_data, rest = PCAP.parse_radiotab_data ( rest )

        if ( i == 1 ) then
            -- check present flags
            assert ( PCAP.hasbit ( radiotab_header['it_present'], PCAP.bit ( PCAP.radiotab_type [ 'IEEE80211_RADIOTAP_TSFT' ] ) ) == true )
            assert ( PCAP.hasbit ( radiotab_header['it_present'], PCAP.bit ( PCAP.radiotab_type [ 'IEEE80211_RADIOTAP_FLAGS' ] ) ) == true )
            assert ( PCAP.hasbit ( radiotab_header['it_present'], PCAP.bit ( PCAP.radiotab_type [ 'IEEE80211_RADIOTAP_RATE' ] ) ) == true )
            assert ( PCAP.hasbit ( radiotab_header['it_present'], PCAP.bit ( PCAP.radiotab_type [ 'IEEE80211_RADIOTAP_CHANNEL' ] ) ) == true )
            assert ( PCAP.hasbit ( radiotab_header['it_present'], PCAP.bit ( PCAP.radiotab_type [ 'IEEE80211_RADIOTAP_FHSS' ] ) ) == false )
            assert ( PCAP.hasbit ( radiotab_header['it_present'], PCAP.bit ( PCAP.radiotab_type [ 'IEEE80211_RADIOTAP_DBM_ANTSIGNAL' ] ) ) == true )
            assert ( PCAP.hasbit ( radiotab_header['it_present'], PCAP.bit ( PCAP.radiotab_type [ 'IEEE80211_RADIOTAP_DBM_ANTNOISE' ] ) ) == false )
            assert ( PCAP.hasbit ( radiotab_header['it_present'], PCAP.bit ( PCAP.radiotab_type [ 'IEEE80211_RADIOTAP_LOCK_QUALITY' ] ) ) == false )
            assert ( PCAP.hasbit ( radiotab_header['it_present'], PCAP.bit ( PCAP.radiotab_type [ 'IEEE80211_RADIOTAP_TX_ATTENUATION' ] ) ) == false )
            assert ( PCAP.hasbit ( radiotab_header['it_present'], PCAP.bit ( PCAP.radiotab_type [ 'IEEE80211_RADIOTAP_DBM_TX_POWER' ] ) ) == false )
            assert ( PCAP.hasbit ( radiotab_header['it_present'], PCAP.bit ( PCAP.radiotab_type [ 'IEEE80211_RADIOTAP_ANTENNA' ] ) ) == false )
            assert ( PCAP.hasbit ( radiotab_header['it_present'], PCAP.bit ( PCAP.radiotab_type [ 'IEEE80211_RADIOTAP_DB_ANTSIGNAL' ] ) ) == false )
            assert ( PCAP.hasbit ( radiotab_header['it_present'], PCAP.bit ( PCAP.radiotab_type [ 'IEEE80211_RADIOTAP_DB_ANTNOISE' ] ) ) == false )
            assert ( PCAP.hasbit ( radiotab_header['it_present'], PCAP.bit ( PCAP.radiotab_type [ 'IEEE80211_RADIOTAP_RX_FLAGS' ] ) ) == true )
            assert ( PCAP.hasbit ( radiotab_header['it_present'], PCAP.bit ( PCAP.radiotab_type [ 'IEEE80211_RADIOTAP_EXT' ] ) ) == true )

            -- check timestamp
            assert ( radiotab_header['tsft'] == 89665551)

            -- check flags
            assert ( PCAP.hasbit ( radiotab_header['flags'], PCAP.bit ( PCAP.radiotab_flags [ 'IEEE80211_RADIOTAP_F_CFP' ] ) ) == false )
            assert ( PCAP.hasbit ( radiotab_header['flags'], PCAP.bit ( PCAP.radiotab_flags [ 'IEEE80211_RADIOTAP_F_SHORTPRE' ] ) ) == false )
            assert ( PCAP.hasbit ( radiotab_header['flags'], PCAP.bit ( PCAP.radiotab_flags [ 'IEEE80211_RADIOTAP_F_WEP' ] ) ) == false )
            assert ( PCAP.hasbit ( radiotab_header['flags'], PCAP.bit ( PCAP.radiotab_flags [ 'IEEE80211_RADIOTAP_F_FRAG' ] ) ) == false )
            assert ( PCAP.hasbit ( radiotab_header['flags'], PCAP.bit ( PCAP.radiotab_flags [ 'IEEE80211_RADIOTAP_F_FCS' ] ) ) == true )
            assert ( PCAP.hasbit ( radiotab_header['flags'], PCAP.bit ( PCAP.radiotab_flags [ 'IEEE80211_RADIOTAP_F_DATAPAD' ] ) ) == false )
            assert ( PCAP.hasbit ( radiotab_header['flags'], PCAP.bit ( PCAP.radiotab_flags [ 'IEEE80211_RADIOTAP_F_BADFCS' ] ) ) == false )
    
            -- check data rate
            --print ( radiotab_header['rate'] )
            assert ( radiotab_header['rate'] == 2 ) -- 1Mb/s

            --print ( radiotab_header['channel'] )
            assert ( radiotab_header['channel'] == 2462 ) -- 1Mb/s

            -- check channel flags
            --print ( PCAP.bitmask_tostring ( radiotab_header['channel_flags'], 16 ) )
            assert ( PCAP.hasbit ( radiotab_header['channel_flags'], PCAP.bit ( PCAP.radiotab_chan_flags [ 'IEEE80211_CHAN_TURBO' ] ) ) == false )
            assert ( PCAP.hasbit ( radiotab_header['channel_flags'], PCAP.bit ( PCAP.radiotab_chan_flags [ 'IEEE80211_CHAN_CCK' ] ) ) == true )
            assert ( PCAP.hasbit ( radiotab_header['channel_flags'], PCAP.bit ( PCAP.radiotab_chan_flags [ 'IEEE80211_CHAN_OFDM' ] ) ) == false )
            assert ( PCAP.hasbit ( radiotab_header['channel_flags'], PCAP.bit ( PCAP.radiotab_chan_flags [ 'IEEE80211_CHAN_2GHZ' ] ) ) == true )
            assert ( PCAP.hasbit ( radiotab_header['channel_flags'], PCAP.bit ( PCAP.radiotab_chan_flags [ 'IEEE80211_CHAN_5GHZ' ] ) ) == false )
            assert ( PCAP.hasbit ( radiotab_header['channel_flags'], PCAP.bit ( PCAP.radiotab_chan_flags [ 'IEEE80211_CHAN_PASSIVE' ] ) ) == false )
            assert ( PCAP.hasbit ( radiotab_header['channel_flags'], PCAP.bit ( PCAP.radiotab_chan_flags [ 'IEEE80211_CHAN_DYN' ] ) ) == false )
            assert ( PCAP.hasbit ( radiotab_header['channel_flags'], PCAP.bit ( PCAP.radiotab_chan_flags [ 'IEEE80211_CHAN_GFSK' ] ) ) == false )
        end

        -- check SSI Signal
        assert ( radiotab_header['antenna_signal'] == snrs[i] )

        if ( i == 7 ) then
            break
        else
            i = i + 1
        end
    end
    cap:close()
else
    print ("pcap open failed: " .. fname)
end

