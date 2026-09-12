/* Modern Minimalist Landing & Authentication Module */
import { StateManager } from '../state.js';
import { AuthService } from '../auth.js';
import { DbService } from '../db.js';
import { CloudConfigModal } from './cloud-config-modal.js';
import { SetupGuideModal } from './setup-guide-modal.js';

export const AuthPage = {
  isSignUp: false,
  errorMessage: null,
  successMessage: null,
  isLoading: false,
  emailInput: '',

  render(state) {
    return `
      <div class="site-wrapper animate-fade-in" style="min-height: 100vh;">
        <!-- Ambient lighting mesh -->
        <div class="ambient-glow">
          <div class="ambient-circle-1"></div>
          <div class="ambient-circle-2"></div>
        </div>

        <!-- Minimal Sticky Header -->
        <header class="min-header">
          <div class="min-header-inner">
            <a href="/" class="min-brand-link">
              <div class="min-brand-badge">Q</div>
              <div class="min-brand-title">Quantro</div>
              <span class="min-brand-tag">PRO</span>
            </a>

            <div class="min-header-actions">
              <button class="min-nav-btn" id="nav-signin-btn">
                <span>Sign In</span>
              </button>
              <button class="min-nav-btn min-nav-btn-solid" id="landing-demo-top-btn">
                <span class="material-icons" style="font-size: 16px;">play_circle</span>
                <span>Live Demo</span>
              </button>
            </div>
          </div>
        </header>

        <!-- Main Content -->
        <main style="flex: 1;">
          <!-- Centered Editorial Hero -->
          <section class="min-hero-section">
            <div class="min-eyebrow">
              <span class="min-eyebrow-dot"></span>
              <span>QUANTRO // SOVEREIGN CAPITAL INTELLIGENCE</span>
            </div>

            <h1 class="min-hero-h1">
              Own your financial truth.
            </h1>

            <p class="min-hero-p">
              Local-first wealth intelligence with zero telemetry.
            </p>

            <div class="min-cta-wrap">
              <button class="min-cta-btn min-cta-primary" id="hero-demo-btn">
                <span class="material-icons" style="font-size: 18px;">play_circle</span>
                <span>Launch Live Demo</span>
              </button>
              <button class="min-cta-btn min-cta-secondary" id="hero-signin-btn">
                <span class="material-icons" style="font-size: 18px;">login</span>
                <span>Sign In to Sync</span>
              </button>
            </div>
          </section>

          <!-- Spotlight Telemetry Console Frame (The Visual Hook) -->
          <section class="min-preview-wrap">
            <div class="min-preview-box">
              <div class="min-preview-nav">
                <div class="min-dots">
                  <span class="min-dot"></span>
                  <span class="min-dot"></span>
                  <span class="min-dot"></span>
                </div>
                <div class="min-preview-chip">
                  <span>DRIFT SQLITE // AES-256 CLIENT ENCRYPTED</span>
                </div>
                <div class="min-pulse-indicator" style="font-size: 10px; font-family: var(--font-mono); color: #4ADE80;">
                  <span class="min-eyebrow-dot" style="width: 5px; height: 5px;"></span>
                  <span>ACTIVE</span>
                </div>
              </div>

              <div class="min-preview-body">
                <div class="min-metrics-row">
                  <div class="min-metric-col">
                    <div class="min-metric-label">Net Reserve</div>
                    <div class="min-metric-number">₹2,48,500</div>
                    <div class="min-metric-meta">
                      <span class="material-icons" style="font-size: 13px; color: var(--text-primary);">trending_up</span>
                      <span style="color: var(--text-primary);">+14.2% MoM</span>
                    </div>
                  </div>

                  <div class="min-metric-col">
                    <div class="min-metric-label">Daily Burn Velocity</div>
                    <div class="min-metric-number">₹1,180</div>
                    <div class="min-metric-meta">
                      <span class="material-icons" style="font-size: 13px;">check_circle</span>
                      <span>Within Target</span>
                    </div>
                  </div>

                  <div class="min-metric-col">
                    <div class="min-metric-label">Projected Runway</div>
                    <div class="min-metric-number">18.4 <span style="font-size: 14px; font-weight: 500; color: var(--text-muted);">Mos</span></div>
                    <div class="min-metric-meta">
                      <span class="material-icons" style="font-size: 13px;">savings</span>
                      <span>SIP Capital Protected</span>
                    </div>
                  </div>
                </div>

                <!-- Continuous Liquidity Sparkline -->
                <div class="min-chart-wrap">
                  <div class="min-chart-meta">
                    <span>LIQUIDITY TRAJECTORY (30-DAY COMPOSITE)</span>
                    <span>DETERMINISTIC FORECAST: ₹2,84,200</span>
                  </div>
                  <svg class="min-chart-svg" viewBox="0 0 760 70" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <defs>
                      <linearGradient id="minCurveGrad" x1="0" y1="0" x2="0" y2="70" gradientUnits="userSpaceOnUse">
                        <stop stop-color="#FFFFFF" stop-opacity="0.18"/>
                        <stop offset="1" stop-color="#FFFFFF" stop-opacity="0.0"/>
                      </linearGradient>
                    </defs>
                    <path d="M0 58 Q 120 54, 220 42 T 440 28 T 620 16 T 760 8 L 760 70 L 0 70 Z" fill="url(#minCurveGrad)"/>
                    <path d="M0 58 Q 120 54, 220 42 T 440 28 T 620 16 T 760 8" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round"/>
                    <circle cx="760" cy="8" r="4" fill="#FFFFFF" />
                  </svg>
                </div>
              </div>

              <div class="min-preview-foot">
                <span>Flutter Mobile + Web SPA In Sync</span>
                <span>Zero External Telemetry</span>
              </div>
            </div>
          </section>

          <!-- Three Quiet Capability Pillars -->
          <section class="min-pillars-wrap">
            <div class="min-pillars-grid">
              <div class="min-pillar">
                <div class="min-pillar-num">01 / SOVEREIGN PRIVACY</div>
                <h3 class="min-pillar-h3">Local-First Storage</h3>
                <p class="min-pillar-p">
                  Stored directly on your local hardware via encrypted SQLite. Zero mandatory cloud accounts, zero tracking, zero vendor lock-in.
                </p>
              </div>

              <div class="min-pillar">
                <div class="min-pillar-num">02 / CAPITAL METRICS</div>
                <h3 class="min-pillar-h3">Deterministic Runway</h3>
                <p class="min-pillar-p">
                  Automated burn velocity analytics isolate SIP investments from daily lifestyle spending to deliver predictable survival horizons.
                </p>
              </div>

              <div class="min-pillar">
                <div class="min-pillar-num">03 / CONTINUOUS SYNC</div>
                <h3 class="min-pillar-h3">Bi-Directional Engine</h3>
                <p class="min-pillar-p">
                  Seamless background reconciliation between Flutter mobile and web desktop with conflict-free offline drift caching.
                </p>
              </div>
            </div>
          </section>

          <!-- Centered Access Terminal -->
          <section class="min-auth-wrap" id="auth-access-gateway">
            <div class="min-auth-head">
              <h2 class="min-auth-title">Access Quantro</h2>
              <p class="min-auth-subtitle">Sign in to sync across devices or start in local mode.</p>
            </div>

            <div class="min-auth-card">
              <!-- Segmented Switcher -->
              <div class="auth-segmented-control">
                <button class="auth-segment-btn ${!this.isSignUp ? 'active' : ''}" id="auth-tab-signin">
                  <span class="material-icons" style="font-size: 16px;">login</span>
                  <span>Sign In</span>
                </button>
                <button class="auth-segment-btn ${this.isSignUp ? 'active' : ''}" id="auth-tab-signup">
                  <span class="material-icons" style="font-size: 16px;">person_add</span>
                  <span>Create Account</span>
                </button>
              </div>

              <!-- Alerts -->
              ${this.errorMessage ? `
                <div class="auth-error-banner">
                  <span class="material-icons" style="font-size: 18px; color: var(--error);">error_outline</span>
                  <span>${this.errorMessage}</span>
                </div>
              ` : ''}

              ${this.successMessage ? `
                <div class="auth-success-banner">
                  <span class="material-icons" style="font-size: 18px; color: var(--success);">check_circle</span>
                  <span>${this.successMessage}</span>
                </div>
              ` : ''}

              <!-- Form Inputs -->
              <div class="form-group" style="margin-bottom: 16px;">
                <label class="form-label" style="text-align: left; font-size: 12px;">Email Address</label>
                <input type="email" class="form-control" id="auth-email-input" placeholder="you@example.com" value="${this.emailInput}" autocomplete="email">
              </div>

              <div class="form-group" style="margin-bottom: 20px;">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
                  <label class="form-label" style="margin: 0; font-size: 12px;">Password</label>
                  ${!this.isSignUp ? `
                    <a href="#" id="auth-forgot-pwd" style="font-size: 11.5px; color: var(--text-secondary); text-decoration: underline;">Forgot?</a>
                  ` : ''}
                </div>
                <input type="password" class="form-control" id="auth-password-input" placeholder="••••••••" autocomplete="${this.isSignUp ? 'new-password' : 'current-password'}">
              </div>

              <!-- Submit Button -->
              <button class="btn-auth-submit" id="auth-submit-btn" ${this.isLoading ? 'disabled' : ''}>
                ${this.isLoading ? `
                  <span class="material-icons animate-spin" style="font-size: 18px;">sync</span>
                  <span>Authenticating...</span>
                ` : (this.isSignUp ? `
                  <span class="material-icons" style="font-size: 18px;">arrow_forward</span>
                  <span>Create Cloud Account</span>
                ` : `
                  <span class="material-icons" style="font-size: 18px;">arrow_forward</span>
                  <span>Sign In to Sync</span>
                `)}
              </button>

              <!-- Divider -->
              <div class="auth-divider">
                <span>OR</span>
              </div>

              <!-- Google Sign In -->
              <button class="btn-google-auth" id="auth-google-btn" ${this.isLoading ? 'disabled' : ''}>
                <svg width="18" height="18" viewBox="0 0 24 24">
                  <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
                  <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
                  <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"/>
                  <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"/>
                </svg>
                <span>Continue with Google</span>
              </button>

              <!-- Instant Demo Mode -->
              <button class="btn-demo-action" id="auth-demo-btn">
                <span class="material-icons" style="font-size: 18px; color: var(--primary);">bolt</span>
                <span>Launch Live Demo (Instant Test-Drive)</span>
              </button>

              <!-- Auxiliary Links -->
              <div class="auth-alt-actions">
                <button class="btn-ghost" id="auth-guest-link" style="font-size: 13px; color: var(--text-primary); font-weight: 600; width: 100%; justify-content: center; padding: 6px 12px;">
                  <span class="material-icons" style="font-size: 16px; color: var(--text-secondary);">shield</span>
                  <span>Enter Private Local Mode (No Cloud)</span>
                </button>
                
                <div class="auth-config-links">
                  <button class="btn-ghost" id="auth-cloud-config-link" style="font-size: 12px; color: var(--text-muted); padding: 4px 8px;">
                    <span class="material-icons" style="font-size: 14px;">tune</span>
                    <span>Custom Firebase</span>
                  </button>
                  <span>•</span>
                  <button class="btn-ghost" id="auth-setup-guide-link" style="font-size: 12px; color: var(--text-muted); padding: 4px 8px;">
                    <span class="material-icons" style="font-size: 14px;">menu_book</span>
                    <span>Self-Hosting Guide</span>
                  </button>
                </div>
              </div>
            </div>
          </section>
        </main>

        <!-- Architectural Double-Bezel Footer -->
        <footer class="site-footer">
          <div class="site-container">
            <div class="footer-card">
              
              <!-- Upper Architectural Grid -->
              <div class="footer-grid">
                
                <!-- Left: Identity, Mission & Telemetry Bezel -->
                <div class="footer-brand-col">
                  <div class="footer-brand-header">
                    <div class="footer-brand-badge">
                      <span class="footer-brand-glyph">Q</span>
                    </div>
                    <div>
                      <div class="footer-brand-name">Quantro</div>
                      <div class="footer-brand-tagline">Financial Architecture</div>
                    </div>
                  </div>

                  <p class="footer-brand-description">
                    Private, local-first financial matrix. Engineered with client-side SQLite storage, deterministic wealth forecasting, and zero telemetry.
                  </p>

                  <!-- Double-Bezel Telemetry Capsule -->
                  <div class="footer-engine-bezel">
                    <div class="footer-engine-core">
                      <div class="footer-engine-status">
                        <span class="footer-engine-dot"></span>
                        <span class="footer-engine-label">Engine: Drift SQLite (Active)</span>
                      </div>
                      <div class="footer-engine-metrics">
                        <span class="footer-engine-tag">AES-256</span>
                        <span class="footer-engine-tag">Zero Telemetry</span>
                        <span class="footer-engine-tag">Offline First</span>
                      </div>
                    </div>
                  </div>

                  <!-- Quick Action Pills -->
                  <div class="footer-actions-row">
                    <a href="https://github.com/suraj-yadav0/money_manager/releases/download/v1.0.1/quantro-v1.0.1.apk" target="_blank" rel="noopener noreferrer" class="footer-action-btn">
                      <span class="material-icons" style="font-size: 15px;">android</span>
                      <span>Android App</span>
                      <span class="footer-action-arrow">↗</span>
                    </a>
                    <button type="button" class="footer-action-btn footer-action-secondary" id="footer-setup-guide-btn">
                      <span class="material-icons" style="font-size: 15px;">dns</span>
                      <span>Self-Host</span>
                    </button>
                    <a href="https://github.com/suraj-yadav0/money_manager" target="_blank" rel="noopener noreferrer" class="footer-icon-pill" title="GitHub Repository">
                      <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z"/></svg>
                    </a>
                  </div>
                </div>

                <!-- Right: Curated 3-Column Navigation -->
                <div class="footer-nav-grid">
                  
                  <div class="footer-col">
                    <div class="footer-col-title">PLATFORM & ACCESS</div>
                    <div class="footer-links">
                      <button class="footer-link footer-link-accent" id="footer-demo-link">Launch Live Demo</button>
                      <button class="footer-link" id="footer-guest-link">Private Local Mode</button>
                      <button class="footer-link" id="footer-signin-link">Sign In to Sync</button>
                      <button class="footer-link" id="footer-cloud-link">Custom Firebase Config</button>
                    </div>
                  </div>

                  <div class="footer-col">
                    <div class="footer-col-title">ARCHITECTURE</div>
                    <div class="footer-links">
                      <span class="footer-link-static">Local Drift SQLite</span>
                      <span class="footer-link-static">Deterministic Runway</span>
                      <button class="footer-link footer-link-accent" id="footer-setup-guide-link">Self-Hosting Guide</button>
                      <a href="https://github.com/suraj-yadav0/money_manager#readme" target="_blank" rel="noopener noreferrer" class="footer-link">Architecture Specs</a>
                      <span class="footer-link-static">Zero External Calls</span>
                    </div>
                  </div>

                  <div class="footer-col">
                    <div class="footer-col-title">ECOSYSTEM</div>
                    <div class="footer-links">
                      <a href="https://github.com/suraj-yadav0/money_manager/releases/tag/v1.0.1" target="_blank" rel="noopener noreferrer" class="footer-link">Release v1.0.1</a>
                      <a href="https://github.com/suraj-yadav0/money_manager/releases/download/v1.0.1/quantro-v1.0.1.apk" target="_blank" rel="noopener noreferrer" class="footer-link">Android APK</a>
                      <a href="https://github.com/suraj-yadav0/money_manager" target="_blank" rel="noopener noreferrer" class="footer-link">GitHub Source</a>
                      <a href="https://github.com/suraj-yadav0/money_manager/blob/main/LICENSE" target="_blank" rel="noopener noreferrer" class="footer-link">MIT License</a>
                    </div>
                  </div>

                </div>

              </div>

              <!-- Architectural Metallic Gradient Display Wordmark -->
              <div class="footer-display-container">
                <div class="footer-display-wrap">
                  <span class="footer-display-wordmark">QUANTRO</span>
                  <span class="footer-display-registered">®</span>
                </div>
              </div>

              <!-- Lower Sub-Bar: Copyright, Security & Back-to-Top -->
              <div class="footer-subbar">
                <div class="footer-copyright">
                  © 2026 Quantro Finance. All ledger data resides strictly on your local hardware.
                </div>
                
                <div class="footer-subbar-right">
                  <div class="footer-security-pill">
                    <span class="material-icons" style="font-size: 13px;">shield</span>
                    <span>Cryptographic Privacy Guarantee</span>
                  </div>
                  
                  <button type="button" class="footer-scroll-top-btn" id="footer-back-to-top" title="Back to top">
                    <span>Top</span>
                    <span class="material-icons" style="font-size: 13px;">arrow_upward</span>
                  </button>
                </div>
              </div>

            </div>
          </div>
        </footer>
      </div>
    `;
  },

  bindEvents() {
    // Segmented tab toggles
    document.getElementById('auth-tab-signin')?.addEventListener('click', () => {
      this.isSignUp = false;
      this.errorMessage = null;
      this.successMessage = null;
      StateManager.notify();
    });

    document.getElementById('auth-tab-signup')?.addEventListener('click', () => {
      this.isSignUp = true;
      this.errorMessage = null;
      this.successMessage = null;
      StateManager.notify();
    });

    // Form inputs
    document.getElementById('auth-email-input')?.addEventListener('input', (e) => {
      this.emailInput = e.target.value;
    });

    document.getElementById('auth-password-input')?.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') document.getElementById('auth-submit-btn')?.click();
    });

    // Forgot Password
    document.getElementById('auth-forgot-pwd')?.addEventListener('click', async (e) => {
      e.preventDefault();
      const emailField = document.getElementById('auth-email-input');
      const emailVal = emailField ? emailField.value.trim() : this.emailInput.trim();

      if (!emailVal || emailVal.indexOf('@') === -1) {
        this.errorMessage = 'Please enter your email address in the field above to reset password.';
        this.successMessage = null;
        StateManager.notify();
        return;
      }

      try {
        await AuthService.resetPassword(emailVal);
        this.successMessage = `Password reset instructions sent to ${emailVal}.`;
        this.errorMessage = null;
        StateManager.notify();
      } catch (err) {
        this.errorMessage = err.message || 'Could not send password reset email.';
        this.successMessage = null;
        StateManager.notify();
      }
    });

    // Submit Auth
    document.getElementById('auth-submit-btn')?.addEventListener('click', async () => {
      const emailField = document.getElementById('auth-email-input');
      const passField = document.getElementById('auth-password-input');
      
      const emailVal = emailField ? emailField.value.trim() : '';
      const passVal = passField ? passField.value : '';

      if (!emailVal || emailVal.indexOf('@') === -1) {
        this.errorMessage = 'Please enter a valid email address.';
        this.successMessage = null;
        StateManager.notify();
        return;
      }
      if (!passVal || passVal.length < 6) {
        this.errorMessage = 'Password must be at least 6 characters.';
        this.successMessage = null;
        StateManager.notify();
        return;
      }

      this.isLoading = true;
      this.errorMessage = null;
      this.successMessage = null;
      StateManager.notify();

      try {
        if (this.isSignUp) {
          const res = await AuthService.signUpWithEmail(emailVal, passVal);
          // Only migrate guest data if genuinely in local guest mode and not demo
          if (StateManager.state.isGuestMode && !StateManager.state.isDemoMode) {
            await DbService.syncGuestDataToCloud(res.user.uid);
          } else {
            StateManager.clearGuestLocalStorage();
          }
          DbService.startSync(res.user.uid);
        } else {
          const res = await AuthService.signInWithEmail(emailVal, passVal);
          // Ensure local guest/demo data never pollutes an existing account
          StateManager.clearGuestLocalStorage();
          DbService.startSync(res.user.uid);
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
      this.successMessage = null;
      StateManager.notify();

      try {
        const user = await AuthService.signInWithGoogle();
        if (user) {
          // Ensure local guest/demo data never pollutes an existing account
          StateManager.clearGuestLocalStorage();
          DbService.startSync(user.uid);
        }
        this.isLoading = false;
      } catch (err) {
        this.errorMessage = err.message || 'Google authentication failed.';
        this.isLoading = false;
        StateManager.notify();
      }
    });

    // Instant Live Demo Mode
    const launchDemoMode = () => {
      window.location.search = '?demo=true';
    };
    document.getElementById('landing-demo-top-btn')?.addEventListener('click', launchDemoMode);
    document.getElementById('hero-demo-btn')?.addEventListener('click', launchDemoMode);
    document.getElementById('auth-demo-btn')?.addEventListener('click', launchDemoMode);
    document.getElementById('footer-demo-link')?.addEventListener('click', launchDemoMode);

    // Private Local Offline Mode
    const enableLocalMode = () => {
      StateManager.enableGuestMode();
    };
    document.getElementById('auth-guest-link')?.addEventListener('click', enableLocalMode);
    document.getElementById('footer-guest-link')?.addEventListener('click', enableLocalMode);

    // Smooth scroll to Sign In Gateway
    const scrollToAccess = () => {
      const target = document.getElementById('auth-access-gateway');
      if (target) {
        target.scrollIntoView({ behavior: 'smooth' });
        setTimeout(() => {
          document.getElementById('auth-email-input')?.focus();
        }, 400);
      }
    };
    document.getElementById('nav-signin-btn')?.addEventListener('click', scrollToAccess);
    document.getElementById('hero-signin-btn')?.addEventListener('click', scrollToAccess);
    document.getElementById('footer-signin-link')?.addEventListener('click', scrollToAccess);

    // Modal Triggers
    const openCloudConfig = () => {
      CloudConfigModal.show();
    };
    document.getElementById('auth-cloud-config-link')?.addEventListener('click', openCloudConfig);
    document.getElementById('footer-cloud-link')?.addEventListener('click', openCloudConfig);

    const openSetupGuide = () => {
      SetupGuideModal.show();
    };
    document.getElementById('auth-setup-guide-link')?.addEventListener('click', openSetupGuide);
    document.getElementById('footer-setup-guide-link')?.addEventListener('click', openSetupGuide);
    document.getElementById('footer-setup-guide-btn')?.addEventListener('click', openSetupGuide);

    // Back to top
    document.getElementById('footer-back-to-top')?.addEventListener('click', () => {
      window.scrollTo({ top: 0, behavior: 'smooth' });
    });
  }
};
