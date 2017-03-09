LUAC = luac
SRC_DIR	= .
BIN_DIR	= bin
INSTALL_BIN_DIR	= $(ROOT)/usr/bin
INSTALL_LUA_LIB_DIR	= $(ROOT)/usr/lib/lua/5.1

FETCH_FILE = fetch_file
NET_RUN = netRun
RUN_CONTROL = runControl
RUN_LOGGER = runLogger
RUN_NODE = runNode

all: $(FETCH_FILE) $(NET_RUN) $(RUN_CONTROL) $(RUN_LOGGER) $(RUN_NODE)

$(FETCH_FILE): $(BIN_DIR)/$(FETCH_FILE).lua
	$(LUAC) -o $(BIN_DIR)/$(FETCH_FILE) "$<"
	chmod 755 $(BIN_DIR)/$(FETCH_FILE)

$(NET_RUN): $(BIN_DIR)/$(NET_RUN).lua
	$(LUAC) -o $(BIN_DIR)/$(NET_RUN) "$<"
	chmod 755 $(BIN_DIR)/$(NET_RUN)

$(RUN_CONTROL): $(BIN_DIR)/$(RUN_CONTROL).lua
	$(LUAC) -o $(BIN_DIR)/$(RUN_CONTROL) "$<"
	chmod 755 $(BIN_DIR)/$(RUN_CONTROL)

$(RUN_LOGGER): $(BIN_DIR)/$(RUN_LOGGER).lua
	$(LUAC) -o $(BIN_DIR)/$(RUN_LOGGER) "$<"
	chmod 755 $(BIN_DIR)/$(RUN_LOGGER)

$(RUN_NODE): $(BIN_DIR)/$(RUN_NODE).lua
	$(LUAC) -o $(BIN_DIR)/$(RUN_NODE) "$<"
	chmod 755 $(BIN_DIR)/$(RUN_NODE)

.PHONY: all

clean:
	rm -f $(BIN_DIR)/$(FETCH_FILE)
	rm -f $(BIN_DIR)/$(NET_RUN)
	rm -f $(BIN_DIR)/$(RUN_CONTROL)
	rm -f $(BIN_DIR)/$(RUN_LOGGER)
	rm -f $(BIN_DIR)/$(RUN_NODE)

install:
	mkdir -p $(INSTALL_BIN_DIR)
	cp $(BIN_DIR)/$(FETCH_FILE) $(INSTALL_BIN_DIR)/$(FETCH_FILE)
	chmod 755 $(INSTALL_BIN_DIR)/$(FETCH_FILE)
	cp $(BIN_DIR)/$(NET_RUN) $(INSTALL_BIN_DIR)/$(NET_RUN)
	chmod 755 $(INSTALL_BIN_DIR)/$(NET_RUN)
	cp $(BIN_DIR)/$(RUN_CONTROL) $(INSTALL_BIN_DIR)/$(RUN_CONTROL)
	chmod 755 $(INSTALL_BIN_DIR)/$(RUN_CONTROL)
	cp $(BIN_DIR)/$(RUN_NODE) $(INSTALL_BIN_DIR)/$(RUN_NODE)
	chmod 755 $(INSTALL_BIN_DIR)/$(RUN_NODE)
	cp $(BIN_DIR)/$(RUN_LOGGER) $(INSTALL_BIN_DIR)/$(RUN_LOGGER)
	chmod 755 $(INSTALL_BIN_DIR)/$(RUN_LOGGER)
	mkdir -p $(INSTALL_LUA_LIB_DIR)
	cp -r *.lua $(INSTALL_LUA_LIB_DIR)
	mkdir -p $(INSTALL_LUA_LIB_DIR)/parsers
	cp -r parsers/*.lua $(INSTALL_LUA_LIB_DIR)/parsers
