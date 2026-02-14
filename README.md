# Bug Bounty Toolkit 2025

A Docker image containing essential tools for bug bounty hunting. Built with pre-configured pipelines and aliases.

Multi-stage build reduces image size. See [SIZE_OPTIMIZATION.md](SIZE_OPTIMIZATION.md) for details.

## Quick Start

```bash
# Build the image
docker build -t bugbounty:2025 .

# Run interactively
docker run -it --rm -v $(pwd)/targets:/root/targets -v $(pwd)/recon:/root/recon bugbounty:2025

# Run with network capabilities (for masscan, nmap)
docker run -it --rm --cap-add=NET_ADMIN --cap-add=NET_RAW \
    -v $(pwd)/targets:/root/targets \
    -v $(pwd)/recon:/root/recon \
    bugbounty:2025
```

## Available Versions

- `Dockerfile` - Optimized build, ~2-3 GB
- `Dockerfile.minimal` - Minimal build, ~800 MB, essential tools only
- `Dockerfile.original` - Full build, ~5-7 GB, all tools and full SecLists

## Standard Workflow

See [WORKFLOW.md](WORKFLOW.md) for a complete recon workflow using the minimal docker image.

## Directory Structure

```
~/
├── tools/          # Installed tools (sqlmap, dirsearch, etc.)
├── targets/        # Mount your target lists here
├── recon/          # Output directory for recon data
├── reports/        # Generated reports
└── .gf/            # GF patterns for grep filtering
```

## Wordlists

Essential wordlists at `/usr/share/wordlists/`:
- `directory-list-2.3-medium.txt`
- `raft-small-words.txt`
- `raft-small-directories.txt`
- `raft-small-files.txt`
- `subdomains-top1million-5000.txt`
- `10k-most-common.txt`

Full SecLists not included in optimized build. Mount if needed:
```bash
docker run -v /path/to/SecLists:/usr/share/seclists bugbounty:2025
```

Original version includes full SecLists at `/usr/share/seclists/`

---

# Tool Reference

## Phase 1: Subdomain & Asset Discovery

### subfinder
Fast passive subdomain enumeration using multiple sources.

```bash
# Basic usage
subfinder -d target.com -o subs.txt

# Silent mode (just domains)
subfinder -d target.com -silent

# Use all sources (slower but thorough)
subfinder -d target.com -all -silent

# Recursive enumeration
subfinder -d target.com -recursive -silent
```
**When to use:** First step in recon. Run against every target domain.

### amass
Most comprehensive subdomain enumeration (slower but thorough).

```bash
# Passive only (fast, no direct contact)
amass enum -passive -d target.com

# Active mode with DNS resolution
amass enum --ip --active -d target.com -o amass.txt

# With brute forcing
amass enum -brute -d target.com -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt
```
**When to use:** When you need maximum coverage. Run alongside subfinder.

### assetfinder
Quick asset discovery from various sources.

```bash
assetfinder target.com
assetfinder --subs-only target.com
```
**When to use:** Quick supplementary subdomain check.

### crtsh / certspotter (aliases)
Certificate transparency log searches.

```bash
# Search crt.sh
crtsh target.com

# Search certspotter
certspotter target.com

# Multiple domains
crtshmulti domains.txt
```
**When to use:** Find subdomains via SSL certificate records.

---

## Phase 2: Host Probing & Fingerprinting

### httpx
Probe hosts for HTTP services and extract metadata.

```bash
# Basic probe
cat subs.txt | httpx -silent

# With status codes, titles, tech detection
cat subs.txt | httpx -status-code -title -tech-detect

# Filter by status
cat subs.txt | httpx -mc 200,301,302,403

# Extract specific info
cat subs.txt | httpx -json -o httpx.json
```
**When to use:** After subdomain enumeration to find live web hosts.

### naabu
Fast port scanner from ProjectDiscovery.

```bash
# Top 100 ports
naabu -host target.com

# Full port scan
naabu -host target.com -p -

# From list
naabu -list subs.txt -top-ports 1000

# With service detection
naabu -host target.com -nmap-cli 'nmap -sV'
```
**When to use:** Find non-standard ports before deeper enumeration.

### masscan
Ultra-fast port scanner for large ranges.

```bash
# Quick web ports
masscan -p80,443,8080,8443 192.168.1.0/24 --rate=1000

# Common service ports (alias: ms)
ms 10.0.0.0/8

# Output to file
masscan -p1-65535 target.com -oG masscan.txt
```
**When to use:** Scanning large IP ranges or CIDR blocks.

---

## Phase 3: Crawling & URL Discovery

### katana
Next-gen web crawler from ProjectDiscovery.

```bash
# Basic crawl
katana -u https://target.com

# Deep crawl with JS parsing
katana -u https://target.com -d 5 -jc

# From list
katana -list live.txt -d 3 -silent | anew urls.txt

# Headless browser mode
katana -u https://target.com -headless
```
**When to use:** Primary crawler for discovering endpoints.

### gospider
Fast web spider with good JS parsing.

```bash
gospider -s https://target.com -d 3 -c 10

# From list
gospider -S live.txt -d 2 -c 5 -o gospider_out
```
**When to use:** Supplementary crawler, good for finding hidden paths.

### waybackurls
Fetch historical URLs from Wayback Machine.

```bash
echo target.com | waybackurls

# From list
cat domains.txt | waybackurls | anew wayback.txt
```
**When to use:** Find old/removed endpoints that may still work.

### gau (GetAllUrls)
Fetch URLs from multiple sources (Wayback, CommonCrawl, URLScan).

```bash
echo target.com | gau

# Exclude static files
echo target.com | gau --blacklist png,jpg,gif,css,woff,svg

# With providers
echo target.com | gau --providers wayback,commoncrawl,otx
```
**When to use:** Comprehensive historical URL gathering.

### waymore
Enhanced Wayback Machine tool.

```bash
waymore -i target.com -mode U
```
**When to use:** When waybackurls doesn't find enough.

---

## Phase 4: Content Discovery & Fuzzing

### ffuf
Fast web fuzzer (the standard for 2025).

```bash
# Directory fuzzing
ffuf -u https://target.com/FUZZ -w /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt

# With extensions
ffuf -u https://target.com/FUZZ -w wordlist.txt -e .php,.asp,.html

# Parameter fuzzing
ffuf -u https://target.com/page?FUZZ=value -w params.txt

# POST data fuzzing
ffuf -u https://target.com/login -X POST -d "user=FUZZ&pass=test" -w users.txt

# Filter by size/words/lines
ffuf -u https://target.com/FUZZ -w wordlist.txt -fs 1234 -fc 404
```
**When to use:** Primary fuzzing tool for directories, files, parameters.

### feroxbuster
Recursive content discovery (Rust, very fast).

```bash
# Basic scan
feroxbuster -u https://target.com

# With wordlist and extensions
feroxbuster -u https://target.com -w wordlist.txt -x php,html

# Recursive depth
feroxbuster -u https://target.com -d 3
```
**When to use:** When you need aggressive recursive discovery.

### gobuster
Directory/DNS/vhost brute forcing.

```bash
# Directory mode
gobuster dir -u https://target.com -w wordlist.txt

# DNS subdomain mode
gobuster dns -d target.com -w subdomains.txt

# Vhost discovery
gobuster vhost -u https://target.com -w vhosts.txt
```
**When to use:** Good for vhost and DNS brute forcing.

### dirsearch
Feature-rich directory scanner.

```bash
# Basic (use alias dirsearchx for full options)
dirsearchx https://target.com

# Manual
python3 ~/tools/dirsearch/dirsearch.py -u https://target.com -e php,html
```
**When to use:** When you need detailed JSON output and recursion control.

---

## Phase 5: Parameter Discovery

### Arjun
Hidden parameter discovery.

```bash
arjun -u https://target.com/page

# From list (use alias aj)
aj urls.txt

# With custom wordlist
arjun -u https://target.com/page -w params.txt
```
**When to use:** Find hidden GET/POST parameters for further testing.

### ParamSpider
Parameter extraction from web archives.

```bash
paramspider -d target.com

# With output
paramspider -d target.com -o params.txt
```
**When to use:** Quick parameter enumeration from historical data.

### unfurl
URL parsing utility.

```bash
# Extract parameter keys
cat urls.txt | unfurl keys

# Extract values
cat urls.txt | unfurl values

# Extract paths
cat urls.txt | unfurl paths
```
**When to use:** Parse URLs to extract parameters for testing.

---

## Phase 6: Vulnerability Scanning

### nuclei
THE vulnerability scanner for 2025. Template-based, community-driven.

```bash
# Basic scan (all templates)
nuclei -u https://target.com

# Scan list of hosts
nuclei -l live.txt -o nuclei.txt

# By severity
nuclei -l live.txt -severity critical,high

# Specific templates
nuclei -l live.txt -t cves/
nuclei -l live.txt -t exposures/
nuclei -l live.txt -tags sqli,xss,rce

# Update templates
nuclei -update-templates

# Rate limiting (be nice)
nuclei -l live.txt -rate-limit 50 -c 20
```
**When to use:** Run against all live hosts. Primary automated scanner.

### dalfox
XSS scanner with WAF bypass capabilities.

```bash
# Single URL
dalfox url https://target.com/page?q=test

# From pipe (with gf patterns)
cat urls.txt | gf xss | dalfox pipe

# With custom payloads
dalfox url https://target.com/page?q=test --custom-payload payloads.txt
```
**When to use:** After finding parameters, test for XSS.

### sqlmap
SQL injection detection and exploitation.

```bash
# Basic test
sqlmap -u "https://target.com/page?id=1"

# From request file (Burp)
sqlmap -r request.txt

# Aggressive mode
sqlmap -u "https://target.com/page?id=1" --level=5 --risk=3

# Batch mode (auto answers)
sqlmap -u "https://target.com/page?id=1" --batch
```
**When to use:** When you suspect SQLi or after gf sqli filtering.

### ghauri
Modern SQLi tool (alternative to sqlmap).

```bash
ghauri -u "https://target.com/page?id=1"
ghauri -u "https://target.com/page?id=1" --batch
```
**When to use:** When sqlmap doesn't work or for a second opinion.

---

## Phase 7: JavaScript Analysis

### LinkFinder
Extract endpoints from JavaScript files.

```bash
python3 ~/tools/LinkFinder/linkfinder.py -i https://target.com/app.js -o cli

# From file
python3 ~/tools/LinkFinder/linkfinder.py -i app.js -o cli
```
**When to use:** Analyze JS files for hidden API endpoints.

### SecretFinder
Find secrets in JavaScript.

```bash
python3 ~/tools/SecretFinder/SecretFinder.py -i https://target.com/app.js -o cli
```
**When to use:** Look for API keys, tokens in JS files.

### jss (alias)
Quick JS secret grep.

```bash
jss https://target.com/app.js

# Multiple files
mjss js_urls.txt
```
**When to use:** Fast check for secrets in JS.

### subjs
Discover JS files from a list of hosts.

```bash
cat live.txt | subjs
```
**When to use:** Find all JS files across multiple hosts.

---

## Phase 8: Specialized Tools

### wpscan
WordPress vulnerability scanner.

```bash
# Full scan (use alias wpsa)
wpsa https://wordpress-site.com

# Manual with API token
wpscan --url https://target.com --api-token YOUR_TOKEN -e ap,at,u
```
**When to use:** Any WordPress site.

### jwt_tool
JWT analysis and exploitation.

```bash
jwt_tool <token>
jwt_tool <token> -T  # Tamper mode
jwt_tool <token> -C -d wordlist.txt  # Crack secret
```
**When to use:** When you find JWT tokens.

### hydra
Network login brute forcing.

```bash
# SSH
hydra -l admin -P passwords.txt ssh://target.com

# HTTP POST
hydra -l admin -P passwords.txt target.com http-post-form "/login:user=^USER^&pass=^PASS^:Invalid"
```
**When to use:** Brute force login pages (with permission!).

---

## Utility Tools

### anew
Append only new unique lines to a file.

```bash
cat new_subs.txt | anew all_subs.txt
```
**When to use:** Combine results without duplicates.

### qsreplace
Replace query string values.

```bash
cat urls.txt | qsreplace "FUZZ"
cat urls.txt | qsreplace '"><script>alert(1)</script>'
```
**When to use:** Prepare URLs for fuzzing.

### uro
URL deduplication and filtering.

```bash
cat urls.txt | uro
```
**When to use:** Clean up URL lists before testing.

### gf
Grep for patterns (XSS, SQLi, SSRF, etc.).

```bash
cat urls.txt | gf xss
cat urls.txt | gf sqli
cat urls.txt | gf ssrf
cat urls.txt | gf redirect

# List available patterns
ls ~/.gf/
```
**When to use:** Filter URLs by vulnerability type.

---

# Workflows

## Quick Recon Pipeline

```bash
# Use the built-in function
fullrecon target.com

# Or the script
recon-pipeline target.com
```

## Manual Step-by-Step

```bash
# 1. Subdomain enumeration
subfinder -d target.com -silent | anew subs.txt
amass enum -passive -d target.com | anew subs.txt
crtsh target.com | anew subs.txt

# 2. Probe live hosts
cat subs.txt | httpx -silent | anew live.txt

# 3. Port scan interesting hosts
naabu -list live.txt -top-ports 1000 -o ports.txt

# 4. Crawl and gather URLs
cat live.txt | katana -d 3 -silent | anew urls.txt
cat live.txt | waybackurls | anew urls.txt
cat live.txt | gau --blacklist png,jpg,gif | anew urls.txt

# 5. Extract JS files
cat urls.txt | grep -iE '\.js$' | anew js.txt

# 6. Run nuclei
nuclei -l live.txt -severity critical,high,medium -o nuclei.txt

# 7. Hunt for specific vulns
cat urls.txt | gf xss | uro | dalfox pipe -o xss.txt
cat urls.txt | gf sqli | uro > sqli_candidates.txt
```

## XSS Hunting Pipeline

```bash
# Gather URLs with parameters
cat live.txt | katana -d 3 -jc -silent | grep "=" | anew params.txt

# Filter for XSS candidates
cat params.txt | gf xss | uro | anew xss_candidates.txt

# Test with dalfox
cat xss_candidates.txt | dalfox pipe --silence -o xss_results.txt

# Or use the alias
cat params.txt | scan-xss
```

## JS Secrets Pipeline

```bash
# Find JS files
cat live.txt | katana -d 3 -jc -silent | grep -iE '\.js$' | anew js.txt

# Extract endpoints
cat js.txt | while read url; do
    python3 ~/tools/LinkFinder/linkfinder.py -i $url -o cli
done | anew endpoints.txt

# Find secrets
cat js.txt | while read url; do
    python3 ~/tools/SecretFinder/SecretFinder.py -i $url -o cli
done | anew secrets.txt

# Quick grep for keys (use alias)
mjss js.txt
```

## API Hunting

```bash
# Find API endpoints
cat urls.txt | grep -iE "/api/|/v[0-9]+/" | anew api.txt

# Fuzz for more
ffuf -u https://target.com/api/FUZZ -w /usr/share/seclists/Discovery/Web-Content/api/api-endpoints.txt

# Test with nuclei
nuclei -l api.txt -t http/exposures/ -t http/misconfiguration/
```

---

# Tips & Best Practices

1. **Always start passive** - subfinder, amass passive, crtsh before active scanning
2. **Deduplicate often** - Use `anew` and `uro` to keep lists clean
3. **Rate limit** - Use `-rate-limit` flags to avoid getting blocked
4. **Save everything** - Pipe to files, you'll want to reference later
5. **Layer your tools** - Don't rely on just one tool per phase
6. **Check JS files** - Lots of secrets and endpoints hide in JavaScript
7. **Update templates** - Run `nuclei -update-templates` regularly
8. **Use gf patterns** - Filter URLs before testing for specific vulns

---

# Environment Variables

Set these for enhanced functionality:

```bash
# API keys for better results
export SHODAN_API_KEY="your_key"
export CENSYS_API_ID="your_id"
export CENSYS_API_SECRET="your_secret"
export GITHUB_TOKEN="your_token"
export VIRUSTOTAL_API_KEY="your_key"
```

---

# Mounting Volumes

```bash
# Recommended mounts
docker run -it --rm \
    -v $(pwd)/targets:/root/targets \      # Your target lists
    -v $(pwd)/recon:/root/recon \           # Recon output
    -v $(pwd)/reports:/root/reports \       # Reports
    -v ~/.config/nuclei:/root/.config/nuclei \  # Nuclei config
    bugbounty:2025
```

---

# Troubleshooting

**Tools not found:** Make sure PATH includes `/root/go/bin`
```bash
export PATH=$PATH:/root/go/bin
```

**Permission denied on masscan/nmap:** Run container with capabilities
```bash
docker run --cap-add=NET_ADMIN --cap-add=NET_RAW ...
```

**Out of memory:** Limit concurrent tools
```bash
nuclei -c 10 -rate-limit 50
```

**Image too large:** Use `Dockerfile.minimal` for smaller image

**Missing wordlists:** Mount full SecLists with `-v /path/to/SecLists:/usr/share/seclists`

---

# License

Tools included are from their respective authors. Check individual tool licenses.

Built with ❤️ for the bug bounty community.
