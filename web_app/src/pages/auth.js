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
      <div class="onboarding-container animate-fade-in" style="justify-content: center; max-width: 440px; margin: 0 auto; min-height: 100vh; padding: 32px 20px;">
        <!-- Brand Header -->
        <div style="text-align: center; margin-bottom: 24px;">
          <div class="auth-header-logo" style="width: 72px; height: 72px; background: linear-gradient(135deg, var(--primary) 0%, #FF8C42 100%); border-radius: 20px; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px; box-shadow: 0 10px 25px rgba(255, 95, 31, 0.3);">
            <span class="material-icons" style="font-size: 40px; color: #FFF;">account_balance_wallet</span>
          </div>
          <h1 class="onboarding-title" style="font-size: 32px; margin-bottom: 6px; font-weight: 800; letter-spacing: -0.5px;">Quantro</h1>
          <p style="color: var(--text-secondary); font-size: 14px; line-height: 1.4;">
            ${this.isSignUp ? 'Create your account to sync finances across devices' : 'Sign in to access your synchronized cloud data'}
          </p>
        </div>

        <!-- Glassmorphic Auth Card -->
        <div class="glass-card auth-card" style="padding: 28px 24px;">
          <!-- Login/SignUp Tab Toggle -->
          <div class="tab-bar" style="margin-bottom: 24px; padding: 3px; background: rgba(255, 255, 255, 0.05); border-radius: 12px;">
            <button class="tab-button ${!this.isSignUp ? 'active' : ''}" id="auth-tab-signin" style="border-radius: 10px;">Sign In</button>
            <button class="tab-button ${this.isSignUp ? 'active' : ''}" id="auth-tab-signup" style="border-radius: 10px;">Create Account</button>
          </div>

          <!-- Error Alert -->
          ${this.errorMessage ? `
            <div class="auth-error animate-fade-in" style="background: rgba(239, 68, 68, 0.15); border: 1px solid rgba(239, 68, 68, 0.3); color: #FCA5A5; padding: 12px 16px; border-radius: 12px; font-size: 13px; margin-bottom: 18px; display: flex; align-items: flex-start; gap: 10px; line-height: 1.4;">
              <span class="material-icons" style="font-size: 18px; color: var(--error); margin-top: 1px;">error_outline</span>
              <div style="flex: 1;">${this.errorMessage}</div>
            </div>
          ` : ''}

          <!-- Form Fields -->
          <div class="form-group" style="margin-bottom: 16px;">
            <label class="form-label" style="font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: var(--text-muted); margin-bottom: 6px; display: block;">Email Address</label>
            <div class="form-input-container">
              <span class="material-icons form-input-icon" style="color: var(--text-muted);">mail_outline</span>
              <input type="email" class="form-input" id="auth-email-input" placeholder="you@example.com" value="${this.emailInput}" autocomplete="email">
            </div>
          </div>

          <div class="form-group" style="margin-bottom: 12px;">
            <label class="form-label" style="font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: var(--text-muted); margin-bottom: 6px; display: block;">Password</label>
            <div class="form-input-container has-suffix">
              <span class="material-icons form-input-icon" style="color: var(--text-muted);">lock_outline</span>
              <input type="password" class="form-input" id="auth-password-input" placeholder="••••••••" value="${this.passwordInput}" autocomplete="current-password">
              <span class="material-icons form-input-suffix" id="auth-toggle-pwd" style="cursor: pointer; color: var(--text-muted);">visibility_off</span>
            </div>
          </div>

          <!-- Forgot Password Link -->
          ${!this.isSignUp ? `
            <div style="text-align: right; margin-bottom: 20px;">
              <a href="#" id="auth-forgot-pwd" style="font-size: 12px; font-weight: 600; color: var(--primary); text-decoration: none;">Forgot Password?</a>
            </div>
          ` : '<div style="height: 16px;"></div>'}

          <!-- Action Button -->
          <button class="btn btn-primary" id="auth-submit-btn" ${this.isLoading ? 'disabled' : ''} style="display: flex; align-items: center; justify-content: center; gap: 8px; font-weight: 700;">
            ${this.isLoading ? `
              <span class="material-icons animate-spin" style="font-size: 20px;">sync</span> Signing In...
            ` : (this.isSignUp ? 'Create Account' : 'Sign In')}
          </button>

          <!-- Divider -->
          <div class="divider-text" style="margin: 20px 0; display: flex; align-items: center; text-align: center; color: var(--text-muted); font-size: 11px; text-transform: uppercase; letter-spacing: 0.1em;">
            <span style="flex: 1; border-bottom: 1px solid var(--divider);"></span>
            <span style="padding: 0 12px;">OR</span>
            <span style="flex: 1; border-bottom: 1px solid var(--divider);"></span>
          </div>

          <!-- Google Sign In Button -->
          <button class="btn btn-outline" id="auth-google-btn" ${this.isLoading ? 'disabled' : ''} style="display: flex; align-items: center; justify-content: center; gap: 10px; font-weight: 600;">
            <svg width="18" height="18" viewBox="0 0 24 24">
              <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
              <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
              <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"/>
              <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"/>
            </svg>
            Continue with Google
          </button>
        </div>

        <!-- Offline Guest Mode option -->
        <button class="btn btn-outline" id="auth-guest-btn" style="margin-top: 20px; border-color: rgba(255, 255, 255, 0.12); color: var(--text-secondary); display: flex; align-items: center; justify-content: center; gap: 8px;">
          <span class="material-icons" style="font-size: 18px; color: var(--text-muted);">cloud_off</span>
          Continue in Offline Mode (Guest)
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
      // Submit on Enter key
      pwdField.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
          document.getElementById('auth-submit-btn')?.click();
        }
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
        const email = (this.emailInput || '').trim();
        const pwd = this.passwordInput || '';

        if (!email || email.indexOf('@') === -1) {
          this.errorMessage = 'Please enter a valid email address.';
          StateManager.notify();
          return;
        }
        if (!pwd || pwd.length < 6) {
          this.errorMessage = 'Password must be at least 6 characters.';
          StateManager.notify();
          return;
        }

        this.isLoading = true;
        this.errorMessage = null;
        StateManager.notify();

        try {
          if (this.isSignUp) {
            const res = await AuthService.signUpWithEmail(email, pwd);
            DbService.startSync(res.user.uid);
            await DbService.syncGuestDataToCloud(res.user.uid);
          } else {
            const res = await AuthService.signInWithEmail(email, pwd);
            DbService.startSync(res.user.uid);
            await DbService.syncGuestDataToCloud(res.user.uid);
          }
          this.isLoading = false;
        } catch (err) {
          this.errorMessage = err.message || 'Authentication failed.';
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
          this.isLoading = false;
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
        StateManager.enableGuestMode();
      });
    }
  },

  // Modal for Password Reset
  showForgotPasswordDialog() {
    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    overlay.innerHTML = `
      <div class="modal-card animate-fade-in" style="background:#1A1A2E; width:95%; max-width:400px; padding:24px;">
        <div class="modal-header" style="margin-bottom:12px;">
          <h3 style="color:#FFF; font-size:18px;">Reset Password</h3>
          <button class="modal-close" id="forgot-modal-close">&times;</button>
        </div>
        <p style="color:rgba(255,255,255,0.7); font-size:13px; margin-bottom:16px; line-height:1.4;">
          Enter your registered email address to receive password reset instructions.
        </p>
        <div class="form-group" style="margin-bottom:16px;">
          <label class="form-label" style="font-size:12px; color:var(--text-muted); margin-bottom:6px; display:block;">Email Address</label>
          <input type="email" class="form-input" id="forgot-email-field" placeholder="you@example.com" value="${this.emailInput}">
        </div>
        <div id="forgot-error-msg" style="color:var(--error); font-size:12px; margin-bottom:12px; display:none;"></div>
        <div style="display:flex; gap:12px; justify-content:flex-end;">
          <button class="btn btn-outline" id="forgot-cancel-btn" style="width:auto; padding:8px 16px; font-size:13px;">Cancel</button>
          <button class="btn btn-primary" id="forgot-submit-btn" style="width:auto; padding:8px 16px; font-size:13px;">Send Email</button>
        </div>
      </div>
    `;
    
    document.body.appendChild(overlay);

    const closeModal = () => {
      if (document.body.contains(overlay)) {
        document.body.removeChild(overlay);
      }
    };

    document.getElementById('forgot-modal-close').addEventListener('click', closeModal);
    document.getElementById('forgot-cancel-btn').addEventListener('click', closeModal);

    document.getElementById('forgot-submit-btn').addEventListener('click', async () => {
      const emailField = document.getElementById('forgot-email-field');
      const email = emailField ? emailField.value.trim() : '';
      const errorDiv = document.getElementById('forgot-error-msg');

      if (!email || email.indexOf('@') === -1) {
        if (errorDiv) {
          errorDiv.textContent = 'Please enter a valid email address.';
          errorDiv.style.display = 'block';
        }
        return;
      }

      try {
        await AuthService.resetPassword(email);
        alert(`Password reset link sent to ${email}. Please check your inbox.`);
        closeModal();
      } catch (err) {
        if (errorDiv) {
          errorDiv.textContent = err.message || 'Failed to send reset email.';
          errorDiv.style.display = 'block';
        }
      }
    });
  }
};
