#!/bin/bash

echo "Downloading MetaTrader 5 setup..."
wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe

echo "Running MT5 installer with Wine (headless)"
xvfb-run wine mt5setup.exe
