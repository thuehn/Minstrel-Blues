ctrl = "A"

nodes = {
    { name = "A", ctrl_if = "eth0",      radio = "radio0" },
    { name = "B", ctrl_if = "eth1",      radio = "radio1" },
    { name = "C", ctrl_if = "wlp0s20u1", radio = "radio0" },
    { name = "D", ctrl_if = "eth0.1",    radio = "radio0" },
    { name = "E", ctrl_if = "eth0.2",    radio = "radio0" },
    { name = "F", ctrl_if = "eth2" }
}

connections["A"] = { "B", "C" }
connections["D"] = { "E" }

