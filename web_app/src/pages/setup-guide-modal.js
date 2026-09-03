/* In-App Setup & Self-Hosting Guide Modal */

export const SetupGuideModal = {
  activeTab: 'hosting', // 'hosting' | 'byof' | 'backup' | 'security'

  show(defaultTab = 'hosting') {
    this.activeTab = defaultTab;
    let modalRoot = document.getElementById('setup-guide-modal-root');
    if (!modalRoot) {
      modalRoot = document.createElement('div');
      modalRoot.id = 'setup-guide-modal-root';
      modalRoot.className = 'modal-overlay';
      document.body.appendChild(modalRoot);
    }

    modalRoot.innerHTML = this.render();
    modalRoot.classList.add('active');
    this.bindEvents(modalRoot);
  },

  close() {
    const modalRoot = document.getElementById('setup-guide-modal-root');
    if (modalRoot) {
      modalRoot.classList.remove('active');
      modalRoot.innerHTML = '';
    }
  },

  render() {
    return `
      <div class="modern-modal-dialog animate-scale-up" style="max-width: 680px; max-height: 85vh; display: flex; flex-direction: column;">
        <!-- Header -->
        <div class="modal-header">
          <div class="modal-title">
            <span class="material-icons" style="color: var(--primary);">menu_book</span>
            <span>Self-Hosting & Setup Guide</span>
          </div>
          <button class="modal-close-btn" id="guide-close-btn" aria-label="Close">
            <span class="material-icons" style="font-size: 20px; line-height: 1;">close</span>
          </button>
        </div>

        <!-- Navigation Tabs -->
        <div class="auth-segmented-control" style="margin-bottom: 16px;">
          <button class="auth-segment-btn ${this.activeTab === 'hosting' ? 'active' : ''}" data-guide-tab="hosting">
            <span class="material-icons" style="font-size: 15px;">dns</span>
            <span>Local Hosting</span>
          </button>
          <button class="auth-segment-btn ${this.activeTab === 'byof' ? 'active' : ''}" data-guide-tab="byof">
            <span class="material-icons" style="font-size: 15px;">cloud</span>
            <span>Custom Firebase</span>
          </button>
          <button class="auth-segment-btn ${this.activeTab === 'backup' ? 'active' : ''}" data-guide-tab="backup">
            <span class="material-icons" style="font-size: 15px;">save</span>
            <span>Local & Backups</span>
          </button>
          <button class="auth-segment-btn ${this.activeTab === 'security' ? 'active' : ''}" data-guide-tab="security">
            <span class="material-icons" style="font-size: 15px;">security</span>
            <span>LAN & Security</span>
          </button>
        </div>

        <!-- Body Content Area -->
        <div style="flex: 1; overflow-y: auto; padding-right: 6px; display: flex; flex-direction: column; gap: 16px;">
          ${this.renderTabContent()}
        </div>

        <!-- Footer Action -->
        <div style="display: flex; justify-content: flex-end; margin-top: 18px; padding-top: 14px; border-top: 1px solid var(--glass-border);">
          <button class="btn-primary" id="guide-done-btn" style="padding: 7px 20px; font-size: 13px;">Got It</button>
        </div>
      </div>
    `;
  },

  renderTabContent() {
    if (this.activeTab === 'hosting') {
      return `
        <div style="display: flex; flex-direction: column; gap: 14px; font-size: 13px; color: var(--text-secondary); line-height: 1.6;">
          <div style="background: var(--bg-surface-subtle); padding: 14px 16px; border-radius: var(--radius-md); border: 1px solid var(--glass-border);">
            <div style="font-weight: 700; color: var(--text-primary); font-size: 14px; margin-bottom: 4px;">Option A: Docker Production Container (Recommended)</div>
            <div>Single command to build and run an ultra-lightweight Alpine Nginx container on your machine:</div>
            <pre style="background: var(--bg-surface); padding: 10px 12px; border-radius: var(--radius-sm); border: 1px solid var(--glass-border); margin: 8px 0; color: var(--primary); font-family: monospace; font-size: 12px; overflow-x: auto;">docker compose up -d --build</pre>
            <div>Once running, open your browser at <strong style="color: var(--text-primary);">http://localhost:8080</strong> or on any device on your Wi-Fi at <strong style="color: var(--text-primary);">http://&lt;your-local-ip&gt;:8080</strong>.</div>
          </div>

          <div style="background: var(--bg-surface-subtle); padding: 14px 16px; border-radius: var(--radius-md); border: 1px solid var(--glass-border);">
            <div style="font-weight: 700; color: var(--text-primary); font-size: 14px; margin-bottom: 4px;">Option B: Native Node / Vite Host</div>
            <div>Run directly with Node.js without needing Docker:</div>
            <pre style="background: var(--bg-surface); padding: 10px 12px; border-radius: var(--radius-sm); border: 1px solid var(--glass-border); margin: 8px 0; color: var(--primary); font-family: monospace; font-size: 12px; overflow-x: auto;">cd web_app
npm install
npm run build
npm run host</pre>
            <div>Binds to <code style="color: var(--primary);">0.0.0.0:5173</code>, allowing access from your phone or tablet on the same Wi-Fi.</div>
          </div>

          <div style="background: var(--bg-surface-subtle); padding: 12px 14px; border-radius: var(--radius-md); border: 1px solid var(--glass-border);">
            <div style="font-weight: 600; color: var(--text-primary); margin-bottom: 2px;">Finding Your Machine's Local IP</div>
            <div>Run <code style="color: var(--primary);">hostname -I</code> (Linux) or <code style="color: var(--primary);">ipconfig</code> (Windows). Look for an address starting with <code style="color: var(--text-primary);">192.168.x.x</code> or <code style="color: var(--text-primary);">10.x.x.x</code>.</div>
          </div>
        </div>
      `;
    }

    if (this.activeTab === 'byof') {
      return `
        <div style="display: flex; flex-direction: column; gap: 14px; font-size: 13px; color: var(--text-secondary); line-height: 1.6;">
          <div style="background: var(--bg-surface-subtle); padding: 14px 16px; border-radius: var(--radius-md); border: 1px solid var(--glass-border);">
            <div style="font-weight: 700; color: var(--text-primary); font-size: 14px; margin-bottom: 6px;">Why Bring Your Own Firebase?</div>
            <div>If you want real-time cloud sync across your phone and laptop without storing your financial records in someone else's cloud, you can connect your own free Google Firebase project.</div>
          </div>

          <div style="display: flex; flex-direction: column; gap: 10px;">
            <div style="font-weight: 700; color: var(--text-primary); font-size: 13.5px;">Setup Instructions (Takes 2 Minutes):</div>
            <ol style="margin: 0; padding-left: 20px; display: flex; flex-direction: column; gap: 8px;">
              <li>Visit <strong style="color: var(--text-primary);">console.firebase.google.com</strong> and click <strong>Create a project</strong> (free tier).</li>
              <li>Under <strong>Build</strong>, enable <strong>Firestore Database</strong> (Start in test mode or production mode) and <strong>Authentication</strong> (Enable Email/Password and Google).</li>
              <li>Under <strong>Project Settings &gt; General</strong>, scroll down to <strong>Your apps</strong> and click the <strong>&lt;/&gt; Web icon</strong> to register a web app.</li>
              <li>Copy the generated <code style="color: var(--primary);">const firebaseConfig = { ... }</code> snippet.</li>
              <li>In Quantro, open <strong>Settings &gt; Configure Custom Cloud</strong> and paste your snippet. Click <strong>Save &amp; Connect</strong>.</li>
            </ol>
          </div>

          <div style="background: var(--bg-surface-subtle); padding: 10px 14px; border-radius: var(--radius-md); border: 1px solid var(--glass-border);">
            <div style="font-size: 12px; color: var(--text-muted);">
              <strong>Zero-Leak Architecture:</strong> Your API keys and credentials are stored strictly in your device's browser localStorage and are never sent to third parties.
            </div>
          </div>
        </div>
      `;
    }

    if (this.activeTab === 'backup') {
      return `
        <div style="display: flex; flex-direction: column; gap: 14px; font-size: 13px; color: var(--text-secondary); line-height: 1.6;">
          <div style="background: var(--bg-surface-subtle); padding: 14px 16px; border-radius: var(--radius-md); border: 1px solid var(--glass-border);">
            <div style="font-weight: 700; color: var(--text-primary); font-size: 14px; margin-bottom: 4px;">Private Local Mode (Zero Cloud)</div>
            <div>In Private Local Mode, 100% of your financial records (transactions, accounts, goals, assets, and budgets) stay in your local browser storage. No account is required, and zero network calls leave your machine.</div>
          </div>

          <div style="display: flex; flex-direction: column; gap: 10px;">
            <div style="font-weight: 700; color: var(--text-primary); font-size: 13.5px;">Export &amp; Migration:</div>
            <div>Because data is stored in the browser, you can back up or migrate your records at any time:</div>
            <ul style="margin: 0; padding-left: 20px; display: flex; flex-direction: column; gap: 6px;">
              <li><strong>Export:</strong> Go to <em>Settings &gt; Export Complete Backup</em>. Downloads a structured <code style="color: var(--primary);">quantro_backup_YYYY-MM-DD.json</code> file.</li>
              <li><strong>Import:</strong> On your other device, go to <em>Settings &gt; Import Backup from JSON</em> and select your file. All records are restored immediately.</li>
            </ul>
          </div>
        </div>
      `;
    }

    // security
    return `
      <div style="display: flex; flex-direction: column; gap: 14px; font-size: 13px; color: var(--text-secondary); line-height: 1.6;">
        <div style="background: var(--bg-surface-subtle); padding: 14px 16px; border-radius: var(--radius-md); border: 1px solid var(--glass-border);">
          <div style="font-weight: 700; color: var(--text-primary); font-size: 14px; margin-bottom: 4px;">Local Network Firewall</div>
          <div>If other devices on your Wi-Fi cannot open the website, ensure the port is allowed in your host's firewall:</div>
          <pre style="background: var(--bg-surface); padding: 10px 12px; border-radius: var(--radius-sm); border: 1px solid var(--glass-border); margin: 8px 0; color: var(--primary); font-family: monospace; font-size: 12px; overflow-x: auto;">sudo ufw allow 8080/tcp    # For Docker
sudo ufw allow 5173/tcp    # For Node host</pre>
        </div>

        <div style="background: var(--bg-surface-subtle); padding: 14px 16px; border-radius: var(--radius-md); border: 1px solid var(--glass-border);">
          <div style="font-weight: 700; color: var(--text-primary); font-size: 14px; margin-bottom: 4px;">Remote Access Outside Home (Tailscale)</div>
          <div>Never port-forward port 80 or 8080 directly on your home router to the internet without authentication.</div>
          <div style="margin-top: 6px;">Instead, install <strong>Tailscale</strong> (free private mesh VPN) on your host and phone. You will get a private encrypted IP (e.g., <code style="color: var(--primary);">http://100.x.y.z:8080</code>) accessible securely from anywhere in the world.</div>
        </div>
      </div>
    `;
  },

  bindEvents(modalRoot) {
    // Close modal
    modalRoot.querySelector('#guide-close-btn')?.addEventListener('click', () => this.close());
    modalRoot.querySelector('#guide-done-btn')?.addEventListener('click', () => this.close());
    modalRoot.addEventListener('click', (e) => {
      if (e.target === modalRoot) this.close();
    });

    // Tab buttons
    modalRoot.querySelectorAll('[data-guide-tab]').forEach(btn => {
      btn.addEventListener('click', () => {
        this.activeTab = btn.getAttribute('data-guide-tab');
        modalRoot.innerHTML = this.render();
        this.bindEvents(modalRoot);
      });
    });
  }
};
