
ctrl = "lede-ctrl"

connections["lede-ap"] = { "lede-sta" }

nodes = {
    { name = "lede-ap", radio = "radio0", ctrl_if = "eth0.2", rsa_key = "/etc/dropbear/id_rsa" },
    { name = "lede-sta", radio = "radio0", ctrl_if = "eth0.2", rsa_key = "/etc/dropbear/id_rsa"  },
    { name = "lede-ctrl", radio = "radio0", ctrl_if = "eth0.2", rsa_key = "/etc/dropbear/id_rsa" }
}
