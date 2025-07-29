#!/bin/bash

echo "Installing dependencies..."
sudo apt update && sudo apt install -y xvfb wine64 wine32 unzip wget cabextract winbind

echo "Downloading MetaTrader 5 setup..."
wget -O mt5setup.exe https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe

echo "Launching MT5 installer with virtual display (xvfb)..."
xvfb-run -a wine mt5setup.exe

echo "Installation attempted. If installer froze, please upload terminal64.exe manually."
