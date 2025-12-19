// State management
let authToken = null;
let userEmail = null;
let tokenExpiry = null;
const SERVER_URL = '/api/thunder';

// Show alert
function showAlert(message, type = 'info') {
    const alert = document.getElementById('alert');
    alert.className = `alert alert-${type} show`;
    alert.textContent = message;
    
    if (type === 'success' || type === 'error') {
        setTimeout(() => {
            alert.classList.remove('show');
        }, 5000);
    }
}

// Update step indicator
function updateSteps(currentStep) {
    const step1 = document.getElementById('step1');
    const step2 = document.getElementById('step2');

    if (currentStep === 1) {
        step1.classList.add('active');
        step2.classList.remove('active', 'completed');
    } else if (currentStep === 2) {
        step1.classList.add('completed');
        step1.classList.remove('active');
        step2.classList.add('active');
    }
}

// Show section
function showSection(sectionName) {
    document.getElementById('loginSection').classList.remove('active');
    document.getElementById('changePasswordSection').classList.remove('active');
    document.getElementById(sectionName + 'Section').classList.add('active');

    if (sectionName === 'login') {
        updateSteps(1);
    } else if (sectionName === 'changePassword') {
        updateSteps(2);
    }
}

// Password strength checker
function checkPasswordStrength(password) {
    let strength = 0;
    const strengthBar = document.getElementById('strengthBar');
    const strengthText = document.getElementById('strengthText');

    if (!password) {
        strengthBar.className = 'strength-bar-fill';
        strengthText.textContent = '';
        return;
    }

    // Length check
    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;

    // Character variety checks
    if (/[a-z]/.test(password) && /[A-Z]/.test(password)) strength++;
    if (/\d/.test(password)) strength++;
    if (/[!@#$%^&*(),.?":{}|<>]/.test(password)) strength++;

    // Update UI
    if (strength <= 2) {
        strengthBar.className = 'strength-bar-fill weak';
        strengthText.textContent = 'Weak password';
        strengthText.style.color = '#ef4444';
    } else if (strength < 4) {
        strengthBar.className = 'strength-bar-fill medium';
        strengthText.textContent = 'Medium strength';
        strengthText.style.color = '#f59e0b';
    } else {
        strengthBar.className = 'strength-bar-fill strong';
        strengthText.textContent = 'Strong password';
        strengthText.style.color = '#10b981';
    }
}

// Validate password requirements
function validatePassword(password) {
    if (password.length < 8) {
        return 'Password must be at least 8 characters long';
    }
    if (!/[a-z]/.test(password)) {
        return 'Password must include lowercase letters';
    }
    if (!/[A-Z]/.test(password)) {
        return 'Password must include uppercase letters';
    }
    if (!/\d/.test(password)) {
        return 'Password must include at least one number';
    }
    if (!/[!@#$%^&*(),.?":{}|<>]/.test(password)) {
        return 'Password must include at least one special character';
    }
    return null;
}

// Format expiry time
function formatExpiry(exp) {
    const expiryDate = new Date(exp * 1000);
    const now = new Date();
    const diff = Math.floor((expiryDate - now) / 1000 / 60); // minutes
    
    if (diff < 1) return 'Expired';
    if (diff < 60) return `${diff} minutes`;
    
    const hours = Math.floor(diff / 60);
    return `${hours} hour${hours > 1 ? 's' : ''}`;
}

// Parse JWT token
function parseJWT(token) {
    try {
        const base64Url = token.split('.')[1];
        const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
        const jsonPayload = decodeURIComponent(atob(base64).split('').map(function(c) {
            return '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2);
        }).join(''));
        return JSON.parse(jsonPayload);
    } catch (e) {
        return null;
    }
}

// Login handler
document.getElementById('loginForm').addEventListener('submit', async (e) => {
    e.preventDefault();

    const email = document.getElementById('loginEmail').value;
    const password = document.getElementById('loginPassword').value;
    const loginBtn = document.getElementById('loginBtn');
    
    loginBtn.disabled = true;
    loginBtn.innerHTML = '<span class="spinner"></span>Signing in...';

    try {
        const response = await fetch(`${SERVER_URL}/auth/credentials/authenticate`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ email, password })
        });
        
        const data = await response.json();

        if (!response.ok) {
            throw new Error(data.message || 'Authentication failed');
        }

        // Extract token (assertion)
        authToken = data.assertion || data.token || data.access_token;
        
        if (!authToken) {
            throw new Error('No authentication token received from server');
        }

        // Parse token to get user info
        const tokenData = parseJWT(authToken);
        
        if (tokenData) {
            userEmail = email;
            tokenExpiry = tokenData.exp;

            // Update UI with user info
            document.getElementById('userEmail').textContent = email;
            document.getElementById('sessionExpiry').textContent = formatExpiry(tokenData.exp);
        }

        // Check password initialization status
        try {
            const statusResponse = await fetch('/api/check-password-status', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ email })
            });
            const statusData = await statusResponse.json();
            
            if (statusData.must_change_password) {
                showAlert('Password change required. This is your first login with an admin-created password.', 'warning');
            } else {
                showAlert('Successfully authenticated. You can now change your password.', 'success');
            }
        } catch (err) {
            showAlert('Successfully authenticated! You can now change your password.', 'success');
        }
        
        // Switch to password change section
        setTimeout(() => {
            showSection('changePassword');
        }, 1500);

    } catch (error) {
        showAlert(error.message || 'Authentication failed. Please check your credentials.', 'error');
    } finally {
        loginBtn.disabled = false;
        loginBtn.innerHTML = 'Sign In & Continue';
    }
});

// Password strength monitoring
document.getElementById('newPassword').addEventListener('input', (e) => {
    checkPasswordStrength(e.target.value);
});

// Change password handler
document.getElementById('changePasswordForm').addEventListener('submit', async (e) => {
    e.preventDefault();

    const newPassword = document.getElementById('newPassword').value;
    const confirmPassword = document.getElementById('confirmPassword').value;
    const changePasswordBtn = document.getElementById('changePasswordBtn');

    console.log('🔄 Password change initiated');

    // Validate passwords match
    if (newPassword !== confirmPassword) {
        showAlert('Passwords do not match', 'error');
        return;
    }

    // Validate password requirements
    const validationError = validatePassword(newPassword);
    if (validationError) {
        showAlert(validationError, 'error');
        return;
    }
    
    changePasswordBtn.disabled = true;
    changePasswordBtn.innerHTML = '<span class="spinner"></span>Updating password...';

    try {
        const response = await fetch(`${SERVER_URL}/users/me/update-credentials`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Accept': 'application/json',
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                email: userEmail,
                attributes: {
                    password: newPassword
                }
            })
        });

        if (!response.ok) {
            const errorData = await response.json().catch(() => ({}));
            throw new Error(errorData.message || `Server returned ${response.status}: ${response.statusText}`);
        }

        // Handle 204 No Content or successful responses
        let data = {};
        if (response.status === 204 || response.headers.get('content-length') === '0') {
            data = { success: true, message: 'Password updated successfully' };
        } else {
            data = await response.json();
        }
        
        showAlert('Password updated successfully. Redirecting to login...', 'success');

        // Reset form and go back to login after 2 seconds
        setTimeout(() => {
            authToken = null;
            userEmail = null;
            tokenExpiry = null;
            document.getElementById('loginForm').reset();
            document.getElementById('changePasswordForm').reset();
            showSection('login');
            showAlert('Please sign in with your new password.', 'info');
        }, 2000);

    } catch (error) {
        showAlert(error.message || 'Failed to update password. Please try again.', 'error');
    } finally {
        changePasswordBtn.disabled = false;
        changePasswordBtn.innerHTML = 'Update Password';
    }
});

// Logout handler
document.getElementById('logoutBtn').addEventListener('click', () => {
    authToken = null;
    userEmail = null;
    tokenExpiry = null;
    document.getElementById('loginForm').reset();
    document.getElementById('changePasswordForm').reset();
    showSection('login');
    showAlert('Logged out successfully', 'info');
});
