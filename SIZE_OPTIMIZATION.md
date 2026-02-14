# Docker Image Size Optimization Guide

## Overview

Three Dockerfile versions are now available, optimized for different use cases:

| Version | File | Estimated Size | Use Case |
|---------|------|----------------|----------|
| **Optimized** | `Dockerfile` | ~2-3 GB | Full toolkit, production ready |
| **Minimal** | `Dockerfile.minimal` | ~800 MB - 1.2 GB | Essential tools only, small footprint |
| **Original** | `Dockerfile.original` | ~5-7 GB | All tools, full SecLists |

---

## What Was Optimized

### 1. **Multi-Stage Build** ✅
- **Before**: Everything installed in one stage
- **After**: Build stage + Runtime stage
- **Savings**: ~500-800 MB (no build tools in final image)

Build dependencies (gcc, g++, make, etc.) are now only in the builder stage and don't bloat the final image.

### 2. **SecLists Wordlists** ✅
- **Before**: Full SecLists archive (~1.2 GB)
- **After (Optimized)**: Only essential wordlists downloaded individually (~15 MB)
- **After (Minimal)**: Top 2 wordlists only (~5 MB)
- **Savings**: ~1.2 GB

**Wordlists included in optimized version:**
- `directory-list-2.3-medium.txt`
- `raft-small-words.txt`
- `raft-small-directories.txt`
- `raft-small-files.txt`
- `subdomains-top1million-5000.txt`
- `10k-most-common.txt`

**Note**: If you need full SecLists, mount it as a volume:
```bash
docker run -v /path/to/seclists:/usr/share/seclists bugbounty:2025
```

### 3. **Removed Chromium Browser** ✅
- **Before**: chromium-browser package (~200 MB)
- **After**: Removed (rarely used in CLI environment)
- **Savings**: ~200 MB

**Impact**: Tools requiring headless browser (katana with `-headless`) won't work. Use standard katana mode instead.

### 4. **Removed Node.js** ✅
- **Before**: Node.js 20 + npm (~100 MB)
- **After**: Replaced js-beautify (npm) with jsbeautifier (pip)
- **Savings**: ~100 MB

Both provide the same `js-beautify` command.

### 5. **Removed Unnecessary Packages** ✅
Removed from runtime image:
- VPN tools (wireguard, openresolv, iptables, nftables)
- vim (use docker exec with local editor instead)
- Full Ruby (ruby-full → ruby minimal + wpscan)

**Savings**: ~150 MB

### 6. **Combined RUN Layers** ✅
- **Before**: 15+ separate RUN commands
- **After**: Grouped by tool type (Go, Rust, Python)
- **Savings**: ~100-200 MB (fewer layers, better compression)

### 7. **Aggressive Cleanup** ✅
Added cleanup steps:
- `go clean -cache -modcache` after Go installs
- `rm -rf /root/.cargo/registry /root/.cargo/git` after Rust installs
- `pip3 install --no-cache-dir` for all Python packages
- Removed `.git` directories from cloned repos

**Savings**: ~300-500 MB

---

## Build Instructions

### Optimized Version (Default)
```bash
docker build -t bugbounty:2025 .
```

**Includes:**
- All essential tools (50+ tools)
- Essential wordlists only
- Multi-stage build
- Estimated size: **2-3 GB**

### Minimal Version
```bash
docker build -f Dockerfile.minimal -t bugbounty:minimal .
```

**Includes:**
- Core 15 tools only:
  - subfinder, httpx, nuclei, katana, naabu
  - ffuf, waybackurls, gau, dalfox, gf
  - anew, qsreplace, unfurl
  - masscan, sqlmap
- 2 essential wordlists
- Estimated size: **800 MB - 1.2 GB**

### Original Version (Full)
```bash
docker build -f Dockerfile.original -t bugbounty:full .
```

**Includes:**
- ALL tools (70+ tools)
- Full SecLists wordlists
- All dependencies
- Estimated size: **5-7 GB**

---

## What's Included in Each Version

### Optimized (Default) - 50+ Tools

**Subdomain Discovery:**
- subfinder, amass, assetfinder

**HTTP Probing:**
- httpx, naabu

**Crawling:**
- katana, gospider, hakrawler, waybackurls, gau

**Fuzzing:**
- ffuf, gobuster, feroxbuster, wfuzz, dirsearch

**Vulnerability Scanning:**
- nuclei, dalfox, sqlmap, ghauri

**JS Analysis:**
- subjs, LinkFinder, SecretFinder

**Password/Auth:**
- hydra, wpscan

**Utilities:**
- anew, qsreplace, unfurl, gf, uro

### Minimal - 15 Essential Tools

**Subdomain Discovery:**
- subfinder

**HTTP Probing:**
- httpx, naabu

**Crawling:**
- katana, waybackurls, gau

**Fuzzing:**
- ffuf

**Vulnerability Scanning:**
- nuclei, dalfox, sqlmap

**Utilities:**
- anew, qsreplace, unfurl, gf, uro

**Port Scanning:**
- masscan

---

## Comparison Table

| Feature | Original | Optimized | Minimal |
|---------|----------|-----------|---------|
| Go Tools | 30+ | 30+ | 13 |
| Python Tools | 12 | 12 | 1 (sqlmap) |
| Rust Tools | 1 | 1 | 0 |
| Ruby Tools | 1 | 1 | 0 |
| Compiled Tools | 2 | 2 | 1 |
| Wordlists | Full SecLists | Essential 6 | Top 2 |
| Chromium | ✅ | ❌ | ❌ |
| Node.js | ✅ | ❌ | ❌ |
| Build Tools | ✅ | ❌ | ❌ |
| Multi-stage | ❌ | ✅ | ✅ |
| Est. Size | 5-7 GB | 2-3 GB | 0.8-1.2 GB |

---

## Usage Recommendations

### Use **Optimized** when:
- ✅ You need comprehensive tooling
- ✅ Working on multiple targets/programs
- ✅ Need variety of tools for different techniques
- ✅ Want balance of features vs size

### Use **Minimal** when:
- ✅ Limited disk space
- ✅ Quick recon pipeline only
- ✅ Using cloud instances with storage limits
- ✅ Want fastest build/pull times
- ✅ Core ProjectDiscovery workflow

### Use **Original** when:
- ✅ Unlimited storage
- ✅ Need every possible tool
- ✅ Want full SecLists offline
- ✅ Don't care about image size

---

## Mounting External Resources

If you need tools/wordlists not in the image:

### Mount Full SecLists
```bash
# Download once on host
wget https://github.com/danielmiessler/SecLists/archive/refs/tags/2024.1.tar.gz
tar -xf 2024.1.tar.gz

# Mount in container
docker run -v $(pwd)/SecLists-2024.1:/usr/share/seclists bugbounty:2025
```

### Mount Custom Wordlists
```bash
docker run -v ~/my-wordlists:/root/wordlists bugbounty:2025
```

### Mount Persistent Recon Data
```bash
docker run -v $(pwd)/recon:/root/recon bugbounty:2025
```

---

## Further Size Reduction Tips

If you need even smaller:

1. **Remove tools you don't use:**
   Edit Dockerfile and comment out tools you never use

2. **Use Alpine base:**
   Switch to Alpine Linux (warning: many tools may break)

3. **Skip Nuclei templates:**
   Comment out `nuclei -update-templates` (saves ~500 MB)
   Download templates on first run instead

4. **Remove amass:**
   Amass is large (~200 MB). Use subfinder + assetfinder only

5. **Skip Python tools:**
   Many Python tools can be run from GitHub without installing

---

## Build Time Comparison

| Version | Build Time | Pull Time (if pushed) |
|---------|------------|---------------------|
| Original | ~20-30 min | ~5-10 min |
| Optimized | ~15-20 min | ~2-5 min |
| Minimal | ~8-12 min | ~1-2 min |

*Times vary based on network speed and hardware*

---

## Recommendation

**Start with the Optimized version (default `Dockerfile`)** - it provides the best balance of:
- Complete toolset for professional bug bounty hunting
- Reasonable size (~2-3 GB)
- Multi-stage build optimization
- All scripts and aliases work
- No missing dependencies

Switch to Minimal only if storage is critically limited.

---

## Questions?

- Missing a critical tool in Minimal? → Use Optimized
- Need full SecLists? → Mount it as volume or use Original
- Want smallest possible? → Use Minimal + mount tools as needed

---

Last Updated: 2025-02-14
