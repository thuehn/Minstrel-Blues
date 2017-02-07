aps = { 
    { name = "lede-ap"
    , radio = "radio0"
    , ctrl_if = "br-lan"
    }
}

stations = {
    { name = "lede-sta"
    , radio = "radio0"
    , ctrl_if = "eth0"
    },
    { name = "sta-ctrl"
    , radio = "radio0"
    , ctrl_if = "eth0"
    }
}
