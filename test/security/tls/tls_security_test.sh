#!/bin/bash

# ================================================================
# TLS/SSL Security Test Script for Silver Mail Server
# ================================================================
# This script tests all TLS-enabled ports from docker-compose.yaml
# and provides comprehensive security analysis.
#
# Usage:
#   ./tls_encrypt_test.sh           # Quick mode (1-2 minutes)
#   ./tls_encrypt_test.sh --full    # Full testssl.sh scan (~60-75 min)
#   ./tls_encrypt_test.sh --critical # Only critical ports (~30-40 min)
# ================================================================

set -e

# Parse command line arguments
MODE="quick"
if [ "${1:-}" = "--full" ]; then
    MODE="full"
elif [ "${1:-}" = "--critical" ]; then
    MODE="critical"
fi

# Read domains from silver.yaml configuration file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../../../conf/silver.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE"
    exit 1
fi

# Extract domains from YAML file (using awk for better compatibility)
DOMAINS=$(awk '/^[[:space:]]*-?[[:space:]]*domain:/ {gsub(/^[[:space:]]*-?[[:space:]]*domain:[[:space:]]*/, ""); gsub(/[[:space:]]*$/, ""); if ($0 != "") print $0}' "$CONFIG_FILE")

if [ -z "$DOMAINS" ]; then
    echo "Error: No domains found in $CONFIG_FILE"
    exit 1
fi

# Get the first domain (primary domain)
PRIMARY_DOMAIN=$(echo "$DOMAINS" | head -n 1)
MAIL_DOMAIN="mail.$PRIMARY_DOMAIN"

echo "================================================================"
echo "  TLS/SSL Security Testing for: $PRIMARY_DOMAIN"
echo "================================================================"
echo "  Mode: $MODE"
if [ "$MODE" = "quick" ]; then
    echo "  Estimated time: 1-2 minutes"
elif [ "$MODE" = "critical" ]; then
    echo "  Estimated time: 30-40 minutes"
else
    echo "  Estimated time: 60-90 minutes"
fi
echo "================================================================"
echo ""

# ================================================================
# Install testssl.sh if not present (only if needed)
# ================================================================
if [ "$MODE" != "quick" ]; then
    TESTSSL_DIR="$SCRIPT_DIR/testssl.sh"
    TESTSSL_CMD="$TESTSSL_DIR/testssl.sh"

    if [ ! -f "$TESTSSL_CMD" ]; then
        echo "testssl.sh not found. Installing..."
        echo "Cloning testssl.sh from GitHub..."
        git clone --depth 1 https://github.com/drwetter/testssl.sh.git "$TESTSSL_DIR"
        chmod +x "$TESTSSL_CMD"
        echo "testssl.sh installed successfully!"
        echo ""
    fi
fi

# ================================================================
# Quick OpenSSL Tests for All Services
# ================================================================

echo "================================================================"
echo "  QUICK CONNECTION TESTS (using OpenSSL)"
echo "================================================================"
echo ""

test_port_quick() {
    local port=$1
    local display_name=$2
    local starttls_protocol=$3
    local starttls=$4
    local domain=$5
    local quit_cmd=$6

    echo ">> Testing $display_name (port $port)..."

    local output
    if [ "$starttls" = "yes" ]; then
        output=$(timeout 10 sh -c "echo '$quit_cmd' | openssl s_client -starttls $starttls_protocol -connect $domain:$port -crlf -servername $domain 2>&1" | grep -E "(Protocol|Cipher|Verify return code)" | head -3)
    else
        output=$(timeout 10 sh -c "echo '$quit_cmd' | openssl s_client -connect $domain:$port -servername $domain 2>&1" | grep -E "(Protocol|Cipher|Verify return code)" | head -3)
    fi

    if [ -n "$output" ]; then
        echo "$output"
        echo "   ✅ Connection successful"
    else
        echo "   ❌ Connection failed or timed out"
    fi
    echo ""
}

# Test all ports
test_port_quick 25 "SMTP" "smtp" "yes" "$MAIL_DOMAIN" "QUIT"
test_port_quick 587 "SMTP Submission" "smtp" "yes" "$MAIL_DOMAIN" "QUIT"
test_port_quick 143 "IMAP" "imap" "yes" "$MAIL_DOMAIN" "a1 LOGOUT"
test_port_quick 993 "IMAPS" "" "no" "$MAIL_DOMAIN" "a1 LOGOUT"

echo "================================================================"
echo "  SECURITY SUMMARY - Quick Analysis"
echo "================================================================"
echo ""
echo "Quick TLS check completed for all ports."
echo ""

if [ "$MODE" = "quick" ]; then
    echo "✅ Quick mode complete!"
    echo ""
    echo "For comprehensive vulnerability scanning, run:"
    echo "  ./tls_encrypt_test.sh --critical  (tests SMTP & IMAPS - ~30-40 min)"
    echo "  ./tls_encrypt_test.sh --full      (all ports - ~60-90 min)"
    echo ""
    echo "The quick test verified basic TLS connectivity."
    echo "To check for specific vulnerabilities (LUCKY13, BEAST, etc.),"
    echo "you need to run the full or critical scan."
    exit 0
fi

# ================================================================
# Comprehensive testssl.sh Analysis
# ================================================================

echo "================================================================"
echo "  COMPREHENSIVE SECURITY ANALYSIS (using testssl.sh)"
echo "================================================================"
echo ""

# Use more aggressive flags to speed up testing
TESTSSL_FLAGS="--fast --warnings off --quiet --severity HIGH"

run_testssl() {
    local port=$1
    local title=$2
    local starttls=$3
    local domain=$4

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Testing $title"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ "$starttls" != "" ]; then
        "$TESTSSL_CMD" --starttls "$starttls" $TESTSSL_FLAGS "$domain:$port" 2>&1 | grep -E "(Testing protocols|SSLv|TLS |Testing vulnerabilities|VULNERABLE|not vulnerable|offered|Grade)" | head -50
    else
        "$TESTSSL_CMD" $TESTSSL_FLAGS "$domain:$port" 2>&1 | grep -E "(Testing protocols|SSLv|TLS |Testing vulnerabilities|VULNERABLE|not vulnerable|offered|Grade)" | head -50
    fi

    echo ""
}

if [ "$MODE" = "critical" ]; then
    echo "Testing critical ports only (SMTP 587 & IMAPS 993)..."
    echo ""

    run_testssl 587 "SMTP Submission (port 587)" "smtp" "$MAIL_DOMAIN"
    run_testssl 993 "IMAPS (port 993)" "" "$MAIL_DOMAIN"

elif [ "$MODE" = "full" ]; then
    echo "Testing all ports (this will take 60-90 minutes)..."
    echo ""

    run_testssl 25 "SMTP (port 25)" "smtp" "$MAIL_DOMAIN"
    run_testssl 587 "SMTP Submission (port 587)" "smtp" "$MAIL_DOMAIN"
    run_testssl 143 "IMAP (port 143)" "imap" "$MAIL_DOMAIN"
    run_testssl 993 "IMAPS (port 993)" "" "$MAIL_DOMAIN"
fi

echo "================================================================"
echo "  TLS SECURITY TESTING COMPLETE"
echo "================================================================"
echo ""
echo "Summary of tested services:"
if [ "$MODE" = "critical" ]; then
    echo "  ✓ Submission (port 587) - STARTTLS"
    echo "  ✓ IMAPS (port 993) - Direct TLS"
else
    echo "  ✓ SMTP (port 25) - STARTTLS"
    echo "  ✓ Submission (port 587) - STARTTLS"
    echo "  ✓ IMAP (port 143) - STARTTLS"
    echo "  ✓ IMAPS (port 993) - Direct TLS"
fi
echo ""
echo "Review the output above for any security warnings or vulnerabilities."
echo "Key things to check:"
echo "  • TLS 1.0/1.1 should NOT be offered"
echo "  • TLS 1.2/1.3 should be offered"
echo "  • CBC ciphers should NOT be offered"
echo "  • No 'VULNERABLE' findings"
echo "================================================================"
