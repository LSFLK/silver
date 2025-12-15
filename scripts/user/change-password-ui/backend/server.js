#!/usr/bin/env node

/**
 * Silver Mail - Change Password UI Server
 *
 * Simple Express server to serve the password change UI
 *
 * Usage:
 *   npm install express
 *   node server.js
 *
 * Or:
 *   npm start
 */

const express = require('express');
const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3001;
const HTTPS_PORT = process.env.HTTPS_PORT || 3443;
const THUNDER_API = process.env.THUNDER_API || 'https://localhost:8090';

// Read domain from silver.yaml
function getDomainFromConfig() {
    try {
        const configPath = process.env.SILVER_CONFIG || '/etc/silver/silver.yaml';
        if (fs.existsSync(configPath)) {
            const configContent = fs.readFileSync(configPath, 'utf8');
            // Simple YAML parsing for domain (first domain in list)
            const domainMatch = configContent.match(/^\s*-\s*domain:\s*(.+)$/m);
            if (domainMatch && domainMatch[1].trim()) {
                const domain = domainMatch[1].trim();
                console.log(`Loaded domain from config: ${domain}`);
                return domain;
            }
        }
    } catch (e) {
        console.error('Error reading silver.yaml:', e.message);
    }
    return null;
}

const DOMAIN = process.env.DOMAIN || getDomainFromConfig() || 'localhost';

// Auto-detect certificate paths
let SSL_CERT = process.env.SSL_CERT;
let SSL_KEY = process.env.SSL_KEY;

// Helper function to check if file exists (handles symlinks)
function fileExists(filePath) {
    try {
        fs.accessSync(filePath, fs.constants.R_OK);
        return true;
    } catch (e) {
        return false;
    }
}

// If not explicitly set, try to find domain certificates
if (!SSL_CERT || !SSL_KEY) {
    console.log(`\n🔍 Searching for SSL certificates for domain: ${DOMAIN}`);
    
    // Try domain-specific path first
    const domainCertPath = `/etc/letsencrypt/live/${DOMAIN}/fullchain.pem`;
    const domainKeyPath = `/etc/letsencrypt/live/${DOMAIN}/privkey.pem`;
    
    console.log(`   Checking: ${domainCertPath}`);
    console.log(`   Checking: ${domainKeyPath}`);
    
    if (fileExists(domainCertPath) && fileExists(domainKeyPath)) {
        SSL_CERT = domainCertPath;
        SSL_KEY = domainKeyPath;
        console.log(`✓ Found certificates for domain: ${DOMAIN}`);
    } else {
        console.log(`✗ Certificates not found for ${DOMAIN}`);
        
        // Try to find any available domain
        const letsencryptDir = '/etc/letsencrypt/live';
        if (fs.existsSync(letsencryptDir)) {
            console.log(`   Scanning ${letsencryptDir} for available certificates...`);
            try {
                const allEntries = fs.readdirSync(letsencryptDir);
                console.log(`   Found entries: ${allEntries.join(', ')}`);
                
                const domains = allEntries.filter(f => {
                    if (f === 'README') return false; // Skip README file
                    const certPath = path.join(letsencryptDir, f, 'fullchain.pem');
                    const keyPath = path.join(letsencryptDir, f, 'privkey.pem');
                    const certExists = fileExists(certPath);
                    const keyExists = fileExists(keyPath);
                    console.log(`   ${f}: fullchain=${certExists}, privkey=${keyExists}`);
                    return certExists && keyExists;
                });
                
                if (domains.length > 0) {
                    const firstDomain = domains[0];
                    SSL_CERT = path.join(letsencryptDir, firstDomain, 'fullchain.pem');
                    SSL_KEY = path.join(letsencryptDir, firstDomain, 'privkey.pem');
                    console.log(`✓ Auto-detected certificates from: ${firstDomain}`);
                } else {
                    console.log(`✗ No valid certificate directories found`);
                }
            } catch (e) {
                console.error('✗ Error scanning certificate directory:', e.message);
            }
        } else {
            console.log(`✗ Directory ${letsencryptDir} does not exist`);
        }
        
        // Fallback to /certs
        if (!SSL_CERT && fileExists('/certs/fullchain.pem') && fileExists('/certs/privkey.pem')) {
            SSL_CERT = '/certs/fullchain.pem';
            SSL_KEY = '/certs/privkey.pem';
            console.log('✓ Using certificates from /certs');
        }
    }
}

const ENABLE_HTTPS = SSL_CERT && SSL_KEY && fileExists(SSL_CERT) && fileExists(SSL_KEY);

if (ENABLE_HTTPS) {
    console.log(`\n✓ SSL Certificate: ${SSL_CERT}`);
    console.log(`✓ SSL Key: ${SSL_KEY}`);
} else {
    console.log(`\n✗ SSL setup failed:`);
    console.log(`   SSL_CERT: ${SSL_CERT || 'undefined'}`);
    console.log(`   SSL_KEY: ${SSL_KEY || 'undefined'}`);
}

// Enable JSON parsing
app.use(express.json());

// Check password initialization status
app.post('/api/check-password-status', async (req, res) => {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: 'Email required' });
    
    try {
        const { execSync } = require('child_process');
        const [username, domain] = email.split('@');
        const cmd = `docker exec smtp-server-container sqlite3 /app/data/databases/shared.db "SELECT password_initialized FROM users u INNER JOIN domains d ON u.domain_id = d.id WHERE u.username='${username}' AND d.domain='${domain}' AND u.enabled=1;" 2>&1`;
        const result = execSync(cmd, { encoding: 'utf8' }).trim();
        const initialized = result === '1';
        res.json({ email, password_initialized: initialized, must_change_password: !initialized });
    } catch (error) {
        console.error('Check status error:', error.message);
        res.status(500).json({ error: 'Failed to check status' });
    }
});

// Update password_initialized after password change
async function updatePasswordInitialized(email) {
    if (!email) return;
    try {
        const { execSync } = require('child_process');
        const [username, domain] = email.split('@');
        const cmd = `docker exec smtp-server-container sqlite3 /app/data/databases/shared.db "UPDATE users SET password_initialized = 1 WHERE id IN (SELECT u.id FROM users u INNER JOIN domains d ON u.domain_id = d.id WHERE u.username='${username}' AND d.domain='${domain}');" 2>&1`;
        execSync(cmd);
    } catch (error) {
        console.error('Update password_initialized failed:', error.message);
    }
}

// CORS proxy middleware - intercept API calls and proxy them to avoid CORS
app.use('/api/thunder', async (req, res) => {
    const targetUrl = `${THUNDER_API}${req.path}`;
    
    try {
        const https = require('https');
        const agent = new https.Agent({ rejectUnauthorized: false }); // Accept self-signed certs
        
        const fetch = (await import('node-fetch')).default;
        const response = await fetch(targetUrl, {
            method: req.method,
            headers: {
                'Content-Type': 'application/json',
                ...(req.headers.authorization && { 'Authorization': req.headers.authorization }),
            },
            body: req.method !== 'GET' ? JSON.stringify(req.body) : undefined,
            agent
        });
        
        // Handle 204 No Content or empty responses
        if (response.status === 204 || response.headers.get('content-length') === '0') {
            // Update password_initialized if this was a password change
            if (req.path === '/users/me/update-credentials' && req.body?.email) {
                await updatePasswordInitialized(req.body.email);
            }
            
            res.status(response.status).json({ success: true, message: 'Operation completed successfully' });
        } else {
            const data = await response.json();
            
            // Update password_initialized if this was a successful password change
            if (req.path === '/users/me/update-credentials' && response.status === 200 && req.body?.email) {
                await updatePasswordInitialized(req.body.email);
            }
            
            res.status(response.status).json(data);
        }
    } catch (error) {
        console.error('Proxy error:', error.message);
        res.status(500).json({ error: 'Proxy request failed', message: error.message });
    }
});

// Serve static files from the frontend directory
const frontendPath = path.join(__dirname, '../frontend');
app.use(express.static(frontendPath));

// Main route - serve index.html from frontend folder
app.get('/', (req, res) => {
    res.sendFile(path.join(frontendPath, 'index.html'));
});

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok', service: 'change-password-ui' });
});

// Start server
if (ENABLE_HTTPS && fs.existsSync(SSL_CERT) && fs.existsSync(SSL_KEY)) {
    // HTTPS Server
    const httpsOptions = {
        cert: fs.readFileSync(SSL_CERT),
        key: fs.readFileSync(SSL_KEY)
    };
    
    https.createServer(httpsOptions, app).listen(HTTPS_PORT, () => {
        console.log('┌─────────────────────────────────────────────────┐');
        console.log('│  Silver Mail - Password Change UI Server       │');
        console.log('│  🔒 HTTPS Enabled                               │');
        console.log('└─────────────────────────────────────────────────┘');
        console.log('');
        console.log(`✓ HTTPS Server: https://localhost:${HTTPS_PORT}`);
        console.log(`✓ Change password UI: https://localhost:${HTTPS_PORT}/`);
        console.log(`✓ API Proxy: https://localhost:${HTTPS_PORT}/api/thunder/*`);
        console.log(`✓ Thunder API: ${THUNDER_API}`);
        console.log(`✓ Health check: https://localhost:${HTTPS_PORT}/health`);
        console.log(`✓ Frontend path: ${frontendPath}`);
        console.log('');
        console.log('🔒 SSL/TLS enabled with provided certificates');
        console.log('');
        console.log('Press Ctrl+C to stop the server');
        console.log('');
    });
    
    // HTTP redirect to HTTPS
    if (PORT !== HTTPS_PORT) {
        http.createServer((req, res) => {
            res.writeHead(301, { 'Location': `https://${req.headers.host.split(':')[0]}:${HTTPS_PORT}${req.url}` });
            res.end();
        }).listen(PORT, () => {
            console.log(`↪️  HTTP redirect enabled on port ${PORT} → HTTPS port ${HTTPS_PORT}`);
        });
    }
} else {
    // HTTP Server (fallback)
    app.listen(PORT, () => {
        console.log('┌─────────────────────────────────────────────────┐');
        console.log('│  Silver Mail - Password Change UI Server       │');
        console.log('│  ⚠️  HTTP Mode (No SSL)                         │');
        console.log('└─────────────────────────────────────────────────┘');
        console.log('');
        console.log(`✓ Server running on: http://localhost:${PORT}`);
        console.log(`✓ Change password UI: http://localhost:${PORT}/`);
        console.log(`✓ API Proxy: http://localhost:${PORT}/api/thunder/*`);
        console.log(`✓ Thunder API: ${THUNDER_API}`);
        console.log(`✓ Health check: http://localhost:${PORT}/health`);
        console.log(`✓ Frontend path: ${frontendPath}`);
        console.log('');
        console.log('⚠️  Warning: SSL certificates not found');
        console.log(`   Expected: ${SSL_CERT} and ${SSL_KEY}`);
        console.log('   Set ENABLE_HTTPS=true and provide certificates for HTTPS');
        console.log('');
        console.log('Press Ctrl+C to stop the server');
        console.log('');
    });
}

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully...');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('\nSIGINT received, shutting down gracefully...');
    process.exit(0);
});
