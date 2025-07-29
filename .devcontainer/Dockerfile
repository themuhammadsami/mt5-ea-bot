FROM ubuntu:22.04

RUN dpkg --add-architecture i386 && \
    apt update && \
    apt upgrade -y && \
    apt install -y wine64 wine32 unzip wget cabextract winbind xvfb && \
    apt install -y git curl nano

# Create wine prefix
RUN wineboot || true
