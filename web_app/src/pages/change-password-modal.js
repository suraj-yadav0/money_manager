/* Change Password Modal: Allows logged-in users to update their password or send a reset email */
import { AuthService } from '../auth.js';

export const ChangePasswordModal = {
  currentPassword: '',
  newPassword: '',
  confirmPassword: '',
  showPasswords: false,
  isLoading: false,
  isSuccess: false,
  errorMessage: null,
  successMessage: null,

  show() {
    this.currentPassword = '';
    this.newPassword = '';
    this.confirmPassword = '';
    this.showPasswords = false;
    this.isLoading = false;
    this.isSuccess = false;
    this.errorMessage = null;
    this.successMessage = null;

    let modalRoot = document.getElementById('change-password-modal-root');
    if (!modalRoot) {
      modalRoot = document.createElement('div');
      modalRoot.id = 'change-password-modal-root';
      modalRoot.className = 'modal-overlay';
      document.body.appendChild(modalRoot);
    }

    modalRoot.innerHTML = this.render();
    modalRoot.classList.add('active');
    this.bindEvents(modalRoot);

    setTimeout(() => {
      const input = document.getElementById('change-pwd-current-input');
      if (input) input.focus();
    }, 100);
  },

  close() {
    const modalRoot = document.getElementById('change-password-modal-root');
    if (modalRoot) {
      modalRoot.classList.remove('active');
      modalRoot.innerHTML = '';
    }
  },

  render() {
    const user = AuthService.getCurrentUser();
    const isPassword = AuthService.isPasswordUser();
    const email = user ? user.email : '';

    return `
      <div class="modern-modal-dialog animate-scale-up" style="max-width: 500px;" id="change-password-dialog">
        <div class="modal-header">
          <div class="modal-title">
            <span class="material-icons" style="color: var(--primary);">password</span>
            <span>Account Security</span>
          </div>
          <button class="modal-close-btn" id="change-pwd-close-btn" aria-label="Close">
            <span class="material-icons" style="font-size: 20px; line-height: 1;">close</span>
          </button>
        </div>

        <div style="display: flex; flex-direction: column; gap: 16px; padding: 4px 0;">
          ${this.isSuccess ? `
            <div style="text-align: center; padding: 16px 8px;">
              <div style="width: 52px; height: 52px; border-radius: 50%; background: var(--success-bg); display: flex; align-items: center; justify-content: center; margin: 0 auto 16px;">
                <span class="material-icons" style="font-size: 28px; color: var(--success);">check_circle</span>
              </div>
              <h3 style="font-size: 17px; font-weight: 700; color: var(--text-primary); margin-bottom: 8px;">Password Updated</h3>
              <p style="font-size: 13.5px; color: var(--text-secondary); line-height: 1.5; margin-bottom: 24px;">
                ${this.successMessage || 'Your password has been changed successfully.'}
              </p>
              <button class="btn-primary" id="change-pwd-done-btn" style="width: 100%; justify-content: center;">
                <span>Done</span>
              </button>
            </div>
          ` : (isPassword ? `
            <p style="font-size: 13.5px; color: var(--text-secondary); line-height: 1.5; margin: 0;">
              Update the password for <strong style="color: var(--text-primary); font-family: var(--font-mono);">${email}</strong>.
            </p>

            ${this.errorMessage ? `
              <div class="auth-error-banner" style="margin: 0;">
                <span class="material-icons" style="font-size: 18px; color: var(--error);">error_outline</span>
                <span>${this.errorMessage}</span>
              </div>
            ` : ''}

            ${this.successMessage ? `
              <div class="auth-success-banner" style="margin: 0;">
                <span class="material-icons" style="font-size: 18px; color: var(--success);">check_circle</span>
                <span>${this.successMessage}</span>
              </div>
            ` : ''}

            <div class="form-group" style="margin-bottom: 8px;">
              <label class="form-label" style="font-size: 12px;">Current Password</label>
              <input 
                type="${this.showPasswords ? 'text' : 'password'}" 
                class="form-control" 
                id="change-pwd-current-input" 
                placeholder="Enter current password" 
                value="${this.currentPassword}"
                autocomplete="current-password"
                ${this.isLoading ? 'disabled' : ''}
              >
            </div>

            <div class="form-group" style="margin-bottom: 8px;">
              <label class="form-label" style="font-size: 12px;">New Password</label>
              <input 
                type="${this.showPasswords ? 'text' : 'password'}" 
                class="form-control" 
                id="change-pwd-new-input" 
                placeholder="At least 6 characters" 
                value="${this.newPassword}"
                autocomplete="new-password"
                ${this.isLoading ? 'disabled' : ''}
              >
            </div>

            <div class="form-group" style="margin-bottom: 4px;">
              <label class="form-label" style="font-size: 12px;">Confirm New Password</label>
              <input 
                type="${this.showPasswords ? 'text' : 'password'}" 
                class="form-control" 
                id="change-pwd-confirm-input" 
                placeholder="Re-enter new password" 
                value="${this.confirmPassword}"
                autocomplete="new-password"
                ${this.isLoading ? 'disabled' : ''}
              >
            </div>

            <div style="display: flex; align-items: center; justify-content: space-between; margin-top: 4px;">
              <label style="display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--text-secondary); cursor: pointer;">
                <input type="checkbox" id="change-pwd-show-toggle" ${this.showPasswords ? 'checked' : ''} style="cursor: pointer;">
                <span>Show passwords</span>
              </label>

              <button type="button" class="btn-ghost" id="change-pwd-send-email-link" style="font-size: 12px; padding: 4px 8px; color: var(--text-secondary);">
                <span class="material-icons" style="font-size: 14px;">mail</span>
                <span>Send reset email instead</span>
              </button>
            </div>

            <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 12px; border-top: 1px solid var(--glass-border); padding-top: 14px;">
              <button class="btn-secondary" id="change-pwd-cancel-btn" style="width: auto;" ${this.isLoading ? 'disabled' : ''}>
                Cancel
              </button>
              <button class="btn-primary" id="change-pwd-submit-btn" style="width: auto;" ${this.isLoading ? 'disabled' : ''}>
                ${this.isLoading ? `
                  <span class="material-icons animate-spin" style="font-size: 16px;">sync</span>
                  <span>Updating...</span>
                ` : `
                  <span class="material-icons" style="font-size: 16px;">check</span>
                  <span>Update Password</span>
                `}
              </button>
            </div>
          ` : `
            <div style="background: var(--bg-surface-subtle); border: 1px solid var(--glass-border); border-radius: var(--radius-md); padding: 18px;">
              <div style="display: flex; align-items: center; gap: 12px; margin-bottom: 12px;">
                <div style="width: 40px; height: 40px; border-radius: 50%; background: var(--bg-surface-hover); display: flex; align-items: center; justify-content: center;">
                  <svg width="20" height="20" viewBox="0 0 24 24">
                    <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
                    <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
                    <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"/>
                    <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"/>
                  </svg>
                </div>
                <div>
                  <div style="font-weight: 700; font-size: 15px; color: var(--text-primary);">Google Account</div>
                  <div style="font-size: 12.5px; color: var(--text-muted);">${email}</div>
                </div>
              </div>
              <p style="font-size: 13px; color: var(--text-secondary); line-height: 1.5; margin: 0 0 14px;">
                You are signed in with Google OAuth. Your account credentials are managed through Google.
              </p>
              <p style="font-size: 12px; color: var(--text-muted); line-height: 1.4; margin: 0 0 16px;">
                If you want to set an email password to also sign in directly with your email, we can send you a password setup link.
              </p>
              <button class="btn-secondary" id="change-pwd-google-setup-btn" style="width: 100%; justify-content: center;">
                <span class="material-icons" style="font-size: 16px;">mail</span>
                <span>Send Password Setup Email</span>
              </button>
            </div>
          `)}
        </div>
      </div>
    `;
  },

  bindEvents(modalRoot) {
    const closeDialog = () => {
      this.close();
    };

    modalRoot.querySelector('#change-pwd-close-btn')?.addEventListener('click', closeDialog);
    modalRoot.querySelector('#change-pwd-cancel-btn')?.addEventListener('click', closeDialog);
    modalRoot.querySelector('#change-pwd-done-btn')?.addEventListener('click', closeDialog);

    // Close on backdrop click
    modalRoot.addEventListener('click', (e) => {
      if (e.target === modalRoot && !this.isLoading) closeDialog();
    });

    // Toggle password visibility
    const showToggle = modalRoot.querySelector('#change-pwd-show-toggle');
    if (showToggle) {
      showToggle.addEventListener('change', (e) => {
        this.showPasswords = e.target.checked;
        const currentInput = modalRoot.querySelector('#change-pwd-current-input');
        const newInput = modalRoot.querySelector('#change-pwd-new-input');
        const confirmInput = modalRoot.querySelector('#change-pwd-confirm-input');
        const type = this.showPasswords ? 'text' : 'password';
        if (currentInput) currentInput.type = type;
        if (newInput) newInput.type = type;
        if (confirmInput) confirmInput.type = type;
      });
    }

    const currentInput = modalRoot.querySelector('#change-pwd-current-input');
    const newInput = modalRoot.querySelector('#change-pwd-new-input');
    const confirmInput = modalRoot.querySelector('#change-pwd-confirm-input');

    if (currentInput) {
      currentInput.addEventListener('input', (e) => {
        this.currentPassword = e.target.value;
      });
    }

    if (newInput) {
      newInput.addEventListener('input', (e) => {
        this.newPassword = e.target.value;
      });
    }

    if (confirmInput) {
      confirmInput.addEventListener('input', (e) => {
        this.confirmPassword = e.target.value;
      });

      confirmInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
          modalRoot.querySelector('#change-pwd-submit-btn')?.click();
        }
      });
    }

    // Submit password update
    modalRoot.querySelector('#change-pwd-submit-btn')?.addEventListener('click', async () => {
      if (!this.currentPassword) {
        this.errorMessage = 'Please enter your current password.';
        modalRoot.innerHTML = this.render();
        this.bindEvents(modalRoot);
        return;
      }

      if (!this.newPassword || this.newPassword.length < 6) {
        this.errorMessage = 'New password must be at least 6 characters.';
        modalRoot.innerHTML = this.render();
        this.bindEvents(modalRoot);
        return;
      }

      if (this.newPassword !== this.confirmPassword) {
        this.errorMessage = 'New passwords do not match. Please check and try again.';
        modalRoot.innerHTML = this.render();
        this.bindEvents(modalRoot);
        return;
      }

      this.isLoading = true;
      this.errorMessage = null;
      modalRoot.innerHTML = this.render();
      this.bindEvents(modalRoot);

      try {
        await AuthService.changePassword(this.currentPassword, this.newPassword);
        this.isLoading = false;
        this.isSuccess = true;
        this.successMessage = 'Your password has been changed successfully.';
        modalRoot.innerHTML = this.render();
        this.bindEvents(modalRoot);
      } catch (err) {
        this.isLoading = false;
        this.errorMessage = err.message || 'Failed to update password. Verify your current password and try again.';
        modalRoot.innerHTML = this.render();
        this.bindEvents(modalRoot);
      }
    });

    // Send reset email instead
    const sendResetEmailAction = async () => {
      const user = AuthService.getCurrentUser();
      if (!user || !user.email) return;

      this.isLoading = true;
      this.errorMessage = null;
      modalRoot.innerHTML = this.render();
      this.bindEvents(modalRoot);

      try {
        await AuthService.resetPassword(user.email);
        this.isLoading = false;
        this.isSuccess = true;
        this.successMessage = `A password reset link has been sent to ${user.email}. Check your inbox to complete the process.`;
        modalRoot.innerHTML = this.render();
        this.bindEvents(modalRoot);
      } catch (err) {
        this.isLoading = false;
        this.errorMessage = err.message || 'Could not send reset email.';
        modalRoot.innerHTML = this.render();
        this.bindEvents(modalRoot);
      }
    };

    modalRoot.querySelector('#change-pwd-send-email-link')?.addEventListener('click', sendResetEmailAction);
    modalRoot.querySelector('#change-pwd-google-setup-btn')?.addEventListener('click', sendResetEmailAction);
  }
};
