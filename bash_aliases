#!/bin/bash

# Aliases
alias ll='ls -la'
alias subs='subfinder -silent'
alias probe='httpx -silent'
alias live='httpx -silent -mc 200,301,302,403'
alias nuc='nuclei'
alias ff='ffuf'

# Certificate search
crtsh(){
    [ -z "$1" ] && echo "Usage: crtsh <domain>" && return 1
    local resp
    resp=$(curl -s --max-time 30 -H 'User-Agent: Mozilla/5.0' \
        "https://crt.sh/?q=%25.$1&output=json")
    if ! echo "$resp" | jq -e . >/dev/null 2>&1; then
        echo "  crt.sh returned non-JSON (rate-limited or down), skipping" >&2
        return 1
    fi
    echo "$resp" \
        | jq -r '.[].name_value' \
        | sed 's/\*\.//g' \
        | tr '[:upper:]' '[:lower:]' \
        | grep -E "\.$1$" \
        | sort -u
}

# Port scanning
ms(){
    [ -z "$1" ] && echo "Usage: ms <ip_or_cidr>" && return 1
    masscan -p80,443,8080,8443,3000,8000 "$1" --rate=1000
}


# Amass with httpx probe
am(){
    [ -z "$1" ] && echo "Usage: am <domain>" && return 1
    # Parse names from stdout (schema-independent) rather than amass v4 JSON,
    # which has changed shape across releases.
    amass enum -passive -d "$1" 2>/dev/null \
        | grep -E "^[a-zA-Z0-9._-]+\.$1$" \
        | sort -u \
        | httpx-go -silent \
        | anew "$1-domains-am.txt"
}

# Arjun parameter discovery (accepts a single URL or a file of URLs)
aj(){
    [ -z "$1" ] && echo "Usage: aj <url|urls.txt>" && return 1
    if [ -f "$1" ]; then
        while read -r line; do
            [ -z "$line" ] && continue
            arjun -u "$line"
        done < "$1"
    elif printf '%s' "$1" | grep -qE '^https?://'; then
        arjun -u "$1"
    else
        echo "Not a file or URL: $1" && return 1
    fi
}

# Photon crawler
ph(){
    [ -z "$1" ] && echo "Usage: ph <url>" && return 1
    python3 ~/tools/Photon/photon.py -u "$1" -l 6 --keys --wayback
}

massph(){
    [ -z "$1" ] && echo "Usage: massph <urls.txt>" && return 1
    [ ! -f "$1" ] && echo "File not found: $1" && return 1
    cat "$1" | while read -r line; do
        [ -z "$line" ] && continue
        ph "$line"
    done
}

# JS secret scan
jss(){
    [ -z "$1" ] && echo "Usage: jss <js_url>" && return 1
    curl -s "$1" | js-beautify - | grep -iE "api|key|token|secret|password"
}

# Quick recon (fast, no amass/nuclei)
quickrecon(){
    [ -z "$1" ] && echo "Usage: quickrecon <domain>" && return 1

    domain="$1"
    mkdir -p ~/recon/"$domain" && cd ~/recon/"$domain" || return 1

    echo "[1/5] Subdomain enumeration (fast)..."
    subfinder -d "$domain" -silent | anew subs.txt
    crtsh "$domain" | anew subs.txt

    echo "[2/5] Probing..."
    cat subs.txt | /usr/local/bin/httpx -silent | anew live.txt

    echo "[3/5] URL discovery..."
    local errout=/dev/null
    [ -n "${DEBUG:-}" ] && errout=/dev/stderr
    # waybackurls/gau need bare hostnames, not schemed URLs.
    cat live.txt | unfurl domains | sort -u | anew hosts.txt > /dev/null
    cat hosts.txt | waybackurls 2>"$errout" | anew urls.txt
    cat hosts.txt | gau --threads 10 2>"$errout" | anew urls.txt

    echo "[4/5] JS files..."
    cat urls.txt | grep -iE '\.js(\?|$)' | anew js.txt

    echo "[5/5] Parameters..."
    cat urls.txt | grep "=" | unfurl keys 2>/dev/null | sort -u | anew params.txt

    echo ""
    echo "Quick recon complete!"
    echo "  Subdomains: $(wc -l < subs.txt 2>/dev/null || echo 0)"
    echo "  Live: $(wc -l < live.txt 2>/dev/null || echo 0)"
    echo "  URLs: $(wc -l < urls.txt 2>/dev/null || echo 0)"
    echo ""
    echo "For full scan with amass+nuclei, run: fullrecon $domain"
}

# Full recon pipeline
fullrecon(){
    [ -z "$1" ] && echo "Usage: fullrecon <domain>" && return 1

    domain="$1"
    mkdir -p ~/recon/"$domain" && cd ~/recon/"$domain" || return 1

    echo "[1/6] Subdomain enumeration..."
    subfinder -d "$domain" -silent | anew subs.txt

    # Amass with timeout (can hang indefinitely)
    # NOTE: amass v4 prints its association graph to stdout, not clean names.
    # Filter to FQDNs that actually belong to the target before storing.
    timeout 300 amass enum -passive -d "$domain" 2>/dev/null \
        | grep -E "^[a-zA-Z0-9._-]+\.${domain}$" \
        | anew subs.txt || echo "  (amass timeout/skipped)"

    # Alternative: crt.sh
    crtsh "$domain" | anew subs.txt

    echo "[2/6] Probing..."
    cat subs.txt | /usr/local/bin/httpx -silent | anew live.txt

    echo "[3/6] URL discovery..."
    # Set DEBUG=1 to see tool errors instead of swallowing them.
    local errout=/dev/null
    [ -n "${DEBUG:-}" ] && errout=/dev/stderr

    # katana takes full URLs (with scheme) on stdin.
    cat live.txt | katana -d 3 -silent 2>"$errout" | anew urls.txt || echo "  (katana failed, skipping)"

    # waybackurls/gau take bare hostnames, NOT schemed URLs. Strip the scheme first.
    cat live.txt | unfurl domains | sort -u | anew hosts.txt > /dev/null
    cat hosts.txt | waybackurls 2>"$errout" | anew urls.txt
    cat hosts.txt | gau --threads 5 2>"$errout" | anew urls.txt

    echo "[4/6] JS files..."
    cat urls.txt | grep -iE '\.js(\?|$)' | anew js.txt

    echo "[5/6] Parameters..."
    cat urls.txt | grep "=" | unfurl keys 2>/dev/null | sort -u | anew params.txt

    echo "[6/6] Nuclei scan (rate-limited, may take time)..."
    nuclei -l live.txt -severity critical,high,medium -rl 150 -c 25 -o nuclei.txt -silent 2>/dev/null &
    NUCLEI_PID=$!

    echo ""
    echo "Results (nuclei running in background PID: $NUCLEI_PID):"
    echo "  Subdomains: $(wc -l < subs.txt 2>/dev/null || echo 0)"
    echo "  Live: $(wc -l < live.txt 2>/dev/null || echo 0)"
    echo "  URLs: $(wc -l < urls.txt 2>/dev/null || echo 0)"
    echo ""
    echo "Nuclei is running in background. Check progress:"
    echo "  tail -f nuclei.txt"
    echo "  kill $NUCLEI_PID  # to stop early"
}

# Help
bbhelp(){
    echo "Bug Bounty Toolkit Commands"
    echo ""
    echo "Main:"
    echo "  quickrecon <domain> - Fast recon (no amass/nuclei, 2-5 min)"
    echo "  fullrecon <domain>  - Full recon pipeline (slower, complete)"
    echo "  bbhelp              - This help"
    echo ""
    echo "Discovery:"
    echo "  crtsh <domain>      - Certificate transparency"
    echo "  am <domain>         - Amass + httpx probe"
    echo "  subs, probe, live   - Aliases for subfinder/httpx"
    echo ""
    echo "Scanning:"
    echo "  nuc, ff             - Aliases for nuclei/ffuf"
    echo "  ms <ip>             - Masscan ports"
    echo "  aj <url|urls.txt>   - Arjun parameter discovery"
    echo ""
    echo "Crawling:"
    echo "  ph <url>            - Photon crawler"
    echo "  massph <urls.txt>   - Bulk Photon"
    echo ""
    echo "Analysis:"
    echo "  jss <js_url>        - JS secrets"
    echo ""
    echo "Standard Scripts:"
    echo "  recon-pipeline, xss-hunt, scope-check,"
    echo "  report-gen, monitor, version"
    echo ""
    echo "Novel Attack Scripts:"
    echo "  novel-recon <domain>            - Advanced recon (source maps, hidden APIs)"
    echo "  race-condition-test <url>       - Race condition testing"
    echo "  cache-poison-test <url>         - Cache poisoning tests"
    echo "  integer-overflow-fuzz <urls>    - Integer overflow fuzzing"
    echo "  graphql-introspect <url>        - GraphQL security testing"
    echo "  business-logic-fuzz <url> <p>   - Business logic edge cases"
    echo "  prototype-pollution-test <url>  - Prototype pollution"
    echo "  ssrf-test <url> <param>         - SSRF with cloud metadata"
}
