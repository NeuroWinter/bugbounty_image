# Bug Bounty Toolkit

Docker container with security tools for bug bounty hunting.

## Usage

```bash
docker build -t bugbounty .
docker run -it --rm -v $(pwd)/recon:/root/recon bugbounty

# Inside container
fullrecon example.com
bbhelp
```

## What's Included

subfinder, amass, httpx, naabu, katana, waybackurls, nuclei, dalfox, ffuf, sqlmap, wpscan, SecLists

## Scripts

- `fullrecon <domain>` - Full recon
- `xss-hunt <urls.txt>` - XSS testing
- `scope-check <target>` - Validate scope
- `report-gen <domain>` - Generate report
- `monitor <domain>` - Continuous monitoring

## Setup

API keys (optional):
```bash
cp .env.example .env
# Add your keys
docker run -it --env-file .env ...
```

Scope:
```bash
echo "*.example.com" > ~/scope/authorized.txt
```

