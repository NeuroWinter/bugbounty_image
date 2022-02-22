FROM docker.io/ubuntu:20.04
LABEL Description="This is a docker container that contains all the tools I use for bug hunting"

# First lets create the dir for our tools
RUN mkdir ~/tools
RUN mkdir ~/targets
RUN apt update && apt upgrade -y
RUN apt install git python3 python3-pip wget curl libgnutls28-dev libcurl4-gnutls-dev libssl-dev jq vim libpcap0.8 iputils-ping wireguard nmap iproute2 openresolv iptables iproute2 wireguard-tools nftables -y


WORKDIR /root/tools/

# Install Photon
RUN git clone https://github.com/s0md3v/Photon.git 
RUN cd Photon && pip3 install -r requirements.txt

# Install Amass
# first we need to install go
RUN mkdir ~/apps/ && cd ~/apps/ && \
    wget https://golang.org/dl/go1.17.3.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.17.3.linux-amd64.tar.gz
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
RUN git clone https://github.com/maurosoria/dirsearch.git && \
    cd dirsearch && \
    pip install -r requirements.txt

# Install Ajurn
RUN git clone https://github.com/s0md3v/Arjun.git && cd Arjun && \
    python3 setup.py install

# Install Fuff
RUN go get -u github.com/ffuf/ffuf

# Install cloud-enum
RUN git clone https://github.com/initstring/cloud_enum.git && \
    cd cloud_enum && pip3 install -r requirements.txt

# Install subfinder 
RUN GO111MODULE=on go get -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder

# Install RustScan
RUN mkdir rustscan && cd rustscan && \
    wget https://github.com/RustScan/RustScan/releases/download/2.0.1/rustscan_2.0.1_amd64.deb && \
    dpkg -i rustscan_2.0.1_amd64.deb 

# Install httpx
RUN GO111MODULE=on go get -v github.com/projectdiscovery/httpx/cmd/httpx

# Install GF (https://github.com/tomnomnom/gf) and GF-patterns (https://github.com/1ndianl33t/Gf-Patterns)
RUN go get -u github.com/tomnomnom/gf
RUN git clone https://github.com/1ndianl33t/Gf-Patterns && \
    mkdir ~/.gf && \
    mv ~/tools/Gf-Patterns/*.json ~/.gf

RUN apt install -y ruby-full && \
    gem install wpscan

# Install Hydra
RUN git clone https://github.com/vanhauser-thc/thc-hydra.git && \
    cd thc-hydra && \
    ./configure && \
    make && \
    make install

# Install DirDar
RUN go get -u github.com/m4dm0e/dirdar

# Install Web Cache Vulnerability Scanner
RUN go install -v github.com/Hackmanit/Web-Cache-Vulnerability-Scanner@latest

# Install headi
RUN go get github.com/mlcsec/headi

COPY .bash_aliases ../
