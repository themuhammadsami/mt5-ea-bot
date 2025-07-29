#!/bin/bash

set -e
export DISPLAY=:1

# Create virtual display in background
Xvfb :1 &

# Download MetaTrader 5 setup
wget -O mt5setup.exe "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"

# Run setup with wine
wine mt5setup.exe || echo "Ignore GUI errors, install still proceeds"
