# Standard Recon Workflow - Minimal Docker

This workflow uses only the tools available in `Dockerfile.minimal`.

## Setup

```bash
# Build minimal image
docker build -f Dockerfile.minimal -t bugbounty:minimal .

# Run with mounted volume for persistence
docker run -it --rm -v $(pwd)/recon:/root/recon bugbounty:minimal

# Create working directory
mkdir -p ~/recon/target.com && cd ~/recon/target.com
```

---

## Phase 1: Subdomain Enumeration

### Find subdomains
```bash
# Passive enumeration
subfinder -d target.com -silent -o subs.txt

# Check what was found
wc -l subs.txt
```

**Output:** `subs.txt` - List of subdomains

---

## Phase 2: Host Probing

### Identify live hosts
```bash
# Basic probe
cat subs.txt | httpx -silent -o live.txt

# Detailed probe with tech detection
cat subs.txt | httpx -status-code -title -tech-detect -o live-detailed.txt

# Check results
wc -l live.txt
```

**Output:**
- `live.txt` - Live HTTP/HTTPS hosts
- `live-detailed.txt` - Hosts with status codes and technologies

---

## Phase 3: Port Scanning

### Scan for non-standard ports
```bash
# Quick scan of common web ports
cat live.txt | sed 's/https\?:\/\///' | naabu -top-ports 100 -silent -o ports.txt

# Check for additional web services
cat ports.txt | httpx -silent | anew live.txt
```

**Output:** `ports.txt` - Open ports on live hosts

---

## Phase 4: URL Discovery

### Crawl and gather URLs
```bash
# Active crawling
cat live.txt | katana -d 3 -silent -o urls-crawled.txt

# Historical URLs from archives
cat live.txt | waybackurls > urls-wayback.txt
cat live.txt | gau --blacklist png,jpg,gif,css,woff,svg,ico > urls-gau.txt

# Combine all URLs
cat urls-crawled.txt urls-wayback.txt urls-gau.txt | sort -u > urls-all.txt

# Check count
wc -l urls-all.txt
```

**Output:**
- `urls-crawled.txt` - Active crawling results
- `urls-wayback.txt` - Wayback Machine URLs
- `urls-gau.txt` - URLs from multiple archives
- `urls-all.txt` - Combined unique URLs

---

## Phase 5: URL Filtering

### Extract specific URL types
```bash
# URLs with parameters
cat urls-all.txt | grep "=" > urls-params.txt

# JavaScript files
cat urls-all.txt | grep -iE '\.js(\?|$)' > urls-js.txt

# API endpoints
cat urls-all.txt | grep -iE "/api/|/v[0-9]+/" > urls-api.txt

# Extract parameter names
cat urls-params.txt | unfurl keys | sort -u > params.txt
```

**Output:**
- `urls-params.txt` - URLs with query parameters
- `urls-js.txt` - JavaScript files
- `urls-api.txt` - Potential API endpoints
- `params.txt` - Unique parameter names

---

## Phase 6: Vulnerability Scanning

### Run nuclei on live hosts
```bash
# Critical and high severity only
nuclei -l live.txt -severity critical,high -silent -o nuclei-critical.txt

# All severities
nuclei -l live.txt -severity critical,high,medium -silent -o nuclei-all.txt

# Check findings
cat nuclei-critical.txt
```

**Output:**
- `nuclei-critical.txt` - Critical/high findings
- `nuclei-all.txt` - All findings

---

## Phase 7: XSS Testing

### Test for XSS vulnerabilities
```bash
# Filter URLs likely vulnerable to XSS
cat urls-params.txt | gf xss > urls-xss-candidates.txt

# Test with dalfox
cat urls-xss-candidates.txt | dalfox pipe --silence -o xss-results.txt

# Check results
cat xss-results.txt
```

**Output:**
- `urls-xss-candidates.txt` - Potential XSS targets
- `xss-results.txt` - Confirmed XSS findings

---

## Phase 8: SQLi Testing

### Test for SQL injection
```bash
# Filter URLs likely vulnerable to SQLi
cat urls-params.txt | gf sqli > urls-sqli-candidates.txt

# Test with sqlmap (first 10 URLs as example)
head -10 urls-sqli-candidates.txt | while read url; do
    python3 /opt/sqlmap/sqlmap.py -u "$url" --batch --level=2 --risk=2
done
```

**Output:** SQLMap will create output in `~/.local/share/sqlmap/`

---

## Phase 9: Directory Fuzzing

### Fuzz for hidden directories and files
```bash
# Fuzz top 5 live hosts
head -5 live.txt | while read url; do
    echo "[+] Fuzzing $url"
    ffuf -u "$url/FUZZ" \
         -w /usr/share/wordlists/raft-small-words.txt \
         -mc 200,301,302,403 \
         -o "ffuf-$(echo $url | sed 's/[^a-zA-Z0-9]/_/g').json" \
         -of json \
         -s
done
```

**Output:** `ffuf-*.json` - Discovered directories and files

---

## Phase 10: JavaScript Analysis

### Extract secrets and endpoints from JS files
```bash
# Download JS files (sample first 20)
mkdir -p js-files
head -20 urls-js.txt | while read url; do
    filename=$(echo "$url" | md5sum | cut -d' ' -f1).js
    curl -s "$url" -o "js-files/$filename"
done

# Search for sensitive data
grep -riE "api[_-]?key|secret|password|token|access[_-]?key" js-files/ > js-secrets.txt

# Manual review recommended
cat js-secrets.txt
```

**Output:**
- `js-files/` - Downloaded JavaScript files
- `js-secrets.txt` - Potential secrets found

---

## Summary Report

### Generate summary of findings
```bash
cat > SUMMARY.txt <<EOF
Recon Summary for target.com
====================================

Subdomains found:     $(wc -l < subs.txt)
Live hosts:           $(wc -l < live.txt)
Open ports:           $(wc -l < ports.txt 2>/dev/null || echo 0)
Total URLs:           $(wc -l < urls-all.txt)
URLs with params:     $(wc -l < urls-params.txt)
JavaScript files:     $(wc -l < urls-js.txt)
API endpoints:        $(wc -l < urls-api.txt)
Unique parameters:    $(wc -l < params.txt)

Nuclei findings:      $(wc -l < nuclei-all.txt)
XSS candidates:       $(wc -l < urls-xss-candidates.txt)
SQLi candidates:      $(wc -l < urls-sqli-candidates.txt)

Files:
------
subs.txt              - All subdomains
live.txt              - Live HTTP/HTTPS hosts
urls-all.txt          - All discovered URLs
urls-params.txt       - URLs with parameters
nuclei-all.txt        - Nuclei scan results
xss-results.txt       - XSS findings
params.txt            - Parameter names
EOF

cat SUMMARY.txt
```

**Output:** `SUMMARY.txt` - Overview of all findings

---

## Complete Workflow Script

Save this as `recon.sh`:

```bash
#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: ./recon.sh domain.com"
    exit 1
fi

DOMAIN=$1
mkdir -p ~/recon/$DOMAIN && cd ~/recon/$DOMAIN

echo "[1/9] Subdomain enumeration..."
subfinder -d $DOMAIN -silent -o subs.txt

echo "[2/9] Probing live hosts..."
cat subs.txt | httpx -silent -o live.txt

echo "[3/9] Port scanning..."
cat live.txt | sed 's/https\?:\/\///' | naabu -top-ports 100 -silent -o ports.txt

echo "[4/9] Crawling URLs..."
cat live.txt | katana -d 3 -silent -o urls-crawled.txt
cat live.txt | waybackurls > urls-wayback.txt 2>/dev/null
cat live.txt | gau --blacklist png,jpg,gif,css,woff > urls-gau.txt 2>/dev/null
cat urls-crawled.txt urls-wayback.txt urls-gau.txt | sort -u > urls-all.txt

echo "[5/9] Filtering URLs..."
cat urls-all.txt | grep "=" > urls-params.txt
cat urls-all.txt | grep -iE '\.js(\?|$)' > urls-js.txt
cat urls-params.txt | unfurl keys | sort -u > params.txt

echo "[6/9] Running Nuclei..."
nuclei -l live.txt -severity critical,high,medium -silent -o nuclei-all.txt 2>/dev/null

echo "[7/9] Checking for XSS..."
cat urls-params.txt | gf xss > urls-xss-candidates.txt 2>/dev/null
cat urls-xss-candidates.txt | dalfox pipe --silence -o xss-results.txt 2>/dev/null

echo "[8/9] Checking for SQLi..."
cat urls-params.txt | gf sqli > urls-sqli-candidates.txt 2>/dev/null

echo "[9/9] Generating summary..."
cat > SUMMARY.txt <<EOF
Recon Summary for $DOMAIN
====================================

Subdomains found:     $(wc -l < subs.txt)
Live hosts:           $(wc -l < live.txt)
Open ports:           $(wc -l < ports.txt 2>/dev/null || echo 0)
Total URLs:           $(wc -l < urls-all.txt)
URLs with params:     $(wc -l < urls-params.txt)
JavaScript files:     $(wc -l < urls-js.txt)
Unique parameters:    $(wc -l < params.txt)

Nuclei findings:      $(wc -l < nuclei-all.txt 2>/dev/null || echo 0)
XSS candidates:       $(wc -l < urls-xss-candidates.txt)
SQLi candidates:      $(wc -l < urls-sqli-candidates.txt)
EOF

echo ""
echo "Done! Results in ~/recon/$DOMAIN/"
cat SUMMARY.txt
```

Make it executable:
```bash
chmod +x recon.sh
```

Run it:
```bash
./recon.sh target.com
```

---

## File Structure After Workflow

```
~/recon/target.com/
├── subs.txt                  # All subdomains
├── live.txt                  # Live hosts
├── live-detailed.txt         # Hosts with tech info
├── ports.txt                 # Open ports
├── urls-crawled.txt          # Crawled URLs
├── urls-wayback.txt          # Wayback URLs
├── urls-gau.txt              # Archive URLs
├── urls-all.txt              # All unique URLs
├── urls-params.txt           # URLs with parameters
├── urls-js.txt               # JavaScript files
├── urls-api.txt              # API endpoints
├── params.txt                # Parameter names
├── urls-xss-candidates.txt   # XSS targets
├── urls-sqli-candidates.txt  # SQLi targets
├── nuclei-all.txt            # Nuclei findings
├── xss-results.txt           # XSS results
├── js-secrets.txt            # Secrets in JS
├── ffuf-*.json               # Fuzzing results
└── SUMMARY.txt               # Summary report
```

---

## Next Steps

After running this workflow:

1. **Review nuclei findings** - Check `nuclei-all.txt` for vulnerabilities
2. **Test XSS manually** - Review `xss-results.txt` and verify findings
3. **Test SQLi manually** - Use sqlmap on candidates in `urls-sqli-candidates.txt`
4. **Review JS files** - Check `js-secrets.txt` for API keys and tokens
5. **Fuzz critical endpoints** - Use ffuf on interesting paths
6. **Check API endpoints** - Test `urls-api.txt` for broken access control
7. **Parameter testing** - Try parameter pollution with names from `params.txt`

---

## Tips

- Run phases in order, each builds on previous results
- Save everything to files for later review
- Use `anew` to avoid duplicates when re-running scans
- Rate limit tools if you get blocked (add `-rate-limit 50` to nuclei, etc.)
- Review results manually, automated tools miss things
- Keep notes of what you've tested

---

## Time Estimates

For a medium-sized target (~100 subdomains):

- Subdomain enumeration: 2-5 minutes
- Host probing: 1-2 minutes
- URL discovery: 5-10 minutes
- Nuclei scanning: 10-30 minutes
- XSS testing: 5-15 minutes
- Total: ~30-60 minutes for initial scan

Larger targets will take proportionally longer.
