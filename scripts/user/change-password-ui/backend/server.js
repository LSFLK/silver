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
const THUNDER_API = process.env.THUNDER_API || 'https://thunder-server:8090';

// Startup logging
console.log('🚀 Starting Silver Mail - Change Password UI Server...');
console.log(`📋 Configuration:`);
console.log(`   PORT: ${PORT}`);
console.log(`   HTTPS_PORT: ${HTTPS_PORT}`);
console.log(`   THUNDER_API: ${THUNDER_API}`);
console.log(`   NODE_ENV: ${process.env.NODE_ENV || 'development'}`);
console.log('');

// Suppress specific Node.js warnings that are expected in this environment
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0'; // For self-signed certificates
process.removeAllListeners('warning'); // Remove default warning listeners

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

// Utility function to check if SMTP container is ready
async function isSmtpContainerReady() {
    try {
        const { execSync } = require('child_process');
        const result = execSync('docker ps --filter "name=smtp-server-container" --filter "status=running" --format "{{.Names}}"', 
                              { encoding: 'utf8', timeout: 5000 });
        return result.trim() === 'smtp-server-container';
    } catch (error) {
        return false;
    }
}

// Utility function to check if database is accessible
async function isDatabaseReady() {
    try {
        const { execSync } = require('child_process');
        const result = execSync('docker exec smtp-server-container sqlite3 /app/data/databases/shared.db "SELECT 1;"', 
                              { encoding: 'utf8', timeout: 5000 });
        return result.trim() === '1';
    } catch (error) {
        return false;
    }
}

// Check password initialization status
app.post('/api/check-password-status', async (req, res) => {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: 'Email required' });
    
    // Check if containers are ready
    const smtpReady = await isSmtpContainerReady();
    if (!smtpReady) {
        console.warn('SMTP container not ready for database operations');
        return res.status(503).json({ error: 'Service not ready, please try again' });
    }
    
    const dbReady = await isDatabaseReady();
    if (!dbReady) {
        console.warn('Database not ready for operations');
        return res.status(503).json({ error: 'Database not ready, please try again' });
    }
    
    try {
        const { execSync } = require('child_process');
        const [username, domain] = email.split('@');
        
        // Validate email format
        if (!username || !domain) {
            return res.status(400).json({ error: 'Invalid email format' });
        }
        
        const cmd = `docker exec smtp-server-container sqlite3 /app/data/databases/shared.db "SELECT password_initialized FROM users u INNER JOIN domains d ON u.domain_id = d.id WHERE u.username='${username}' AND d.domain='${domain}' AND u.enabled=1;" 2>&1`;
        const result = execSync(cmd, { encoding: 'utf8', timeout: 10000 }).trim();
        
        // Handle cases where user is not found
        if (result === '' || result.includes('Error') || result.includes('no such table')) {
            console.warn(`User not found or database error: ${email}`);
            return res.status(404).json({ error: 'User not found' });
        }
        
        const initialized = result === '1';
        res.json({ email, password_initialized: initialized, must_change_password: !initialized });
    } catch (error) {
        console.error('Check password status error:', error.message);
        res.status(500).json({ error: 'Failed to check password status', details: error.message });
    }
});

// Update password_initialized after password change
async function updatePasswordInitialized(email) {
    if (!email) return;
    
    // Check if containers are ready before attempting database operations
    const smtpReady = await isSmtpContainerReady();
    const dbReady = await isDatabaseReady();
    
    if (!smtpReady || !dbReady) {
        console.warn('Containers not ready for password initialization update, skipping...');
        return;
    }
    
    try {
        const { execSync } = require('child_process');
        const [username, domain] = email.split('@');
        
        // Validate email format
        if (!username || !domain) {
            console.error('Invalid email format for password initialization update:', email);
            return;
        }
        
        const cmd = `docker exec smtp-server-container sqlite3 /app/data/databases/shared.db "UPDATE users SET password_initialized = 1 WHERE id IN (SELECT u.id FROM users u INNER JOIN domains d ON u.domain_id = d.id WHERE u.username='${username}' AND d.domain='${domain}');" 2>&1`;
        const result = execSync(cmd, { encoding: 'utf8', timeout: 10000 });
        
        if (result && result.includes('Error')) {
            console.error('SQL error updating password_initialized:', result);
        } else {
            console.log(`✓ Password initialization status updated for: ${email}`);
        }
    } catch (error) {
        console.error('Update password_initialized failed:', error.message);
    }
}

// CORS proxy middleware - intercept API calls and proxy them to avoid CORS
app.use('/api/thunder', async (req, res) => {
    const targetUrl = `${THUNDER_API}${req.path}`;
    
    try {
        const https = require('https');
        // Create HTTPS agent with better security configuration
        const agent = new https.Agent({ 
            rejectUnauthorized: false, // Accept self-signed certs for internal communication
            keepAlive: true,
            timeout: 30000
        });
        
        const fetch = (await import('node-fetch')).default;
        
        console.log(`Proxying ${req.method} ${targetUrl}`);
        
        const response = await fetch(targetUrl, {
            method: req.method,
            headers: {
                'Content-Type': 'application/json',
                ...(req.headers.authorization && { 'Authorization': req.headers.authorization }),
            },
            body: req.method !== 'GET' ? JSON.stringify(req.body) : undefined,
            agent,
            timeout: 30000
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
        console.error(`Proxy error for ${req.method} ${targetUrl}:`, error.message);
        res.status(500).json({ 
            error: 'Proxy request failed', 
            message: error.message,
            target: targetUrl
        });
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
app.get('/health', async (req, res) => {
    const status = {
        status: 'ok',
        service: 'change-password-ui',
        timestamp: new Date().toISOString(),
        dependencies: {
            smtpContainer: await isSmtpContainerReady(),
            database: await isDatabaseReady()
        }
    };
    
    const allReady = status.dependencies.smtpContainer && status.dependencies.database;
    const httpStatus = allReady ? 200 : 503;
    
    res.status(httpStatus).json(status);
});

// Startup dependency check with retry logic
async function waitForDependencies() {
    console.log('🔍 Checking service dependencies...');
    
    let retries = 0;
    const maxRetries = 30; // 5 minutes with 10 second intervals
    
    while (retries < maxRetries) {
        const smtpReady = await isSmtpContainerReady();
        const dbReady = await isDatabaseReady();
        
        if (smtpReady && dbReady) {
            console.log('✅ All dependencies are ready!');
            return true;
        }
        
        console.log(`⏳ Waiting for dependencies... (${retries + 1}/${maxRetries})`);
        console.log(`   SMTP Container: ${smtpReady ? '✅' : '❌'}`);
        console.log(`   Database: ${dbReady ? '✅' : '❌'}`);
        
        retries++;
        await new Promise(resolve => setTimeout(resolve, 10000)); // Wait 10 seconds
    }
    
    console.warn('⚠️  Some dependencies are not ready, starting anyway...');
    return false;
}

// Initialize server with dependency checking
async function initializeServer() {
    await waitForDependencies();
    
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
        
        // HTTP redirect to HTTPS - Only enable if explicitly requested
        const enableHttpRedirect = process.env.ENABLE_HTTP_REDIRECT !== 'false';
        
        if (PORT !== HTTPS_PORT && enableHttpRedirect) {
            const httpServer = http.createServer((req, res) => {
                const host = req.headers.host;
                let redirectHost;
                
                if (host) {
                    // Extract hostname without port
                    const hostname = host.split(':')[0];
                    // For Docker environment, use the same hostname with HTTPS port
                    redirectHost = `${hostname}:${HTTPS_PORT}`;
                } else {
                    // Fallback
                    redirectHost = `localhost:${HTTPS_PORT}`;
                }
                
                const redirectUrl = `https://${redirectHost}${req.url}`;
                console.log(`HTTP redirect: ${req.url} -> ${redirectUrl}`);
                
                res.writeHead(301, { 
                    'Location': redirectUrl,
                    'Connection': 'close'
                });
                res.end();
            });
            
            // Add error handling for HTTP redirect server
            httpServer.on('error', (err) => {
                console.error('HTTP redirect server error:', err.message);
            });
            
            httpServer.listen(PORT, () => {
                console.log(`↪️  HTTP redirect enabled on port ${PORT} → HTTPS port ${HTTPS_PORT}`);
                console.log(`   To disable HTTP redirect, set ENABLE_HTTP_REDIRECT=false`);
            });
        } else if (PORT !== HTTPS_PORT) {
            console.log(`📝 HTTP redirect disabled (ENABLE_HTTP_REDIRECT=false)`);
            console.log(`   Only HTTPS server running on port ${HTTPS_PORT}`);
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

// Start the server initialization
initializeServer().catch(err => {
    console.error('Server initialization failed:', err.message);
    process.exit(1);
});
