FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -y update
RUN apt-get install -y build-essential wget unzip

WORKDIR /usr/local

# install SEGGER Embedded Studio version 5.42a (the same version expected by the nRF5 SDK)
RUN wget -q https://www.segger.com/downloads/embedded-studio/Setup_EmbeddedStudio_ARM_v542a_linux_x64.tar.gz && tar xf Setup_EmbeddedStudio_ARM_v542a_linux_x64.tar.gz --strip-components=1 arm_segger_embedded_studio_542a_linux_x64/install_segger_embedded_studio && rm Setup_EmbeddedStudio_ARM_v542a_linux_x64.tar.gz
RUN apt-get install -y libxrender1 libxext6
RUN yes yes | ./install_segger_embedded_studio --copy-files-to /usr/local/segger_embedded_studio_V5.42a

# install nRF command line tools, including nrfjprog for programming using SEGGER J-Link programmers/debuggers
RUN apt-get install -y libusb-1.0-0 apt-utils udev
RUN wget -q https://nsscprodmedia.blob.core.windows.net/prod/software-and-other-downloads/desktop-software/nrf-command-line-tools/sw/versions-10-x-x/10-23-2/nrf-command-line-tools_10.23.2_amd64.deb && dpkg -i nrf-command-line-tools_10.23.2_amd64.deb
RUN echo '#!/bin/bash\necho not running udevadm "$@"' > /usr/bin/udevadm && chmod +x /usr/bin/udevadm && apt-get install -y /opt/nrf-command-line-tools/share/JLink_Linux_V788j_x86_64.deb --fix-broken

WORKDIR /project