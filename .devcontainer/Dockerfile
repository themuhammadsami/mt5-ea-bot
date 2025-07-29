# Use official Ubuntu as base
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && \
    apt install -y software-properties-common && \
    dpkg --add-architecture i386 && \
    add-apt-repository universe && \
    apt update && \
    apt install -y \
    wget \
    gnupg2 \
    unzip \
    cabextract \
    winbind \
    xvfb \
    wine64 \
    wine32 \
    x11-utils \
    curl \
    && apt clean
