/* Modern Landing & Authentication Module */
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
                  <span class="brand-tag">PRO</span>
                </div>
              </div>

              <div class="header-actions">
                <button class="btn-secondary" id="landing-demo-top-btn" style="padding: 7px 16px; font-size: 13px; font-weight: 600;">
                  <span class="material-icons" style="font-size: 16px; color: var(--primary);">play_circle</span>
                  <span>Explore Live Demo</span>
                </button>
                <button class="btn-secondary" id="landing-guest-btn" style="padding: 7px 16px; font-size: 13px; font-weight: 600;">
                  <span class="material-icons" style="font-size: 16px; color: var(--text-secondary);">shield</span>
                  <span>Private Local Mode</span>
                </button>
              </div>
            </div>
          </div>
        </header>

        <!-- Main Content -->
        <main class="site-container" style="flex: 1; padding-top: 36px;">
          <!-- Asymmetric Split Hero -->
          <section class="landing-split-layout">
            
            <!-- Left Column: Product Showcase & Narrative -->
            <div class="landing-narrative-col">
              <div class="landing-badge">
                <span class="footer-engine-dot" style="width: 7px; height: 7px; background: #22C55E; border-radius: 50%; box-shadow: 0 0 8px #22C55E;"></span>
                <span>QUANTRO PLATFORM // BI-DIRECTIONAL CLOUD & LOCAL ENGINE</span>
              </div>

              <h1 class="landing-title">
                Unified Capital Intelligence.<br>Built for Modern Wealth.
              </h1>

              <p class="landing-subtitle">
                Private-by-design financial command matrix. Real-time bi-directional synchronization between Flutter mobile and desktop web with deterministic runway forecasts and zero-knowledge local storage.
              </p>

              <!-- Trust Verification Matrix -->
              <div class="landing-trust-matrix">
                <div class="trust-chip">
                  <span class="material-icons">storage</span>
                  <span>Local-First SQLite</span>
                </div>
                <div class="trust-chip">
                  <span class="material-icons">sync</span>
                  <span>Offline Conflict Reconciler</span>
                </div>
                <div class="trust-chip">
                  <span class="material-icons">lock</span>
                  <span>Client-Side AES-256</span>
                </div>
                <div class="trust-chip">
                  <span class="material-icons">no_encryption</span>
                  <span>Zero Telemetry</span>
                </div>
              </div>

              <!-- Live Command Console Mockup Artifact -->
              <div class="landing-mockup-card">
                <div class="mockup-header">
                  <div class="mockup-header-left">
                    <div class="mockup-dot-group">
                      <span class="mockup-window-dot"></span>
                      <span class="mockup-window-dot"></span>
                      <span class="mockup-window-dot"></span>
                    </div>
                    <span class="mockup-title">QUANTRO TELEMETRY CONSOLE // REAL-TIME MONITOR</span>
                  </div>
                  <div class="mockup-status-pill">
                    <span class="footer-engine-dot" style="width: 6px; height: 6px; background: #22C55E; border-radius: 50%;"></span>
                    <span>SYSTEM OPTIMAL</span>
                  </div>
                </div>

                <div class="mockup-body">
                  <div class="mockup-metrics-grid">
                    <div class="mockup-stat-cell">
                      <div class="mockup-stat-label">Net Reserve</div>
                      <div class="mockup-stat-val">₹2,48,500</div>
                      <div class="mockup-stat-delta positive">
                        <span class="material-icons" style="font-size: 13px;">trending_up</span>
                        <span>+14.2% MoM</span>
                      </div>
                    </div>

                    <div class="mockup-stat-cell">
                      <div class="mockup-stat-label">Burn Velocity</div>
                      <div class="mockup-stat-val">₹1,180<span style="font-size: 11px; font-weight: 500; color: var(--text-muted);">/day</span></div>
                      <div class="mockup-stat-delta safe">
                        <span class="material-icons" style="font-size: 13px;">check_circle</span>
                        <span>Within Target</span>
                      </div>
                    </div>

                    <div class="mockup-stat-cell">
                      <div class="mockup-stat-label">Projected Runway</div>
                      <div class="mockup-stat-val">18.4 <span style="font-size: 11px; font-weight: 500; color: var(--text-muted);">Mos</span></div>
                      <div class="mockup-stat-delta neutral">
                        <span class="material-icons" style="font-size: 13px;">savings</span>
                        <span>SIP Protected</span>
                      </div>
                    </div>
                  </div>

                  <!-- Trajectory Sparkline Curve -->
                  <div class="mockup-chart-box">
                    <div class="mockup-chart-header">
                      <span>LIQUIDITY TRAJECTORY (30-DAY COMPOSITE)</span>
                      <span>DETERMINISTIC FORECAST: ₹2,84,200</span>
                    </div>
                    <svg class="mockup-svg" viewBox="0 0 540 80" fill="none" xmlns="http://www.w3.org/2000/svg">
                      <defs>
                        <linearGradient id="curveGradient" x1="0" y1="0" x2="0" y2="80" gradientUnits="userSpaceOnUse">
                          <stop stop-color="#FFFFFF" stop-opacity="0.22"/>
                          <stop offset="1" stop-color="#FFFFFF" stop-opacity="0.0"/>
                        </linearGradient>
                      </defs>
                      <path d="M0 65 Q 90 60, 150 48 T 300 32 T 420 20 T 540 10 L 540 80 L 0 80 Z" fill="url(#curveGradient)"/>
                      <path d="M0 65 Q 90 60, 150 48 T 300 32 T 420 20 T 540 10" stroke="#FFFFFF" stroke-width="2.5" stroke-linecap="round"/>
                      <circle cx="540" cy="10" r="4.5" fill="#FFFFFF" />
                    </svg>
                  </div>

                  <!-- Live Status Ticker -->
                  <div class="mockup-ticker">
                    <div class="ticker-item">
                      <span class="ticker-bullet">•</span>
                      <span>Cloud Firestore: Synchronized</span>
                    </div>
                    <div class="ticker-item">
                      <span class="ticker-bullet">•</span>
                      <span>Mobile Sync: Active</span>
                    </div>
                    <div class="ticker-item">
                      <span class="ticker-bullet">•</span>
                      <span>Zero Leak Protocol</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Right Column: Quantro Access Terminal -->
            <div class="landing-terminal-col" id="auth-terminal-top">
              <div class="landing-auth-card">
                
                <div class="terminal-badge-bar">
                  <span class="terminal-title">Access Terminal</span>
                  <span class="terminal-sec-pill">
                    <span class="material-icons" style="font-size: 13px;">lock</span>
                    <span>256-bit TLS</span>
                  </span>
                </div>

                <!-- Segmented Tab Switcher -->
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

                <!-- Error Alert -->
                ${this.errorMessage ? `
                  <div class="auth-error-banner">
                    <span class="material-icons" style="font-size: 18px; color: var(--error);">error_outline</span>
                    <span>${this.errorMessage}</span>
                  </div>
                ` : ''}

                <!-- Success Alert -->
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
                    <span>Sign In to Quantro</span>
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

                <!-- Frictionless Demo Test-Drive Button -->
                <button class="btn-demo-action" id="auth-demo-btn">
                  <span class="material-icons" style="font-size: 18px; color: var(--primary);">bolt</span>
                  <span>Instant Test-Drive (Live Demo Mode)</span>
                </button>

                <!-- Auxiliary Action Links -->
                <div class="auth-alt-actions">
                  <button class="btn-ghost" id="auth-guest-link" style="font-size: 13px; color: var(--text-primary); font-weight: 600; width: 100%; justify-content: center; padding: 6px 12px;">
                    <span class="material-icons" style="font-size: 16px; color: var(--text-secondary);">shield</span>
                    <span>Enter Private Local Mode (No Cloud Account)</span>
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
            </div>

          </section>

          <!-- 4-Cell Asymmetric Bento Capabilities Grid -->
          <section class="landing-bento-section">
            <div class="bento-section-header">
              <div class="landing-badge">
                <span class="material-icons" style="font-size: 14px;">hub</span>
                <span>ENGINEERING SPECIFICATION</span>
              </div>
              <h2 class="bento-heading">Engineered for Sovereign Financial Autonomy</h2>
            </div>

            <div class="landing-bento-grid">
              <!-- Cell 1: Bi-Directional Cloud Engine (Wide) -->
              <div class="bento-cell">
                <div>
                  <div class="bento-cell-top">
                    <div class="tx-icon-box" style="width: 40px; height: 40px; background: var(--bg-surface-elevated); color: var(--text-primary); border: 1px solid var(--glass-border);">
                      <span class="material-icons" style="font-size: 20px;">sync_alt</span>
                    </div>
                    <span class="terminal-sec-pill">REAL-TIME</span>
                  </div>
                  <h3 class="bento-cell-title">Bi-Directional Cloud Engine</h3>
                  <p class="bento-cell-desc">
                    Continuous background ledger reconciliation across Android Flutter and Web SPA. Instant conflict-free synchronization powered by Firestore security rules and offline drift caching.
                  </p>
                </div>
                <div class="bento-sync-visual">
                  <div class="sync-node">
                    <span class="material-icons" style="font-size: 16px;">phone_android</span>
                    <span>Flutter App</span>
                  </div>
                  <div class="sync-arrow">
                    <span class="material-icons" style="font-size: 16px;">swap_horiz</span>
                  </div>
                  <div class="sync-node">
                    <span class="material-icons" style="font-size: 16px;">laptop_mac</span>
                    <span>Web Platform</span>
                  </div>
                </div>
              </div>

              <!-- Cell 2: Predictive Cash Flow & Runway -->
              <div class="bento-cell">
                <div>
                  <div class="bento-cell-top">
                    <div class="tx-icon-box" style="width: 40px; height: 40px; background: var(--bg-surface-elevated); color: var(--text-primary); border: 1px solid var(--glass-border);">
                      <span class="material-icons" style="font-size: 20px;">auto_graph</span>
                    </div>
                    <span class="terminal-sec-pill">FORECAST</span>
                  </div>
                  <h3 class="bento-cell-title">Predictive Runway Modeling</h3>
                  <p class="bento-cell-desc">
                    Automated daily burn velocity analytics separate one-time capital allocations from recurring operational costs, calculating deterministic month-end survival horizons.
                  </p>
                </div>
              </div>

              <!-- Cell 3: Sovereign Privacy & Local-First Storage -->
              <div class="bento-cell">
                <div>
                  <div class="bento-cell-top">
                    <div class="tx-icon-box" style="width: 40px; height: 40px; background: var(--bg-surface-elevated); color: var(--text-primary); border: 1px solid var(--glass-border);">
                      <span class="material-icons" style="font-size: 20px;">shield</span>
                    </div>
                    <span class="terminal-sec-pill">ZERO-LEAK</span>
                  </div>
                  <h3 class="bento-cell-title">Sovereign Local Storage</h3>
                  <p class="bento-cell-desc">
                    Run entirely offline with zero mandatory accounts or cloud telemetry. Your financial records are stored securely on local SQLite hardware with client-side encryption.
                  </p>
                </div>
              </div>

              <!-- Cell 4: Intelligent Capital Allocation -->
              <div class="bento-cell">
                <div>
                  <div class="bento-cell-top">
                    <div class="tx-icon-box" style="width: 40px; height: 40px; background: var(--bg-surface-elevated); color: var(--text-primary); border: 1px solid var(--glass-border);">
                      <span class="material-icons" style="font-size: 20px;">pie_chart</span>
                    </div>
                    <span class="terminal-sec-pill">50-30-20</span>
                  </div>
                  <h3 class="bento-cell-title">Intelligent Capital Allocation</h3>
                  <p class="bento-cell-desc">
                    Dynamic categorizations classify expenses into Needs, Lifestyle Wants, and Wealth Accumulation SIPs. Automatically visualizes monthly capital efficiency metrics.
                  </p>
                </div>
              </div>
            </div>
          </section>
        </main>

        <!-- High-Craft Architectural Footer -->
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
                    <div class="footer-col-title">ACCESS & MODES</div>
                    <div class="footer-links">
                      <button class="footer-link footer-link-accent" id="footer-demo-link">Explore Live Demo</button>
                      <button class="footer-link" id="footer-guest-link">Private Local Mode</button>
                      <button class="footer-link" id="footer-signin-link">Sign In / Register</button>
                      <button class="footer-link" id="footer-cloud-link">Custom Firebase Config</button>
                    </div>
                  </div>

                  <div class="footer-col">
                    <div class="footer-col-title">ARCHITECTURE</div>
                    <div class="footer-links">
                      <span class="footer-link-static">Local SQLite</span>
                      <span class="footer-link-static">Deterministic Burn</span>
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
    // Tab toggles
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

    // Inputs
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
          DbService.startSync(res.user.uid);
          await DbService.syncGuestDataToCloud(res.user.uid);
        } else {
          const res = await AuthService.signInWithEmail(emailVal, passVal);
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
      this.successMessage = null;
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

    // Instant Live Demo Mode
    const launchDemoMode = () => {
      window.location.search = '?demo=true';
    };
    document.getElementById('landing-demo-top-btn')?.addEventListener('click', launchDemoMode);
    document.getElementById('auth-demo-btn')?.addEventListener('click', launchDemoMode);
    document.getElementById('footer-demo-link')?.addEventListener('click', launchDemoMode);

    // Private Local Offline Mode
    const enableLocalMode = () => {
      StateManager.enableGuestMode();
    };
    document.getElementById('landing-guest-btn')?.addEventListener('click', enableLocalMode);
    document.getElementById('auth-guest-link')?.addEventListener('click', enableLocalMode);
    document.getElementById('footer-guest-link')?.addEventListener('click', enableLocalMode);

    // Modal Triggers
    document.getElementById('auth-cloud-config-link')?.addEventListener('click', () => {
      CloudConfigModal.show();
    });
    document.getElementById('footer-cloud-link')?.addEventListener('click', () => {
      CloudConfigModal.show();
    });

    const openSetupGuide = () => {
      SetupGuideModal.show();
    };
    document.getElementById('auth-setup-guide-link')?.addEventListener('click', openSetupGuide);
    document.getElementById('footer-setup-guide-btn')?.addEventListener('click', openSetupGuide);
    document.getElementById('footer-setup-guide-link')?.addEventListener('click', openSetupGuide);

    // Footer Scroll-to-Top and Sign-In Focus
    document.getElementById('footer-signin-link')?.addEventListener('click', () => {
      document.getElementById('auth-terminal-top')?.scrollIntoView({ behavior: 'smooth' });
      document.getElementById('auth-email-input')?.focus();
    });

    document.getElementById('footer-back-to-top')?.addEventListener('click', () => {
      window.scrollTo({ top: 0, behavior: 'smooth' });
    });
  }
};
