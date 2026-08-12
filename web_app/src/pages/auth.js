/* Authentication Screen Module (Sign In, Sign Up, Google OAuth, and Offline Mode) */
import { StateManager } from '../state.js';
import { AuthService } from '../auth.js';
import { DbService } from '../db.js';

export const AuthPage = {
  isSignUp: false,
  errorMessage: null,
  isLoading: false,
  
  // Controllers
  emailInput: '',
  passwordInput: '',

  render(state) {
    return `
      <div class="onboarding-container animate-fade-in" style="justify-content: center; max-width: 440px; margin: 0 auto;">
        <!-- Brand Header -->
        <div style="text-align: center; margin-bottom: 24px;">
          <div class="auth-header-logo">
            <span class="material-icons" style="font-size: 54px;">account_balance_wallet</span>
          </div>
          <h1 class="onboarding-title" style="font-size: 34px; margin-bottom: 4px;">Quantro</h1>
          <p style="color: var(--text-secondary); font-size: 14px;">
            ${this.isSignUp ? 'Create your account to sync data securely' : 'Welcome back! Sign in to restore your cloud data'}
          </p>
        </div>

        <!-- Glassmorphic Auth Card -->
        <div class="glass-card auth-card">
          <!-- Login/SignUp Tab Toggle -->
          <div class="tab-bar" style="margin-bottom: 24px;">
            <button class="tab-button ${!this.isSignUp ? 'active' : ''}" id="auth-tab-signin">Sign In</button>
            <button class="tab-button ${this.isSignUp ? 'active' : ''}" id="auth-tab-signup">Create Account</button>
          </div>

          <!-- Error Alert -->
          ${this.errorMessage ? `
            <div class="auth-error animate-fade-in">
              <span class="material-icons">error_outline</span>
              <div>${this.errorMessage}</div>
            </div>
          ` : ''}

          <!-- Form Fields -->
          <div class="form-group">
            <label class="form-label">Email Address</label>
            <div class="form-input-container">
              <span class="material-icons form-input-icon">mail_outline</span>
              <input type="email" class="form-input" id="auth-email-input" placeholder="you@example.com" value="${this.emailInput}">
            </div>
          </div>

          <div class="form-group" style="margin-bottom: 12px;">
            <label class="form-label">Password</label>
            <div class="form-input-container has-suffix">
              <span class="material-icons form-input-icon">lock_outline</span>
              <input type="password" class="form-input" id="auth-password-input" placeholder="••••••••" value="${this.passwordInput}">
              <span class="material-icons form-input-suffix" id="auth-toggle-pwd">visibility_off</span>
            </div>
          </div>

          <!-- Forgot Password Link -->
          ${!this.isSignUp ? `
            <div style="text-align: right; margin-bottom: 20px;">
              <a href="#" id="auth-forgot-pwd" style="font-size: 13px; font-weight: 500;">Forgot Password?</a>
            </div>
          ` : '<div style="height: 16px;"></div>'}

          <!-- Action Button -->
          <button class="btn btn-primary" id="auth-submit-btn" ${this.isLoading ? 'disabled' : ''}>
            ${this.isLoading ? `
              <span class="material-icons animate-spin" style="font-size: 20px;">sync</span>
            ` : (this.isSignUp ? 'Create Account' : 'Sign In')}
          </button>

          <!-- Divider -->
          <div class="divider-text">OR</div>

          <!-- Google Sign In Button -->
          <button class="btn btn-outline" id="auth-google-btn" ${this.isLoading ? 'disabled' : ''}>
            <span style="font-size: 22px; font-weight: bold; color: #EA4335; margin-right: 8px;">G</span>
            Continue with Google
          </button>
        </div>

        <!-- Offline Guest Mode option -->
        <button class="btn btn-outline" id="auth-guest-btn" style="margin-top: 24px; border-color: rgba(255, 255, 255, 0.15); color: var(--text-secondary);">
          <span class="material-icons" style="font-size: 20px; color: var(--text-muted);">cloud_off</span>
          Continue in Offline Mode (Local Only)
        </button>
      </div>
    `;
  },

  bindEvents() {
    // Tab toggles
    const tabSignIn = document.getElementById('auth-tab-signin');
    if (tabSignIn) {
      tabSignIn.addEventListener('click', () => {
        this.isSignUp = false;
        this.errorMessage = null;
        StateManager.notify();
      });
    }

    const tabSignUp = document.getElementById('auth-tab-signup');
    if (tabSignUp) {
      tabSignUp.addEventListener('click', () => {
        this.isSignUp = true;
        this.errorMessage = null;
        StateManager.notify();
      });
    }

    // Capture inputs
    const emailField = document.getElementById('auth-email-input');
    if (emailField) {
      emailField.addEventListener('input', (e) => {
        this.emailInput = e.target.value;
      });
    }

    const pwdField = document.getElementById('auth-password-input');
    if (pwdField) {
      pwdField.addEventListener('input', (e) => {
        this.passwordInput = e.target.value;
      });
    }

    // Toggle Password Visibility
    const pwdToggle = document.getElementById('auth-toggle-pwd');
    if (pwdToggle && pwdField) {
      pwdToggle.addEventListener('click', () => {
        if (pwdField.type === 'password') {
          pwdField.type = 'text';
          pwdToggle.textContent = 'visibility';
        } else {
          pwdField.type = 'password';
          pwdToggle.textContent = 'visibility_off';
        }
      });
    }

    // Forgot password modal
    const forgotPwdLink = document.getElementById('auth-forgot-pwd');
    if (forgotPwdLink) {
      forgotPwdLink.addEventListener('click', (e) => {
        e.preventDefault();
        this.showForgotPasswordDialog();
      });
    }

    // Submit Email/Password Auth
    const submitBtn = document.getElementById('auth-submit-btn');
    if (submitBtn) {
      submitBtn.addEventListener('click', async () => {
        if (!this.emailInput || this.emailInput.indexOf('@') === -1) {
          this.errorMessage = 'Please enter a valid email address.';
          StateManager.notify();
          return;
        }
        if (!this.passwordInput || this.passwordInput.length < 6) {
          this.errorMessage = 'Password must be at least 6 characters.';
          StateManager.notify();
          return;
        }

        this.isLoading = true;
        this.errorMessage = null;
        StateManager.notify();

        try {
          if (this.isSignUp) {
            const res = await AuthService.signUpWithEmail(this.emailInput, this.passwordInput);
            // Trigger Firestore Sync after sign-in
            DbService.startSync(res.user.uid);
            await DbService.syncGuestDataToCloud(res.user.uid);
          } else {
            const res = await AuthService.signInWithEmail(this.emailInput, this.passwordInput);
            DbService.startSync(res.user.uid);
            await DbService.syncGuestDataToCloud(res.user.uid);
          }
        } catch (err) {
          this.errorMessage = err.message.replace('Firebase:', '').trim();
          this.isLoading = false;
          StateManager.notify();
        }
      });
    }

    // Google Sign-In
    const googleBtn = document.getElementById('auth-google-btn');
    if (googleBtn) {
      googleBtn.addEventListener('click', async () => {
        this.isLoading = true;
        this.errorMessage = null;
        StateManager.notify();

        try {
          const user = await AuthService.signInWithGoogle();
          if (user) {
            DbService.startSync(user.uid);
            await DbService.syncGuestDataToCloud(user.uid);
          }
        } catch (err) {
          this.errorMessage = err.message || 'Google authentication failed.';
          this.isLoading = false;
          StateManager.notify();
        }
      });
    }

    // Offline mode button
    const guestBtn = document.getElementById('auth-guest-btn');
    if (guestBtn) {
      guestBtn.addEventListener('click', () => {
        // Just turn on Guest mode and proceed to main shell
        StateManager.enableGuestMode();
      });
    }
  },

  // Premium Alert Modal for Password Reset
  showForgotPasswordDialog() {
    // Dynamically inject custom modal HTML
    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    overlay.innerHTML = `
      <div class="modal-card animate-fade-in" style="background:#1A1A2E;">
        <div class="modal-header">
          <h3 style="color:#FFF;">Reset Password</h3>
          <button class="modal-close" id="forgot-modal-close">&times;</button>
        </div>
        <p style="color:rgba(255,255,255,0.7); font-size:13px; margin-bottom:16px;">
          Enter your registered email address to receive password reset instructions.
        </p>
        <div class="form-group">
          <label class="form-label">Email Address</label>
          <input type="email" class="form-input" id="forgot-email-field" placeholder="you@example.com" value="${this.emailInput}">
        </div>
        <div style="display:flex; gap:12px; justify-content:flex-end; margin-top:20px;">
          <button class="btn btn-outline" id="forgot-cancel-btn" style="width:auto; padding:10px 20px;">Cancel</button>
          <button class="btn btn-primary" id="forgot-submit-btn" style="width:auto; padding:10px 20px;">Send Email</button>
        </div>
      </div>
    `;
    
    document.body.appendChild(overlay);

    // Event handlers inside Modal
    const closeModal = () => {
      document.body.removeChild(overlay);
    };

    document.getElementById('forgot-modal-close').addEventListener('click', closeModal);
    document.getElementById('forgot-cancel-btn').addEventListener('click', closeModal);

    document.getElementById('forgot-submit-btn').addEventListener('click', async () => {
      const emailField = document.getElementById('forgot-email-field');
      const email = emailField.value.trim();
      if (!email || email.indexOf('@') === -1) {
        alert('Please enter a valid email address.');
        return;
      }

      try {
        await AuthService.resetPassword(email);
        alert('Password reset email sent successfully!');
        closeModal();
      } catch (err) {
        alert('Error: ' + err.message);
      }
    });
  }
};
