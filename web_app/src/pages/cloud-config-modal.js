/* Cloud Configuration Modal: Allows users to Bring Their Own Firebase (BYOF) */
import { 
  getCustomFirebaseConfig, 
  saveCustomFirebaseConfig, 
  removeCustomFirebaseConfig, 
  getActiveProjectId, 
  isUsingCustomFirebase 
} from '../firebase-config.js';
import { StateManager } from '../state.js';
import { AuthService } from '../auth.js';

export const CloudConfigModal = {
  activeTab: 'paste', // 'paste' | 'manual'
  errorMessage: null,
  successMessage: null,

  parseSnippet(rawText) {
    if (!rawText || !rawText.trim()) return null;
    const text = rawText.trim();

    // 1. Try JSON directly
    try {
      const parsed = JSON.parse(text);
      if (parsed && typeof parsed === 'object') return parsed;
    } catch (_) {}

    // 2. Extract keys using regex from JS config snippet
    const extract = (key) => {
      const regex = new RegExp(`${key}\\s*:\\s*["']([^"']+)["']`, 'i');
      const match = text.match(regex);
      return match ? match[1] : '';
    };

    const config = {
      apiKey: extract('apiKey'),
      authDomain: extract('authDomain'),
      projectId: extract('projectId'),
      storageBucket: extract('storageBucket'),
      messagingSenderId: extract('messagingSenderId'),
      appId: extract('appId'),
      measurementId: extract('measurementId')
    };

    if (config.apiKey && config.projectId && config.appId) {
      return config;
    }

    return null;
  },

  show() {
    this.errorMessage = null;
    this.successMessage = null;

    let modalRoot = document.getElementById('cloud-config-modal-root');
    if (!modalRoot) {
      modalRoot = document.createElement('div');
      modalRoot.id = 'cloud-config-modal-root';
      modalRoot.className = 'modal-overlay';
      document.body.appendChild(modalRoot);
    }

    modalRoot.innerHTML = this.render();
    modalRoot.classList.add('active');
    this.bindEvents(modalRoot);
  },

  close() {
    const modalRoot = document.getElementById('cloud-config-modal-root');
    if (modalRoot) {
      modalRoot.classList.remove('active');
      modalRoot.innerHTML = '';
    }
  },

  render() {
    const isCustom = isUsingCustomFirebase();
    const activeProject = getActiveProjectId();
    const customConfig = getCustomFirebaseConfig();

    return `
      <div class="modern-modal-dialog animate-scale-up" style="max-width: 560px;" id="cloud-config-dialog">
        <div class="modal-header">
          <div class="modal-title">
            <span class="material-icons" style="color: var(--primary);">cloud</span>
            <span>Cloud Sync Configuration</span>
          </div>
          <button class="modal-close-btn" id="cloud-config-close-btn" aria-label="Close">
            <span class="material-icons" style="font-size: 20px; line-height: 1;">close</span>
          </button>
        </div>

        <div style="display: flex; flex-direction: column; gap: 18px; max-height: 70vh; overflow-y: auto; padding-right: 4px;">
          
          <!-- Current Status Banner -->
          <div style="background: var(--bg-surface-subtle); border: 1px solid var(--glass-border); border-radius: var(--radius-md); padding: 14px 16px;">
            <div style="display: flex; justify-content: space-between; align-items: center;">
              <div>
                <div style="font-size: 11px; text-transform: uppercase; letter-spacing: 0.5px; color: var(--text-muted); font-weight: 700;">Current Cloud Target</div>
                <div style="font-size: 14px; font-weight: 700; color: var(--text-primary); margin-top: 2px;">
                  ${isCustom ? `Custom Firebase: ${activeProject}` : 'App Default Cloud or Local Storage'}
                </div>
              </div>
              <span class="kpi-badge ${isCustom ? 'positive' : 'neutral'}" style="font-size: 11px;">
                ${isCustom ? 'Personal BYOF' : 'Standard'}
              </span>
            </div>
          </div>

          <!-- Alert messages -->
          ${this.errorMessage ? `
            <div style="background: var(--error-bg); border: 1px solid rgba(244, 63, 94, 0.3); color: #FDA4AF; padding: 10px 14px; border-radius: var(--radius-md); font-size: 12.5px; display: flex; align-items: center; gap: 8px;">
              <span class="material-icons" style="font-size: 16px; color: var(--error);">error_outline</span>
              <span>${this.errorMessage}</span>
            </div>
          ` : ''}

          ${this.successMessage ? `
            <div style="background: var(--success-bg); border: 1px solid rgba(16, 185, 129, 0.3); color: #86EFAC; padding: 10px 14px; border-radius: var(--radius-md); font-size: 12.5px; display: flex; align-items: center; gap: 8px;">
              <span class="material-icons" style="font-size: 16px; color: var(--success);">check_circle</span>
              <span>${this.successMessage}</span>
            </div>
          ` : ''}

          <!-- Info description -->
          <div style="font-size: 12.5px; color: var(--text-secondary); line-height: 1.5;">
            Connect your own Google Firebase project to store financial data inside your personal cloud account. Credentials remain strictly in your browser and are never sent to third-party servers.
          </div>

          <!-- Tab Selection -->
          <div class="auth-segmented-control" style="margin-bottom: 0;">
            <button class="auth-segment-btn ${this.activeTab === 'paste' ? 'active' : ''}" id="cloud-tab-paste">
              <span class="material-icons" style="font-size: 15px;">content_paste</span>
              <span>Paste Firebase Snippet</span>
            </button>
            <button class="auth-segment-btn ${this.activeTab === 'manual' ? 'active' : ''}" id="cloud-tab-manual">
              <span class="material-icons" style="font-size: 15px;">tune</span>
              <span>Manual Input</span>
            </button>
          </div>

          ${this.activeTab === 'paste' ? `
            <div class="form-group" style="margin-bottom: 0;">
              <label class="form-label">Paste Config Snippet or JSON</label>
              <textarea class="form-control" id="cloud-paste-input" rows="7" placeholder='const firebaseConfig = {\n  apiKey: "...",\n  authDomain: "...",\n  projectId: "...",\n  appId: "..."\n};' style="font-family: monospace; font-size: 11.5px; line-height: 1.4; resize: vertical;"></textarea>
              <div style="font-size: 11px; color: var(--text-muted); margin-top: 6px;">
                You can copy this directly from your Google Firebase Console (Project Settings > Web App).
              </div>
            </div>
          ` : `
            <div style="display: flex; flex-direction: column; gap: 12px;">
              <div class="form-group" style="margin-bottom: 0;">
                <label class="form-label">API Key *</label>
                <input type="text" class="form-control" id="cloud-key-input" placeholder="AIzaSy..." value="${customConfig?.apiKey || ''}">
              </div>
              <div class="form-group" style="margin-bottom: 0;">
                <label class="form-label">Project ID *</label>
                <input type="text" class="form-control" id="cloud-project-input" placeholder="my-finance-vault" value="${customConfig?.projectId || ''}">
              </div>
              <div class="form-group" style="margin-bottom: 0;">
                <label class="form-label">App ID *</label>
                <input type="text" class="form-control" id="cloud-appid-input" placeholder="1:123456789:web:abcdef..." value="${customConfig?.appId || ''}">
              </div>
              <div class="form-group" style="margin-bottom: 0;">
                <label class="form-label">Auth Domain (Optional)</label>
                <input type="text" class="form-control" id="cloud-authdomain-input" placeholder="my-finance-vault.firebaseapp.com" value="${customConfig?.authDomain || ''}">
              </div>
            </div>
          `}

          <!-- Actions -->
          <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 10px; padding-top: 14px; border-top: 1px solid var(--glass-border);">
            ${isCustom ? `
              <button class="btn-ghost" id="cloud-reset-btn" style="color: var(--error); padding: 7px 12px; font-size: 12px;">
                <span class="material-icons" style="font-size: 15px;">delete</span>
                <span>Remove Custom Cloud</span>
              </button>
            ` : '<div></div>'}
            
            <div style="display: flex; gap: 10px;">
              <button class="btn-secondary" id="cloud-cancel-btn" style="padding: 7px 16px; font-size: 13px;">Cancel</button>
              <button class="btn-primary" id="cloud-save-btn" style="padding: 7px 18px; font-size: 13px;">Save & Connect</button>
            </div>
          </div>

        </div>
      </div>
    `;
  },

  bindEvents(modalRoot) {
    // Close modal
    modalRoot.querySelector('#cloud-config-close-btn')?.addEventListener('click', () => this.close());
    modalRoot.querySelector('#cloud-cancel-btn')?.addEventListener('click', () => this.close());
    modalRoot.addEventListener('click', (e) => {
      if (e.target === modalRoot) this.close();
    });

    // Tab switches
    modalRoot.querySelector('#cloud-tab-paste')?.addEventListener('click', () => {
      this.activeTab = 'paste';
      modalRoot.innerHTML = this.render();
      this.bindEvents(modalRoot);
    });

    modalRoot.querySelector('#cloud-tab-manual')?.addEventListener('click', () => {
      this.activeTab = 'manual';
      modalRoot.innerHTML = this.render();
      this.bindEvents(modalRoot);
    });

    // Remove custom cloud
    modalRoot.querySelector('#cloud-reset-btn')?.addEventListener('click', async () => {
      if (confirm('Disconnect custom Firebase and revert to local storage?')) {
        removeCustomFirebaseConfig();
        await AuthService.signOut().catch(() => {});
        StateManager.enableGuestMode();
        window.location.reload();
      }
    });

    // Save custom cloud
    modalRoot.querySelector('#cloud-save-btn')?.addEventListener('click', () => {
      let config = null;

      if (this.activeTab === 'paste') {
        const text = modalRoot.querySelector('#cloud-paste-input')?.value;
        config = this.parseSnippet(text);
        if (!config) {
          this.errorMessage = 'Could not parse Firebase keys from pasted text. Please verify the snippet or use Manual Input.';
          modalRoot.innerHTML = this.render();
          this.bindEvents(modalRoot);
          return;
        }
      } else {
        config = {
          apiKey: modalRoot.querySelector('#cloud-key-input')?.value,
          projectId: modalRoot.querySelector('#cloud-project-input')?.value,
          appId: modalRoot.querySelector('#cloud-appid-input')?.value,
          authDomain: modalRoot.querySelector('#cloud-authdomain-input')?.value
        };
      }

      try {
        saveCustomFirebaseConfig(config);
        this.successMessage = 'Firebase configuration saved. Reloading application...';
        modalRoot.innerHTML = this.render();
        this.bindEvents(modalRoot);
        setTimeout(() => {
          window.location.reload();
        }, 800);
      } catch (err) {
        this.errorMessage = err.message;
        modalRoot.innerHTML = this.render();
        this.bindEvents(modalRoot);
      }
    });
  }
};
