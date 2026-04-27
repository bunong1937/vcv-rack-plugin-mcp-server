# Makefile for VCV Rack Plugin - VCVRackMcpServer
# Follows VCV Rack official plugin build system

# Plugin slug and version
SLUG = VCVRackMcpServer

# Extract version from plugin.json
VERSION ?= $(shell python3 -c "import json; print(json.load(open('../plugin.json'))['version'])" 2>/dev/null || echo "1.0.0")

# Rack SDK path (can be overridden with make RACK_DIR=/path/to/Rack-SDK)
RACK_DIR ?= ../Rack-SDK

# Source files
SOURCES = $(wildcard src/*.cpp)

# Distribution
DISTRIBUTABLE = dist/$(SLUG)-$(VERSION)-win-x64.vcvplugin

# Include Rack SDK compile rules
include $(RACK_DIR)/compile.mk

# Install to Rack user plugins folder
install: $(DISTRIBUTABLE)
	mkdir -p "$(HOME)/AppData/Local/Rack2/plugins-win-x64/$(SLUG)"
	unzip -o $(DISTRIBUTABLE) -d "$(HOME)/AppData/Local/Rack2/plugins-win-x64/$(SLUG)/"
	@echo "Installed to $(HOME)/AppData/Local/Rack2/plugins-win-x64/$(SLUG)/"
