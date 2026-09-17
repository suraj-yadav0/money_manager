/* Client-side Single Page Application router with Modern Website Architecture */
import { StateManager } from './state.js';
import { AuthPage } from './pages/auth.js';
import { OnboardingPage } from './pages/onboarding.js';
import { DashboardPage } from './pages/dashboard.js';
import { BudgetPage } from './pages/budget.js';
import { NetWorthPage } from './pages/net-worth.js';
import { GoalsPage } from './pages/goals.js';
import { SettingsPage } from './pages/settings.js';
import { InsightsPage } from './pages/insights.js';
import { CalendarPage } from './pages/calendar.js';
import { AllTransactionsPage } from './pages/all-transactions.js';
import { SetupGuideModal } from './pages/setup-guide-modal.js';
import { DbService } from './db.js';
import { ColorSchemes, isLightTheme } from './utils/theme.js';

export const Router = {
  targetElement: null,
  activeOverlayPage: null, // 'settings', 'insights', 'calendar', 'all-transactions'

  init(selector) {
    this.targetElement = document.querySelector(selector);
    
    // Subscribe to State Changes to automatically re-render
    StateManager.subscribe((state) => {
      this.render(state);
    });

    // Initial render
    this.render(StateManager.state);
  },

  // Open modal overlay
  openOverlay(pageKey) {
    this.activeOverlayPage = pageKey;
    StateManager.notify();
  },

  closeOverlay() {
    this.activeOverlayPage = null;
    StateManager.notify();
  },

  render(state) {
    if (!this.targetElement) return;

    // 1. If user is authenticated with Firebase:
    if (state.user) {
      this.renderWebsite(state);
      return;
    }

    // 2. If user is in guest mode:
    if (state.isGuestMode) {
      const isOnboarded = state.userSettings && (state.userSettings.is_onboarded === true || state.userSettings.isOnboarded === true);
      if (isOnboarded) {
        this.renderWebsite(state);
        return;
      }
      this.targetElement.innerHTML = OnboardingPage.render(state);
      OnboardingPage.bindEvents();
      return;
    }

    // 3. Unauthenticated landing / auth view
    this.targetElement.innerHTML = AuthPage.render(state);
    AuthPage.bindEvents();
  },

  renderWebsite(state) {
    const navIndex = state.navIndex || 0;

    let contentHtml = '';
    
    if (navIndex === 0) {
      contentHtml = DashboardPage.render(state);
    } else if (navIndex === 1) {
      contentHtml = AllTransactionsPage.render(state);
    } else if (navIndex === 2) {
      contentHtml = BudgetPage.render(state);
    } else if (navIndex === 3) {
      contentHtml = GoalsPage.render(state);
    } else if (navIndex === 4) {
      contentHtml = NetWorthPage.render(state);
    } else if (navIndex === 5) {
      contentHtml = InsightsPage.render(state);
    } else if (navIndex === 6) {
      contentHtml = CalendarPage.render(state);
    } else {
      contentHtml = DashboardPage.render(state);
    }

    // Sync Status badge indicators
    let syncLabel = 'Cloud Synced';
    let syncClass = '';
    if (state.syncStatus === 'syncing') {
      syncLabel = 'Syncing...';
      syncClass = 'syncing';
    } else if (state.syncStatus === 'error') {
      syncLabel = 'Sync Warning';
      syncClass = 'error';
    }

    const html = `
      <div class="site-wrapper animate-fade-in">
        <!-- Ambient lighting mesh -->
        <div class="ambient-glow">
          <div class="ambient-circle-1"></div>
          <div class="ambient-circle-2"></div>
        </div>

        <!-- Top Navigation Header -->
        <header class="site-header">
          <div class="site-container">
            <div class="header-inner">
              <!-- Brand Logo -->
              <div class="brand-link" id="brand-logo-btn">
                <div class="brand-icon">
                  <span class="material-icons">account_balance_wallet</span>
                </div>
                <div class="brand-name">
                  Quantro
                  <span class="brand-tag">PRO</span>
                </div>
              </div>

              <!-- Main Navigation Links -->
              <nav class="header-nav">
                <button class="nav-link-btn ${navIndex === 0 ? 'active' : ''}" data-nav="0">
                  <span class="material-icons">dashboard</span> Overview
                </button>
                <button class="nav-link-btn ${navIndex === 1 ? 'active' : ''}" data-nav="1">
                  <span class="material-icons">receipt_long</span> Ledger
                </button>
                <button class="nav-link-btn ${navIndex === 2 ? 'active' : ''}" data-nav="2">
                  <span class="material-icons">pie_chart</span> Budget
                </button>
                <button class="nav-link-btn ${navIndex === 3 ? 'active' : ''}" data-nav="3">
                  <span class="material-icons">savings</span> Goals
                </button>
                <button class="nav-link-btn ${navIndex === 4 ? 'active' : ''}" data-nav="4">
                  <span class="material-icons">account_balance</span> Net Worth
                </button>
                <button class="nav-link-btn ${navIndex === 5 ? 'active' : ''}" data-nav="5">
                  <span class="material-icons">insights</span> Insights
                </button>
                <button class="nav-link-btn ${navIndex === 6 ? 'active' : ''}" data-nav="6">
                  <span class="material-icons">calendar_month</span> Calendar
                </button>
              </nav>

              <!-- Header Action Controls -->
              <div class="header-actions">
                ${state.user ? `
                  <div class="sync-pill ${syncClass}" id="header-sync-btn" title="Click to trigger full Cloud Sync">
                    <span class="sync-dot"></span>
                    <span>${syncLabel}</span>
                  </div>
                ` : `
                  <div class="sync-pill" id="header-connect-btn" style="border-color: rgba(255,255,255,0.12);" title="Connect Firebase account">
                    <span class="material-icons" style="font-size: 14px; color: var(--text-muted);">cloud_off</span>
                    <span>Guest Mode</span>
                  </div>
                `}

                <div class="theme-dropdown-wrapper">
                  <button class="btn-icon" id="header-palette-btn" title="Choose Color Scheme" aria-label="Choose Color Scheme">
                    <span class="material-icons" style="font-size: 18px;">palette</span>
                  </button>
                  <div class="theme-dropdown-menu" id="header-palette-menu">
                    <div class="theme-dropdown-header">Color Scheme</div>
                    ${ColorSchemes.map(s => `
                      <button type="button" class="theme-dropdown-item ${s.id === state.theme ? 'active' : ''}" data-scheme-id="${s.id}">
                        <span class="theme-dropdown-dot" style="background: ${s.primary};"></span>
                        <span class="theme-dropdown-name">${s.name}</span>
                        <span class="theme-dropdown-badge">${s.badge}</span>
                        ${s.id === state.theme ? '<span class="material-icons theme-dropdown-check">check</span>' : ''}
                      </button>
                    `).join('')}
                  </div>
                </div>

                <button class="btn-icon" id="header-theme-btn" title="Toggle Light / Dark Mode">
                  <span class="material-icons" style="font-size: 18px;">${isLightTheme(state.theme) ? 'dark_mode' : 'light_mode'}</span>
                </button>

                <button class="btn-primary" id="header-add-tx-btn">
                  <span class="material-icons" style="font-size: 18px;">add</span> <span>Record</span>
                </button>

                <button class="btn-icon" id="header-settings-btn" title="Account & Preferences">
                  <span class="material-icons">settings</span>
                </button>
              </div>
            </div>
          </div>
        </header>

        <!-- Tablet / Mobile Sub-Navigation Bar -->
        <div class="mobile-subnav-bar">
          <div class="mobile-subnav-inner">
            <button class="nav-link-btn ${navIndex === 0 ? 'active' : ''}" data-nav="0">
              <span class="material-icons">dashboard</span> Overview
            </button>
            <button class="nav-link-btn ${navIndex === 1 ? 'active' : ''}" data-nav="1">
              <span class="material-icons">receipt_long</span> Ledger
            </button>
            <button class="nav-link-btn ${navIndex === 2 ? 'active' : ''}" data-nav="2">
              <span class="material-icons">pie_chart</span> Budget
            </button>
            <button class="nav-link-btn ${navIndex === 3 ? 'active' : ''}" data-nav="3">
              <span class="material-icons">savings</span> Goals
            </button>
            <button class="nav-link-btn ${navIndex === 4 ? 'active' : ''}" data-nav="4">
              <span class="material-icons">account_balance</span> Net Worth
            </button>
            <button class="nav-link-btn ${navIndex === 5 ? 'active' : ''}" data-nav="5">
              <span class="material-icons">insights</span> Insights
            </button>
            <button class="nav-link-btn ${navIndex === 6 ? 'active' : ''}" data-nav="6">
              <span class="material-icons">calendar_month</span> Calendar
            </button>
          </div>
        </div>

        <!-- Main Content Area -->
        <main class="main-content-section" style="flex: 1;">
          <div class="site-container">
            ${contentHtml}
          </div>
        </main>

        <!-- Footer -->
        <!-- Footer -->
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
                    <div class="footer-col-title">WORKSPACE</div>
                    <div class="footer-links">
                      <button class="footer-link" data-footer-nav="0">Overview</button>
                      <button class="footer-link" data-footer-nav="1">Ledger</button>
                      <button class="footer-link" data-footer-nav="2">Budget</button>
                      <button class="footer-link" data-footer-nav="3">Savings Goals</button>
                      <button class="footer-link" data-footer-nav="4">Net Worth</button>
                      <button class="footer-link" data-footer-nav="5">Intelligence</button>
                      <button class="footer-link" data-footer-nav="6">Calendar</button>
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

      <!-- Global Overlay Container for Modals -->
      <div class="modal-overlay ${this.activeOverlayPage ? 'active' : ''}" id="app-overlay-container">
        <!-- Render Active Overlay Dialog -->
      </div>
    `;

    this.targetElement.innerHTML = html;

    // Bind Page Events
    if (navIndex === 0) DashboardPage.bindEvents(state);
    else if (navIndex === 1) AllTransactionsPage.bindEvents(state);
    else if (navIndex === 2) BudgetPage.bindEvents(state);
    else if (navIndex === 3) GoalsPage.bindEvents(state);
    else if (navIndex === 4) NetWorthPage.bindEvents(state);
    else if (navIndex === 5) InsightsPage.bindEvents(state);
    else if (navIndex === 6) CalendarPage.bindEvents(state);

    // Bind Global Header Navigation Events
    this.bindHeaderEvents(state);

    // Render Overlay if active
    this.renderActiveOverlay(state);
  },

  bindHeaderEvents(state) {
    // Brand click returns to overview
    document.getElementById('brand-logo-btn')?.addEventListener('click', () => {
      StateManager.setState({ navIndex: 0 });
    });

    // Nav Link tabs (Desktop & Mobile/Tablet)
    const navButtons = document.querySelectorAll('.nav-link-btn[data-nav]');
    navButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        const index = parseInt(btn.getAttribute('data-nav'), 10);
        StateManager.setState({ navIndex: index });
      });
    });

    // Cloud Sync trigger in header
    const syncBtn = document.getElementById('header-sync-btn');
    if (syncBtn && state.user) {
      syncBtn.addEventListener('click', async () => {
        try {
          const res = await DbService.syncNow(state.user.uid);
          alert(`Cloud sync complete!\n\nSynced:\n• ${res.count.transactions} Transactions\n• ${res.count.categories} Categories\n• ${res.count.goals} Goals\n• ${res.count.assets} Assets`);
        } catch (e) {
          console.error('Header sync error:', e);
          alert('Sync error: ' + (e.message || 'Unknown network error'));
        }
      });
    }

    // Connect cloud account button for guests
    document.getElementById('header-connect-btn')?.addEventListener('click', () => {
      StateManager.disableGuestMode();
    });

    // Record Transaction quick action button
    document.getElementById('header-add-tx-btn')?.addEventListener('click', () => {
      import('./pages/add-transaction.js').then(({ AddTransactionModal }) => {
        AddTransactionModal.show(null);
      });
    });

    // Theme palette dropdown in header
    const paletteBtn = document.getElementById('header-palette-btn');
    const paletteMenu = document.getElementById('header-palette-menu');
    if (paletteBtn && paletteMenu) {
      paletteBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        paletteMenu.classList.toggle('open');
      });

      paletteMenu.querySelectorAll('[data-scheme-id]').forEach(item => {
        item.addEventListener('click', (e) => {
          e.stopPropagation();
          const schemeId = item.getAttribute('data-scheme-id');
          if (schemeId) {
            StateManager.setTheme(schemeId);
            paletteMenu.classList.remove('open');
          }
        });
      });

      document.addEventListener('click', (e) => {
        if (!paletteMenu.contains(e.target) && e.target !== paletteBtn) {
          paletteMenu.classList.remove('open');
        }
      });
    }

    // Theme toggle button in header
    document.getElementById('header-theme-btn')?.addEventListener('click', () => {
      StateManager.toggleTheme();
    });

    // Settings trigger button
    document.getElementById('header-settings-btn')?.addEventListener('click', () => {
      this.openOverlay('settings');
    });

    // Hosting Guide triggers in footer
    document.getElementById('footer-setup-guide-btn')?.addEventListener('click', () => {
      SetupGuideModal.show();
    });
    document.getElementById('footer-setup-guide-link')?.addEventListener('click', () => {
      SetupGuideModal.show();
    });

    // Back to top trigger in footer
    document.getElementById('footer-back-to-top')?.addEventListener('click', () => {
      window.scrollTo({ top: 0, behavior: 'smooth' });
    });

    // Footer Navigation triggers
    document.querySelectorAll('[data-footer-nav]').forEach(btn => {
      btn.addEventListener('click', () => {
        const targetNav = Number(btn.getAttribute('data-footer-nav'));
        StateManager.setState({ navIndex: targetNav });
        window.scrollTo({ top: 0, behavior: 'smooth' });
      });
    });

    // Mobile sub-nav horizontal wheel scrolling & active tab auto-centering
    const subNav = document.querySelector('.mobile-subnav-bar');
    if (subNav) {
      subNav.addEventListener('wheel', (e) => {
        if (e.deltaY !== 0) {
          e.preventDefault();
          subNav.scrollLeft += e.deltaY;
        }
      }, { passive: false });

      // Auto-center active button in subnav
      const activeNavBtn = subNav.querySelector('.nav-link-btn.active');
      if (activeNavBtn) {
        setTimeout(() => {
          activeNavBtn.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
        }, 50);
      }
    }
  },

  renderActiveOverlay(state) {
    const overlayContainer = document.getElementById('app-overlay-container');
    if (!overlayContainer) return;

    if (!this.activeOverlayPage) {
      overlayContainer.innerHTML = '';
      overlayContainer.classList.remove('active');
      return;
    }

    overlayContainer.classList.add('active');

    if (this.activeOverlayPage === 'settings') {
      overlayContainer.innerHTML = SettingsPage.render(state);
      SettingsPage.bindEvents(state);
    }

    // Close overlay on backdrop click
    overlayContainer.addEventListener('click', (e) => {
      if (e.target === overlayContainer) {
        this.closeOverlay();
      }
    });
  }
};
