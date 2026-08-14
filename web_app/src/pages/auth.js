/* Modern Landing & Authentication Module */
import { StateManager } from '../state.js';
import { AuthService } from '../auth.js';
import { DbService } from '../db.js';

export const AuthPage = {
  isSignUp: false,
  errorMessage: null,
  isLoading: false,
  
  emailInput: '',
  passwordInput: '',

  render(state) {
    return `
      <div class="site-wrapper animate-fade-in" style="min-height: 100vh;">
        <!-- Ambient lighting mesh -->
        <div class="ambient-glow">
          <div class="ambient-circle-1"></div>
          <div class="ambient-circle-2"></div>
        </div>

        <!-- Minimal Website Header -->
        <header class="site-header">
          <div class="site-container">
            <div class="header-inner">
              <div class="brand-link">
                <div class="brand-icon">
                  <span class="material-icons">account_balance_wallet</span>
                </div>
                <div class="brand-name">
                  Quantro
                  <span class="brand-tag">FINANCE</span>
                </div>
              </div>

              <div class="header-actions">
                <button class="btn-ghost" id="landing-guest-btn">
                  <span class="material-icons" style="font-size: 16px;">explore</span> Explore Demo
                </button>
              </div>
            </div>
          </div>
        </header>

        <!-- Landing Hero -->
        <main class="site-container" style="flex: 1;">
          <section class="landing-hero">
            <div class="landing-badge">
              <span class="material-icons" style="font-size: 16px;">auto_awesome</span>
              Cloud Synced Personal Finance Platform
            </div>

            <h1 class="landing-title">
              Unified Capital Intelligence.<br>Built for Modern Wealth.
            </h1>

            <p class="landing-subtitle">
              Seamless bidirectional sync between your phone and desktop. Track cash flows, project month-end liquidity, and reach savings milestones.
            </p>

            <!-- Authentication Card -->
            <div class="landing-auth-card">
              <!-- Tab Switcher -->
              <div class="filter-group" style="margin-bottom: 24px; width: 100%; padding: 4px;">
                <button class="filter-chip ${!this.isSignUp ? 'active' : ''}" id="auth-tab-signin" style="flex: 1; text-align: center; padding: 8px 16px;">
                  Sign In
                </button>
                <button class="filter-chip ${this.isSignUp ? 'active' : ''}" id="auth-tab-signup" style="flex: 1; text-align: center; padding: 8px 16px;">
                  Create Account
                </button>
              </div>

              <!-- Error Alert -->
              ${this.errorMessage ? `
                <div style="background: var(--error-bg); border: 1px solid rgba(244, 63, 94, 0.3); color: #FDA4AF; padding: 12px 16px; border-radius: var(--radius-md); font-size: 13px; margin-bottom: 18px; display: flex; align-items: center; gap: 10px;">
                  <span class="material-icons" style="font-size: 18px; color: var(--error);">error_outline</span>
                  <span>${this.errorMessage}</span>
                </div>
              ` : ''}

              <!-- Form Inputs -->
              <div class="form-group">
                <label class="form-label" style="text-align: left;">Email Address</label>
                <input type="email" class="form-control" id="auth-email-input" placeholder="you@example.com" value="${this.emailInput}">
              </div>

              <div class="form-group">
                <div style="display: flex; justify-content: space-between; align-items: center;">
                  <label class="form-label">Password</label>
                  ${!this.isSignUp ? `
                    <a href="#" id="auth-forgot-pwd" style="font-size: 12px; color: var(--primary);">Forgot?</a>
                  ` : ''}
                </div>
                <input type="password" class="form-control" id="auth-password-input" placeholder="••••••••" value="${this.passwordInput}">
              </div>

              <!-- Submit Button -->
              <button class="btn-primary" id="auth-submit-btn" ${this.isLoading ? 'disabled' : ''} style="width: 100%; padding: 14px; margin-top: 8px;">
                ${this.isLoading ? `
                  <span class="material-icons animate-spin" style="font-size: 18px;">sync</span> Authenticating...
                ` : (this.isSignUp ? 'Create Cloud Account' : 'Sign In to Quantro')}
              </button>

              <!-- Divider -->
              <div style="display: flex; align-items: center; text-align: center; margin: 20px 0; color: var(--text-muted); font-size: 11px; text-transform: uppercase; letter-spacing: 0.1em;">
                <span style="flex: 1; border-bottom: 1px solid var(--glass-border);"></span>
                <span style="padding: 0 12px;">OR</span>
                <span style="flex: 1; border-bottom: 1px solid var(--glass-border);"></span>
              </div>

              <!-- Google Sign In -->
              <button class="btn-secondary" id="auth-google-btn" ${this.isLoading ? 'disabled' : ''} style="width: 100%; padding: 12px;">
                <svg width="18" height="18" viewBox="0 0 24 24">
                  <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
                  <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
                  <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"/>
                  <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"/>
                </svg>
                Continue with Google
              </button>
            </div>
          </section>

          <!-- 3 Feature Highlight Cards -->
          <section style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 24px; margin-bottom: 80px;">
            <div class="fintech-card">
              <div class="tx-icon-box" style="width: 44px; height: 44px; background: rgba(16, 185, 129, 0.12); color: var(--primary); margin-bottom: 16px;">
                <span class="material-icons">cloud_sync</span>
              </div>
              <h3 style="font-size: 18px; margin-bottom: 8px;">Real-Time Sync Engine</h3>
              <p style="font-size: 14px; line-height: 1.6;">Synchronize balances, transactions, and categories instantly across web and Flutter mobile applications.</p>
            </div>

            <div class="fintech-card">
              <div class="tx-icon-box" style="width: 44px; height: 44px; background: rgba(56, 189, 248, 0.12); color: var(--secondary); margin-bottom: 16px;">
                <span class="material-icons">auto_graph</span>
              </div>
              <h3 style="font-size: 18px; margin-bottom: 8px;">Predictive Cash Flow</h3>
              <p style="font-size: 14px; line-height: 1.6;">Automated daily burn-rate calculations and month-end trajectory forecasts keep you ahead of budget overruns.</p>
            </div>

            <div class="fintech-card">
              <div class="tx-icon-box" style="width: 44px; height: 44px; background: rgba(99, 102, 241, 0.12); color: var(--indigo); margin-bottom: 16px;">
                <span class="material-icons">shield</span>
              </div>
              <h3 style="font-size: 18px; margin-bottom: 8px;">Isolated & Secure</h3>
              <p style="font-size: 14px; line-height: 1.6;">Cloud Firestore database with isolated user access control. Offline-first local database support when disconnected.</p>
            </div>
          </section>
        </main>

        <!-- Footer -->
        <footer class="site-footer">
          <div class="site-container">
            <div class="footer-inner">
              <div>Quantro Finance Platform • Cloud Synchronized Wealth Intelligence</div>
              <div>End-to-End Encrypted • Powered by Firebase & Modern Web Standards</div>
            </div>
          </div>
        </footer>
      </div>
    `;
  },

  bindEvents() {
    // Tab toggles
    document.getElementById('auth-tab-signin')?.addEventListener('click', () => {
      this.isSignUp = false;
      this.errorMessage = null;
      StateManager.notify();
    });

    document.getElementById('auth-tab-signup')?.addEventListener('click', () => {
      this.isSignUp = true;
      this.errorMessage = null;
      StateManager.notify();
    });

    // Inputs
    document.getElementById('auth-email-input')?.addEventListener('input', (e) => {
      this.emailInput = e.target.value;
    });

    const passwordInputElement = document.getElementById('auth-password-input');
    if (passwordInputElement) {
      passwordInputElement.addEventListener('input', (e) => {
        this.passwordInput = e.target.value;
      });
      passwordInputElement.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') document.getElementById('auth-submit-btn')?.click();
      });
    }

    // Submit Auth
    document.getElementById('auth-submit-btn')?.addEventListener('click', async () => {
      const emailValue = (this.emailInput || '').trim();
      const enteredPassword = this.passwordInput || '';

      if (!emailValue || emailValue.indexOf('@') === -1) {
        this.errorMessage = 'Please enter a valid email address.';
        StateManager.notify();
        return;
      }
      if (!enteredPassword || enteredPassword.length < 6) {
        this.errorMessage = 'Password must be at least 6 characters.';
        StateManager.notify();
        return;
      }

      this.isLoading = true;
      this.errorMessage = null;
      StateManager.notify();

      try {
        if (this.isSignUp) {
          const res = await AuthService.signUpWithEmail(emailValue, enteredPassword);
          DbService.startSync(res.user.uid);
          await DbService.syncGuestDataToCloud(res.user.uid);
        } else {
          const res = await AuthService.signInWithEmail(emailValue, enteredPassword);
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

    // Google Sign In
    document.getElementById('auth-google-btn')?.addEventListener('click', async () => {
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

    // Offline Guest Demo Mode
    document.getElementById('landing-guest-btn')?.addEventListener('click', () => {
      StateManager.enableGuestMode();
    });
  }
};
