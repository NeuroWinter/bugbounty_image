# Quick Start Guide - Bug Bounty Toolkit 2025

## Choose Your Version

```bash
# OPTIMIZED (Recommended) - 2-3 GB
docker build -t bugbounty:2025 .

# MINIMAL - 800 MB - 1.2 GB
docker build -f Dockerfile.minimal -t bugbounty:minimal .

# ORIGINAL - 5-7 GB (all tools + full SecLists)
docker build -f Dockerfile.original -t bugbounty:full .
```

---

## Basic Usage

```bash
# Run container
docker run -it --rm bugbounty:2025

# With mounted volumes
docker run -it --rm \
  -v $(pwd)/targets:/root/targets \
  -v $(pwd)/recon:/root/recon \
  bugbounty:2025

# With network capabilities (for masscan/nmap)
docker run -it --rm --cap-add=NET_ADMIN --cap-add=NET_RAW bugbounty:2025
```

---

## Quick Recon

### Option 1: Use Built-in Function
```bash
# Inside container
fullrecon target.com
```

### Option 2: Use Script
```bash
# Inside container
recon-pipeline target.com
```

### Option 3: Manual Pipeline
```bash
# Subdomain enumeration
subfinder -d target.com -silent | anew subs.txt
amass enum -passive -d target.com | anew subs.txt

# Probe live hosts
cat subs.txt | httpx -silent | anew live.txt

# Crawl for URLs
cat live.txt | katana -d 3 -silent | anew urls.txt
cat live.txt | waybackurls | anew urls.txt

# Run vulnerability scan
nuclei -l live.txt -severity critical,high,medium -o findings.txt
```

---

## Common Workflows

### XSS Hunting
```bash
# Gather URLs with parameters
cat live.txt | katana -d 3 -silent | grep "=" | anew params.txt

# Filter for XSS candidates
cat params.txt | gf xss | uro | anew xss_candidates.txt

# Test with dalfox
cat xss_candidates.txt | dalfox pipe -o xss_results.txt

# OR use alias
cat params.txt | scan-xss
```

### SQL Injection
```bash
# Find SQLi candidates
cat urls.txt | gf sqli | uro | anew sqli_candidates.txt

# Test with sqlmap
cat sqli_candidates.txt | while read url; do
    sqlmap -u "$url" --batch --level=2
done
```

### JavaScript Analysis
```bash
# Find JS files
cat live.txt | katana -d 3 -silent | grep -iE '\.js(\?|$)' | anew js.txt

# Extract secrets
cat js.txt | while read url; do
    jss "$url"  # Built-in alias
done

# Find endpoints
cat js.txt | while read url; do
    python3 ~/tools/LinkFinder/linkfinder.py -i "$url" -o cli
done
```

---

## Essential Aliases

Available in all versions:

```bash
subs='subfinder -silent'
probe='httpx -silent'
live='httpx -silent -mc 200,301,302,403'
crawl='katana -silent'
nuc='nuclei'
ff='ffuf'
```

---

## Tool Quick Reference

### Subdomain Discovery
```bash
subfinder -d target.com -silent
amass enum -passive -d target.com
crtsh target.com  # Built-in function
```

### HTTP Probing
```bash
cat subs.txt | httpx -silent
cat subs.txt | httpx -status-code -title -tech-detect
```

### Port Scanning
```bash
naabu -host target.com -top-ports 1000
masscan -p80,443,8080 192.168.1.0/24 --rate=1000
```

### Fuzzing
```bash
ffuf -u https://target.com/FUZZ -w /usr/share/wordlists/raft-small-words.txt
feroxbuster -u https://target.com  # Optimized version only
gobuster dir -u https://target.com -w wordlist.txt
```

### Vulnerability Scanning
```bash
nuclei -u https://target.com
nuclei -l live.txt -severity critical,high,medium
dalfox url "https://target.com/page?q=test"
```

---

## Wordlist Paths

**Optimized/Minimal:**
```
/usr/share/wordlists/raft-small-words.txt
/usr/share/wordlists/subdomains-top1million-5000.txt
/usr/share/wordlists/10k-most-common.txt
```

**Original:**
```
/usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt
/usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt
/usr/share/seclists/Passwords/Common-Credentials/10k-most-common.txt
```

**Need full SecLists?** Mount it:
```bash
docker run -v /path/to/SecLists:/usr/share/seclists bugbounty:2025
```

---

## Environment Variables

Set API keys for enhanced functionality:

```bash
docker run -e SHODAN_API_KEY="key" \
           -e GITHUB_TOKEN="token" \
           -e VIRUSTOTAL_API_KEY="key" \
           bugbounty:2025
```

---

## Persistent Data

### Mount Recon Directory
```bash
docker run -v $(pwd)/recon:/root/recon bugbounty:2025
```

### Mount Nuclei Config
```bash
docker run -v ~/.config/nuclei:/root/.config/nuclei bugbounty:2025
```

### Save Container State
```bash
# Run container with name
docker run -it --name bb-session bugbounty:2025

# Exit container (Ctrl+D)

# Resume later
docker start -ai bb-session
```

---

## Size Comparison

| Command | Size | Time | Tools |
|---------|------|------|-------|
| `docker build -t bugbounty:2025 .` | 2-3 GB | 15-20 min | 50+ |
| `docker build -f Dockerfile.minimal -t bugbounty:minimal .` | 800 MB | 8-12 min | 15 |
| `docker build -f Dockerfile.original -t bugbounty:full .` | 5-7 GB | 20-30 min | 70+ |

---

## Tips

✅ Start with **Optimized** version - best balance
✅ Use `anew` to deduplicate results
✅ Pipe results to files for later analysis
✅ Rate limit tools to avoid blocking: `nuclei -rate-limit 50`
✅ Update templates regularly: `nuclei -update-templates`
✅ Check out [SIZE_OPTIMIZATION.md](SIZE_OPTIMIZATION.md) for details

---

## Next Steps

1. Build your preferred version
2. Run a test recon: `fullrecon example.com`
3. Review results in `~/recon/example.com/`
4. Customize aliases in `/root/.bash_aliases`
5. Add API keys for better results

---

**Need Help?**
- Tool reference: See main [README.md](README.md)
- Size optimization: See [SIZE_OPTIMIZATION.md](SIZE_OPTIMIZATION.md)
- Bug fixes applied: See [FIXES_APPLIED.md](FIXES_APPLIED.md)

---

Happy Hunting! 🎯
