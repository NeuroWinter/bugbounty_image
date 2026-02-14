FROM docker.io/ubuntu:22.04 AS builder
LABEL Description="Bug Bounty Toolkit 2025 - Optimized"

ENV DEBIAN_FRONTEND=noninteractive \
    GOPATH=/root/go \
    GO111MODULE=on

ENV PATH=/root/go/bin:/usr/local/go/bin:/root/.cargo/bin:/root/.local/bin:$PATH

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git wget curl ca-certificates \
    make gcc g++ libffi-dev \
    libgnutls28-dev libcurl4-gnutls-dev libssl-dev libpcap-dev \
    python3 python3-pip ruby-full \
    && rm -rf /var/lib/apt/lists/*

# INSTALL GO 1.22
RUN wget -q https://go.dev/dl/go1.22.1.linux-amd64.tar.gz -O /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz

# INSTALL RUST
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# BUILD ALL GO TOOLS IN ONE LAYER
RUN echo "[+] Installing Go tools..." && \
    # ProjectDiscovery Suite
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest && \
    go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest && \
    go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest && \
    go install -v github.com/projectdiscovery/katana/cmd/katana@latest && \
    go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest && \
    go install -v github.com/projectdiscovery/cvemap/cmd/cvemap@latest && \
    go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest && \
    go install -v github.com/projectdiscovery/uncover/cmd/uncover@latest && \
    # Subdomain & Asset Discovery
    go install -v github.com/owasp-amass/amass/v4/...@master && \
    go install -v github.com/tomnomnom/assetfinder@latest && \
    # URL & Endpoint Discovery
    go install -v github.com/tomnomnom/waybackurls@latest && \
    go install -v github.com/lc/gau/v2/cmd/gau@latest && \
    go install -v github.com/jaeles-project/gospider@latest && \
    go install -v github.com/hakluke/hakrawler@latest && \
    # Fuzzing
    go install -v github.com/ffuf/ffuf/v2@latest && \
    go install -v github.com/OJ/gobuster/v3@latest && \
    # Vulnerability Scanning
    go install -v github.com/hahwul/dalfox/v2@latest && \
    go install -v github.com/tomnomnom/gf@latest && \
    go install -v github.com/m4dm0e/dirdar@latest && \
    go install -v github.com/Hackmanit/Web-Cache-Vulnerability-Scanner@latest && \
    go install -v github.com/mlcsec/headi@latest && \
    # Utilities
    go install -v github.com/tomnomnom/anew@latest && \
    go install -v github.com/tomnomnom/qsreplace@latest && \
    go install -v github.com/tomnomnom/unfurl@latest && \
    go install -v github.com/tomnomnom/hacks/html-tool@latest && \
    # JS Analysis
    go install -v github.com/lc/subjs@latest && \
    # Clean Go cache
    go clean -cache -modcache

# BUILD RUST TOOLS
RUN cargo install feroxbuster && \
    rm -rf /root/.cargo/registry /root/.cargo/git

# BUILD COMPILED TOOLS
RUN git clone --depth 1 https://github.com/robertdavidgraham/masscan /tmp/masscan && \
    cd /tmp/masscan && make -j$(nproc) && make install && \
    git clone --depth 1 https://github.com/vanhauser-thc/thc-hydra /tmp/thc-hydra && \
    cd /tmp/thc-hydra && ./configure && make -j$(nproc) && make install && \
    rm -rf /tmp/masscan /tmp/thc-hydra

# PYTHON TOOLS
WORKDIR /root/tools
RUN pip3 install --no-cache-dir \
        wfuzz uro pyyaml requests beautifulsoup4 waymore jsbeautifier && \
    # Clone and install Python tools
    git clone --depth 1 https://github.com/sqlmapproject/sqlmap.git && \
    git clone --depth 1 https://github.com/r0oth3x49/ghauri.git && \
    cd ghauri && pip3 install --no-cache-dir . && cd .. && \
    git clone --depth 1 https://github.com/ticarpi/jwt_tool.git && \
    cd jwt_tool && pip3 install --no-cache-dir -r requirements.txt && cd .. && \
    git clone --depth 1 https://github.com/s0md3v/Arjun.git && \
    cd Arjun && pip3 install --no-cache-dir . && cd .. && \
    git clone --depth 1 https://github.com/devanshbatham/ParamSpider.git && \
    cd ParamSpider && pip3 install --no-cache-dir . && cd .. && \
    git clone --depth 1 https://github.com/GerbenJavado/LinkFinder.git && \
    cd LinkFinder && pip3 install --no-cache-dir -r requirements.txt && python3 setup.py install && cd .. && \
    git clone --depth 1 https://github.com/m4ll0k/SecretFinder.git && \
    cd SecretFinder && pip3 install --no-cache-dir -r requirements.txt && cd .. && \
    git clone --depth 1 https://github.com/s0md3v/Photon.git && \
    pip3 install --no-cache-dir -r Photon/requirements.txt && \
    git clone --depth 1 https://github.com/maurosoria/dirsearch.git && \
    pip3 install --no-cache-dir -r dirsearch/requirements.txt && \
    git clone --depth 1 https://github.com/initstring/cloud_enum.git && \
    pip3 install --no-cache-dir -r cloud_enum/requirements.txt && \
    # Remove .git directories
    find . -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true

# RUBY TOOLS
RUN gem install wpscan --no-document

# Download only essential wordlists (not full SecLists)
RUN mkdir -p /usr/share/wordlists && \
    # Common web content
    wget -q https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/directory-list-2.3-medium.txt \
         -O /usr/share/wordlists/directory-list-2.3-medium.txt && \
    wget -q https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/raft-small-words.txt \
         -O /usr/share/wordlists/raft-small-words.txt && \
    wget -q https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/raft-small-directories.txt \
         -O /usr/share/wordlists/raft-small-directories.txt && \
    wget -q https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/raft-small-files.txt \
         -O /usr/share/wordlists/raft-small-files.txt && \
    # Subdomains
    wget -q https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/subdomains-top1million-5000.txt \
         -O /usr/share/wordlists/subdomains-top1million-5000.txt && \
    # Common passwords
    wget -q https://raw.githubusercontent.com/danielmiessler/SecLists/master/Passwords/Common-Credentials/10k-most-common.txt \
         -O /usr/share/wordlists/10k-most-common.txt

# ============================================
# FINAL STAGE - Runtime image
# ============================================
FROM docker.io/ubuntu:22.04
LABEL Description="Bug Bounty Toolkit 2025 - Optimized"

ENV DEBIAN_FRONTEND=noninteractive \
    GOPATH=/root/go \
    GO111MODULE=on

ENV PATH=/root/go/bin:/usr/local/go/bin:/root/.cargo/bin:/root/.local/bin:$PATH

# Install ONLY runtime dependencies (no build tools)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # Core utilities (minimal)
        git curl wget ca-certificates \
        # Python runtime
        python3 python3-pip \
        # Ruby runtime (minimal)
        ruby \
        # Network tools (essential only)
        jq nmap dnsutils iputils-ping iproute2 netcat-openbsd \
        # Required libraries
        libgnutls30 libcurl4 libssl3 libpcap0.8 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy Go binaries
COPY --from=builder /root/go/bin/* /root/go/bin/

# Copy Rust binaries
COPY --from=builder /root/.cargo/bin/feroxbuster /root/.cargo/bin/

# Copy compiled tools
COPY --from=builder /usr/local/bin/masscan /usr/local/bin/
COPY --from=builder /usr/local/bin/hydra /usr/local/bin/

# Copy Python tools and installed packages
COPY --from=builder /root/tools /root/tools
COPY --from=builder /usr/local/lib/python3.10/dist-packages /usr/local/lib/python3.10/dist-packages
COPY --from=builder /usr/local/bin/waymore /usr/local/bin/
COPY --from=builder /usr/local/bin/js-beautify /usr/local/bin/

# Copy wpscan
COPY --from=builder /var/lib/gems /var/lib/gems
COPY --from=builder /usr/local/bin/wpscan /usr/local/bin/

# Copy wordlists
COPY --from=builder /usr/share/wordlists /usr/share/wordlists

# Create symlink for legacy path
RUN ln -s /usr/share/wordlists /usr/share/seclists

# Create jwt_tool symlink
RUN ln -s /root/tools/jwt_tool/jwt_tool.py /usr/local/bin/jwt_tool && \
    chmod +x /root/tools/jwt_tool/jwt_tool.py

# GF PATTERNS
RUN git clone --depth 1 https://github.com/1ndianl33t/Gf-Patterns /tmp/gf && \
    mkdir -p ~/.gf && mv /tmp/gf/*.json ~/.gf/ && rm -rf /tmp/gf

# NUCLEI TEMPLATES (download in runtime for freshness)
RUN nuclei -update-templates

# GAU CONFIG
RUN echo 'providers = ["wayback", "commoncrawl", "otx", "urlscan"]' > /root/.gau.toml

# Create directory structure
RUN mkdir -p ~/targets ~/recon ~/reports

# COPY SCRIPTS AND ALIASES
COPY scripts/recon-pipeline /usr/local/bin/recon-pipeline
COPY scripts/xss-hunt /usr/local/bin/xss-hunt
RUN chmod +x /usr/local/bin/recon-pipeline /usr/local/bin/xss-hunt

COPY bash_aliases /root/.bash_aliases
RUN echo "source ~/.bash_aliases" >> ~/.bashrc

# Verify critical tools
RUN echo "[+] Verifying installation..." && \
    httpx -version && \
    nuclei -version && \
    subfinder -version && \
    katana -version && \
    echo "[+] All tools installed successfully!"

WORKDIR /root
CMD ["/bin/bash"]
