# syntax=docker/dockerfile:1.4
# Bug Bounty Toolkit 2025 - WORKING VERSION
# Version: 2.1

# ============================================================================
# STAGE 1: Go Tools Builder
# ============================================================================
FROM golang:1.24.1-alpine AS go-builder

ENV GOOS=linux \
    GOARCH=amd64 \
    GOTOOLCHAIN=auto

RUN apk add --no-cache git

# Build all Go tools statically (no CGO)
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest && \
    CGO_ENABLED=0 go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest && \
    CGO_ENABLED=0 go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest && \
    CGO_ENABLED=0 go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest && \
    CGO_ENABLED=0 go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest && \
    CGO_ENABLED=0 go install -v github.com/projectdiscovery/uncover/cmd/uncover@latest && \
    CGO_ENABLED=0 go install -v github.com/projectdiscovery/katana/cmd/katana@latest && \
    CGO_ENABLED=0 go install -v github.com/owasp-amass/amass/v4/...@latest && \
    CGO_ENABLED=0 go install -v github.com/tomnomnom/waybackurls@latest && \
    CGO_ENABLED=0 go install -v github.com/lc/gau/v2/cmd/gau@latest && \
    CGO_ENABLED=0 go install -v github.com/ffuf/ffuf/v2@latest && \
    CGO_ENABLED=0 go install -v github.com/hahwul/dalfox/v2@latest && \
    CGO_ENABLED=0 go install -v github.com/tomnomnom/gf@latest && \
    CGO_ENABLED=0 go install -v github.com/tomnomnom/anew@latest && \
    CGO_ENABLED=0 go install -v github.com/tomnomnom/qsreplace@latest && \
    CGO_ENABLED=0 go install -v github.com/tomnomnom/unfurl@latest && \
    CGO_ENABLED=0 go install -v github.com/lc/subjs@latest

# ============================================================================
# STAGE 2: Final Runtime Image
# ============================================================================
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/usr/local/bin:/root/.local/bin:$PATH \
    TERM=xterm-256color

# ============================================================================
# Install System Dependencies
# ============================================================================
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        git curl wget ca-certificates jq \
        python3 python3-pip \
        gcc g++ make \
        libssl-dev libpcap-dev \
        dnsutils nmap netcat-openbsd \
        chromium-browser \
        sqlite3 && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ============================================================================
# Copy Go Tools FIRST (before any Python installs)
# ============================================================================
COPY --from=go-builder /go/bin/* /usr/local/bin/

# Rename httpx to prevent Python conflict
RUN mv /usr/local/bin/httpx /usr/local/bin/httpx-go

# ============================================================================
# Install Python Tools
# ============================================================================
RUN pip3 install --no-cache-dir --break-system-packages \
        uro \
        pyyaml \
        requests \
        beautifulsoup4 \
        waymore

# ============================================================================
# Install Git-based Python Tools
# ============================================================================
WORKDIR /root/tools

RUN git clone --depth 1 --branch 1.8 https://github.com/sqlmapproject/sqlmap.git sqlmap && \
    git clone --depth 1 https://github.com/ticarpi/jwt_tool.git jwt_tool && \
    cd jwt_tool && pip3 install --no-cache-dir --break-system-packages -r requirements.txt && \
    chmod +x jwt_tool.py && ln -s /root/tools/jwt_tool/jwt_tool.py /usr/local/bin/jwt_tool && cd .. && \
    git clone --depth 1 https://github.com/s0md3v/Arjun.git Arjun && \
    cd Arjun && pip3 install --no-cache-dir --break-system-packages . && cd .. && \
    git clone --depth 1 https://github.com/m4ll0k/SecretFinder.git SecretFinder && \
    cd SecretFinder && pip3 install --no-cache-dir --break-system-packages -r requirements.txt && cd .. && \
    git clone --depth 1 https://github.com/maurosoria/dirsearch.git dirsearch && \
    pip3 install --no-cache-dir --break-system-packages -r dirsearch/requirements.txt && \
    git clone --depth 1 https://github.com/s0md3v/Photon.git Photon && \
    pip3 install --no-cache-dir --break-system-packages -r Photon/requirements.txt && \
    chmod +x dirsearch/dirsearch.py SecretFinder/SecretFinder.py && \
    ln -s /root/tools/dirsearch/dirsearch.py /usr/local/bin/dirsearch && \
    ln -s /root/tools/SecretFinder/SecretFinder.py /usr/local/bin/secretfinder && \
    find . -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true

# ============================================================================
# Build C Tools
# ============================================================================
RUN git clone --depth 1 https://github.com/robertdavidgraham/masscan.git /tmp/masscan && \
    cd /tmp/masscan && make -j$(nproc) && make install && rm -rf /tmp/masscan

# ============================================================================
# Install Node Tools
# ============================================================================
RUN npm install -g js-beautify && npm cache clean --force

# ============================================================================
# Setup Tool Configurations
# ============================================================================
RUN git clone --depth 1 https://github.com/1ndianl33t/Gf-Patterns /tmp/gf-patterns && \
    mkdir -p ~/.gf && mv /tmp/gf-patterns/*.json ~/.gf/ && rm -rf /tmp/gf-patterns

RUN nuclei -update-templates -silent

RUN echo 'providers = ["wayback", "commoncrawl", "otx", "urlscan"]' > /root/.gau.toml

# ============================================================================
# Download SecLists
# ============================================================================
RUN wget -q https://github.com/danielmiessler/SecLists/archive/refs/tags/2026.1.tar.gz -O /tmp/seclists.tar.gz && \
    tar -xzf /tmp/seclists.tar.gz -C /tmp && \
    mv /tmp/SecLists-2026.1 /usr/share/seclists && \
    rm /tmp/seclists.tar.gz

# ============================================================================
# Create Directory Structure
# ============================================================================
RUN mkdir -p ~/targets ~/recon ~/reports ~/scope ~/configs

# ============================================================================
# Copy Scripts and Config
# ============================================================================
COPY scripts/* /usr/local/bin/
RUN chmod +x /usr/local/bin/*

COPY bash_aliases /root/.bash_aliases
COPY VERSION /root/VERSION

# ============================================================================
# Fix bash_aliases to use httpx-go
# ============================================================================
RUN sed -i 's|/usr/local/bin/httpx|httpx-go|g' /root/.bash_aliases && \
    sed -i 's|httpx -silent|httpx-go -silent|g' /root/.bash_aliases && \
    sed -i "s|alias probe='httpx -silent'|alias probe='httpx-go -silent'|g" /root/.bash_aliases && \
    sed -i "s|alias live='httpx -silent|alias live='httpx-go -silent|g" /root/.bash_aliases

# ============================================================================
# Setup Bash Environment
# ============================================================================
RUN echo 'source ~/.bash_aliases' >> ~/.bashrc && \
    echo '' >> ~/.bashrc && \
    echo 'cat << "EOF"' >> ~/.bashrc && \
    echo '  ╔═══════════════════════════════════════════╗' >> ~/.bashrc && \
    echo '  ║   Bug Bounty Toolkit v2.1                ║' >> ~/.bashrc && \
    echo '  ║   Type: bbhelp for commands              ║' >> ~/.bashrc && \
    echo '  ╚═══════════════════════════════════════════╝' >> ~/.bashrc && \
    echo 'EOF' >> ~/.bashrc

RUN echo "$(date +%Y-%m-%d)" > /root/BUILD_DATE

# ============================================================================
# Runtime Configuration
# ============================================================================
WORKDIR /root
VOLUME ["/root/targets", "/root/recon", "/root/reports"]

CMD ["/bin/bash"]
