FROM docker.io/ubuntu:20.04
LABEL Description="This is a docker container that contains all the tools I use for bug hunting"

# First lets create the dir for our tools
RUN mkdir ~/tools
RUN apt update && apt upgrade -y
RUN apt install git python3 python3-pip wget curl libgnutls28-dev libcurl4-gnutls-dev libssl-dev jq vim libpcap0.8 iputils-ping wireguard -y

WORKDIR /root/tools/

# Install Photon
RUN git clone https://github.com/s0md3v/Photon.git 
RUN cd Photon && pip3 install -r requirements.txt

# Install Amass
# first we need to install go
RUN mkdir ~/apps/ && cd ~/apps/ && \
    wget https://golang.org/dl/go1.15.8.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.15.8.linux-amd64.tar.gz
ENV PATH=$PATH:/usr/local/go/bin
ENV GO111MODULE=on
RUN go get -v github.com/OWASP/Amass/v3/...
ENV PATH=$PATH:~/go/bin

# We also need to install httprobe!
RUN go get -u github.com/tomnomnom/httprobe


# Install MassScan
RUN apt-get --assume-yes install git make gcc && \
    git clone https://github.com/robertdavidgraham/masscan && \
    cd masscan && \
    make

# Time to get the wordlists!
RUN git clone https://github.com/danielmiessler/SecLists.git

# Now lets install js-beautify
# for this we need node and npm
RUN curl -fsSL https://deb.nodesource.com/setup_14.x | bash -
RUN apt-get install -y nodejs
RUN npm -g install js-beautify

# Now lets install wfuzz!
RUN pip3 install wfuzz

# AND sqlmap!
RUN git clone --depth 1 https://github.com/sqlmapproject/sqlmap.git sqlmap-dev

# Now dirsearch
RUN git clone https://github.com/maurosoria/dirsearch.git

# Install Ajurn
RUN git clone https://github.com/s0md3v/Arjun.git && cd Arjun && \
    python3 setup.py install

COPY .bash_aliases ../
