LUAC            = luac

SRC_DIR         = .
SOURCE          =                \
AccessPointRef.lua  DYNsnrAnalyser.lua  Measurement.lua  NodeBase.lua     Uci.lua              misc.lua           udpExperiment.lua \
Config.lua          Experiment.lua      Net.lua          NodeRef.lua      config.lua           parentpid.lua \
ControlNode.lua     FXsnrAnalyser.lua   NetIF.lua        SNRRenderer.lua  functional.lua       spawn_pipe.lua \
ControlNodeRef.lua  LogNode.lua         Node.lua         StationRef.lua   mcastExperiment.lua  tcpExperiment.lua \

BIN_DIR         = bin

FETCH_FILE = fetch_file
NET_RUN = netRun
RUN_CONTROL = runControl
RUN_LOGGER = runLogger
RUN_NODE = runNode

all: $(FETCH_FILE) $(NET_RUN) $(RUN_CONTROL) $(RUN_LOGGER) $(RUN_NODE)


$(FETCH_FILE): $(BIN_DIR)/$(FETCH_FILE).lua
	$(LUAC) -o $(BIN_DIR)/$(FETCH_FILE) $(SOURCE) "$<"
	chmod 700 $(BIN_DIR)/$(FETCH_FILE)

$(NET_RUN): $(BIN_DIR)/$(NET_RUN).lua
	$(LUAC) -o $(BIN_DIR)/$(NET_RUN) $(SOURCE) "$<"
	chmod 700 $(BIN_DIR)/$(NET_RUN)

$(RUN_CONTROL): $(BIN_DIR)/$(RUN_CONTROL).lua
	$(LUAC) -o $(BIN_DIR)/$(RUN_CONTROL) $(SOURCE) "$<"
	chmod 700 $(BIN_DIR)/$(RUN_CONTROL)

$(RUN_LOGGER): $(BIN_DIR)/$(RUN_LOGGER).lua
	$(LUAC) -o $(BIN_DIR)/$(RUN_LOGGER) $(SOURCE) "$<"
	chmod 700 $(BIN_DIR)/$(RUN_LOGGER)

$(RUN_NODE): $(BIN_DIR)/$(RUN_NODE).lua
	$(LUAC) -o $(BIN_DIR)/$(RUN_NODE) $(SOURCE) "$<"
	chmod 700 $(BIN_DIR)/$(RUN_NODE)

.PHONY: all

clean:
	rm -f $(BIN_DIR)/$(FETCH_FILE)
	rm -f $(BIN_DIR)/$(NET_RUN)
	rm -f $(BIN_DIR)/$(RUN_CONTROL)
	rm -f $(BIN_DIR)/$(RUN_LOGGER)
	rm -f $(BIN_DIR)/$(RUN_NODE)
