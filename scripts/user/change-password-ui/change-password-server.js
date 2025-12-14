#!/usr/bin/env node

/**
 * Silver Mail - Change Password UI Server
 *
 * Simple Express server to serve the password change UI
 *
 * Usage:
 *   npm install express
 *   node change-password-server.js
 *
 * Or:
 *   npm start
 */

const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3001;
const THUNDER_API = process.env.THUNDER_API || 'https://localhost:8090';

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
        console.log(`✅ ${email} password_initialized: ${initialized}`);
        res.json({ email, password_initialized: initialized, must_change_password: !initialized });
    } catch (error) {
        console.error('❌ Check status error:', error.message);
        res.status(500).json({ error: 'Failed to check status' });
    }
});

// Update password_initialized after password change
async function updatePasswordInitialized(email) {
    if (!email) return;
    try {
        const { execSync } = require('child_process');
        const [username, domain] = email.split('@');
        console.log(`🔄 Setting password_initialized=1 for ${email}...`);
        const cmd = `docker exec smtp-server-container sqlite3 /app/data/databases/shared.db "UPDATE users SET password_initialized = 1 WHERE id IN (SELECT u.id FROM users u INNER JOIN domains d ON u.domain_id = d.id WHERE u.username='${username}' AND d.domain='${domain}');" 2>&1`;
        execSync(cmd);
        console.log(`✅ Updated password_initialized for ${email}`);
    } catch (error) {
        console.error('❌ Update failed:', error.message);
    }
}

// CORS proxy middleware - intercept API calls and proxy them to avoid CORS
app.use('/api/thunder', async (req, res) => {
    const targetUrl = `${THUNDER_API}${req.path}`;
    
    console.log(`🔄 Proxying ${req.method} ${req.path} to ${targetUrl}`);
    
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
            console.log(`✅ ${response.status} - No content (success)`);
            
            // Update password_initialized if this was a password change
            if (req.path === '/users/me/update-credentials' && req.body?.email) {
                await updatePasswordInitialized(req.body.email);
            }
            
            res.status(response.status).json({ success: true, message: 'Operation completed successfully' });
        } else {
            const data = await response.json();
            console.log(`✅ ${response.status} - Response:`, data);
            
            // Update password_initialized if this was a successful password change
            if (req.path === '/users/me/update-credentials' && response.status === 200 && req.body?.email) {
                await updatePasswordInitialized(req.body.email);
            }
            
            res.status(response.status).json(data);
        }
    } catch (error) {
        console.error('❌ Proxy error:', error);
        res.status(500).json({ error: 'Proxy request failed', message: error.message });
    }
});

// Serve static files
app.use(express.static(__dirname));

// Main route
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'change-password-ui.html'));
});

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok', service: 'change-password-ui' });
});

// Start server
app.listen(PORT, () => {
    console.log('┌─────────────────────────────────────────────────┐');
    console.log('│  Silver Mail - Password Change UI Server       │');
    console.log('└─────────────────────────────────────────────────┘');
    console.log('');
    console.log(`✓ Server running on: http://localhost:${PORT}`);
    console.log(`✓ Change password UI: http://localhost:${PORT}/`);
    console.log(`✓ API Proxy: http://localhost:${PORT}/api/thunder/*`);
    console.log(`✓ Thunder API: ${THUNDER_API}`);
    console.log(`✓ Health check: http://localhost:${PORT}/health`);
    console.log('');
    console.log('🔧 CORS handled via proxy - no browser CORS errors!');
    console.log('');
    console.log('Press Ctrl+C to stop the server');
    console.log('');
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully...');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('\nSIGINT received, shutting down gracefully...');
    process.exit(0);
});
