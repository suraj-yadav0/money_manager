/* Reset Password Modal: Handles the oobCode verification and password update from email link */
import { AuthService } from '../auth.js';
import { ForgotPasswordModal } from './forgot-password-modal.js';

export const ResetPasswordModal = {
  oobCode: null,
  userEmail: null,
  isVerifying: true,
  isUpdating: false,
  isSuccess: false,
  errorMessage: null,
  newPassword: '',
  confirmPassword: '',
  showPassword: false,

  async show(oobCode) {
    this.oobCode = oobCode;
    this.userEmail = null;
    this.isVerifying = true;
    this.isUpdating = false;
    this.isSuccess = false;
    this.errorMessage = null;
    this.newPassword = '';
    this.confirmPassword = '';
    this.showPassword = false;

    let modalRoot = document.getElementById('reset-password-modal-root');
    if (!modalRoot) {
      modalRoot = document.createElement('div');
      modalRoot.id = 'reset-password-modal-root';
      modalRoot.className = 'modal-overlay';
      document.body.appendChild(modalRoot);
    }

    modalRoot.innerHTML = this.render();
    modalRoot.classList.add('active');
    this.bindEvents(modalRoot);

    // Verify code with Firebase
    try {
      const email = await AuthService.verifyResetCode(oobCode);
      this.userEmail = email;
      this.isVerifying = false;
      modalRoot.innerHTML = this.render();
      this.bindEvents(modalRoot);

      setTimeout(() => {
        const input = document.getElementById('reset-new-pwd-input');
        if (input) input.focus();
      }, 100);
    } catch (err) {
      this.isVerifying = false;
      this.errorMessage = err.message || 'Invalid or expired password reset link.';
      modalRoot.innerHTML = this.render();
      this.bindEvents(modalRoot);
    }
  },

  close() {
    const modalRoot = document.getElementById('reset-password-modal-root');
    if (modalRoot) {
      modalRoot.classList.remove('active');
      modalRoot.innerHTML = '';
    }
    // Clean up query parameters from URL
    try {
      const url = new URL(window.location.href);
      url.searchParams.delete('mode');
      url.searchParams.delete('oobCode');
      url.searchParams.delete('apiKey');
      url.searchParams.delete('lang');
      window.history.replaceState({}, document.title, url.pathname + (url.search ? url.search : ''));
    } catch (_) {}
  },

  render() {
    return `
      <div class="modern-modal-dialog animate-scale-up" style="max-width: 480px;" id="reset-password-dialog">
        <div class="modal-header">
          <div class="modal-title">
            <span class="material-icons" style="color: var(--primary);">lock</span>
            <span>Set New Password</span>
          </div>
          <button class="modal-close-btn" id="reset-pwd-close-btn" aria-label="Close">
            <span class="material-icons" style="font-size: 20px; line-height: 1;">close</span>
          </button>
        </div>

        <div style="display: flex; flex-direction: column; gap: 16px; padding: 4px 0;">
          ${this.isVerifying ? `
            <div style="text-align: center; padding: 32px 16px;">
              <span class="material-icons animate-spin" style="font-size: 36px; color: var(--primary); margin-bottom: 12px;">sync</span>
              <p style="font-size: 14px; color: var(--text-secondary); margin: 0;">Verifying password reset link...</p>
            </div>
          ` : (this.isSuccess ? `
            <div style="text-align: center; padding: 16px 8px;">
              <div style="width: 52px; height: 52px; border-radius: 50%; background: var(--success-bg); display: flex; align-items: center; justify-content: center; margin: 0 auto 16px;">
                <span class="material-icons" style="font-size: 28px; color: var(--success);">check_circle</span>
              </div>
              <h3 style="font-size: 17px; font-weight: 700; color: var(--text-primary); margin-bottom: 8px;">Password Reset Complete</h3>
              <p style="font-size: 13.5px; color: var(--text-secondary); line-height: 1.5; margin-bottom: 24px;">
                Your password has been successfully updated. You can now sign in using your new credentials.
              </p>
              <button class="btn-primary" id="reset-pwd-signin-btn" style="width: 100%; justify-content: center;">
                <span class="material-icons" style="font-size: 18px;">login</span>
                <span>Sign In with New Password</span>
              </button>
            </div>
          ` : (this.errorMessage && !this.userEmail ? `
            <div style="text-align: center; padding: 16px 8px;">
              <div style="width: 52px; height: 52px; border-radius: 50%; background: var(--error-bg); display: flex; align-items: center; justify-content: center; margin: 0 auto 16px;">
                <span class="material-icons" style="font-size: 28px; color: var(--error);">link_off</span>
              </div>
              <h3 style="font-size: 17px; font-weight: 700; color: var(--text-primary); margin-bottom: 8px;">Link Expired or Invalid</h3>
              <p style="font-size: 13.5px; color: var(--text-secondary); line-height: 1.5; margin-bottom: 20px;">
                ${this.errorMessage}
              </p>
              <button class="btn-primary" id="reset-pwd-request-new-btn" style="width: 100%; justify-content: center;">
                <span class="material-icons" style="font-size: 18px;">refresh</span>
                <span>Request a New Reset Link</span>
              </button>
            </div>
          ` : `
            <p style="font-size: 13.5px; color: var(--text-secondary); line-height: 1.5; margin: 0;">
              Resetting password for <strong style="color: var(--text-primary); font-family: var(--font-mono);">${this.userEmail || ''}</strong>. Enter your new password below.
            </p>

            ${this.errorMessage ? `
              <div class="auth-error-banner" style="margin: 0;">
                <span class="material-icons" style="font-size: 18px; color: var(--error);">error_outline</span>
                <span>${this.errorMessage}</span>
              </div>
            ` : ''}

            <div class="form-group" style="margin-bottom: 8px;">
              <label class="form-label" style="font-size: 12px;">New Password</label>
              <div style="position: relative; display: flex; align-items: center;">
                <input 
                  type="${this.showPassword ? 'text' : 'password'}" 
                  class="form-control" 
                  id="reset-new-pwd-input" 
                  placeholder="At least 6 characters" 
                  value="${this.newPassword}"
                  autocomplete="new-password"
                  style="padding-right: 42px;"
                  ${this.isUpdating ? 'disabled' : ''}
                >
                <button 
                  type="button" 
                  class="btn-icon" 
                  id="reset-toggle-pwd-btn" 
                  style="position: absolute; right: 6px; padding: 6px;"
                  title="${this.showPassword ? 'Hide password' : 'Show password'}"
                >
                  <span class="material-icons" style="font-size: 18px; color: var(--text-muted);">
                    ${this.showPassword ? 'visibility_off' : 'visibility'}
                  </span>
                </button>
              </div>
            </div>

            <div class="form-group" style="margin-bottom: 4px;">
              <label class="form-label" style="font-size: 12px;">Confirm New Password</label>
              <input 
                type="${this.showPassword ? 'text' : 'password'}" 
                class="form-control" 
                id="reset-confirm-pwd-input" 
                placeholder="Re-enter your new password" 
                value="${this.confirmPassword}"
                autocomplete="new-password"
                ${this.isUpdating ? 'disabled' : ''}
              >
            </div>

            <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 8px;">
              <button class="btn-secondary" id="reset-pwd-cancel-btn" style="width: auto;" ${this.isUpdating ? 'disabled' : ''}>
                Cancel
              </button>
              <button class="btn-primary" id="reset-pwd-submit-btn" style="width: auto;" ${this.isUpdating ? 'disabled' : ''}>
                ${this.isUpdating ? `
                  <span class="material-icons animate-spin" style="font-size: 16px;">sync</span>
                  <span>Updating Password...</span>
                ` : `
                  <span class="material-icons" style="font-size: 16px;">check</span>
                  <span>Save New Password</span>
                `}
              </button>
            </div>
          `))}
        </div>
      </div>
    `;
  },

  bindEvents(modalRoot) {
    const closeDialog = () => {
      this.close();
    };

    modalRoot.querySelector('#reset-pwd-close-btn')?.addEventListener('click', closeDialog);
    modalRoot.querySelector('#reset-pwd-cancel-btn')?.addEventListener('click', closeDialog);

    // Close on backdrop click (only if not verifying/updating)
    modalRoot.addEventListener('click', (e) => {
      if (e.target === modalRoot && !this.isUpdating && !this.isVerifying) {
        closeDialog();
      }
    });

    // Request new link button (when link was expired)
    modalRoot.querySelector('#reset-pwd-request-new-btn')?.addEventListener('click', () => {
      this.close();
      ForgotPasswordModal.show(this.userEmail || '');
    });

    // Sign In button after successful reset
    modalRoot.querySelector('#reset-pwd-signin-btn')?.addEventListener('click', () => {
      const email = this.userEmail;
      this.close();
      // Pre-fill email in Auth page if available
      const emailInput = document.getElementById('auth-email-input');
      if (emailInput && email) {
        emailInput.value = email;
        const pwdInput = document.getElementById('auth-password-input');
        if (pwdInput) pwdInput.focus();
      }
    });

    // Password visibility toggle
    modalRoot.querySelector('#reset-toggle-pwd-btn')?.addEventListener('click', () => {
      this.showPassword = !this.showPassword;
      const newPwdInput = modalRoot.querySelector('#reset-new-pwd-input');
      const confirmPwdInput = modalRoot.querySelector('#reset-confirm-pwd-input');
      if (newPwdInput) newPwdInput.type = this.showPassword ? 'text' : 'password';
      if (confirmPwdInput) confirmPwdInput.type = this.showPassword ? 'text' : 'password';
      const icon = modalRoot.querySelector('#reset-toggle-pwd-btn .material-icons');
      if (icon) icon.textContent = this.showPassword ? 'visibility_off' : 'visibility';
    });

    const newPwdInput = modalRoot.querySelector('#reset-new-pwd-input');
    const confirmPwdInput = modalRoot.querySelector('#reset-confirm-pwd-input');

    if (newPwdInput) {
      newPwdInput.addEventListener('input', (e) => {
        this.newPassword = e.target.value;
      });
    }

    if (confirmPwdInput) {
      confirmPwdInput.addEventListener('input', (e) => {
        this.confirmPassword = e.target.value;
      });

      confirmPwdInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
          modalRoot.querySelector('#reset-pwd-submit-btn')?.click();
        }
      });
    }

    // Submit new password
    modalRoot.querySelector('#reset-pwd-submit-btn')?.addEventListener('click', async () => {
      if (!this.newPassword || this.newPassword.length < 6) {
        this.errorMessage = 'Password must be at least 6 characters.';
        modalRoot.innerHTML = this.render();
        this.bindEvents(modalRoot);
        return;
      }

      if (this.newPassword !== this.confirmPassword) {
        this.errorMessage = 'Passwords do not match. Please verify and try again.';
        modalRoot.innerHTML = this.render();
        this.bindEvents(modalRoot);
        return;
      }

      this.isUpdating = true;
      this.errorMessage = null;
      modalRoot.innerHTML = this.render();
      this.bindEvents(modalRoot);

      try {
        await AuthService.confirmNewPassword(this.oobCode, this.newPassword);
        this.isUpdating = false;
        this.isSuccess = true;
        modalRoot.innerHTML = this.render();
        this.bindEvents(modalRoot);
      } catch (err) {
        this.isUpdating = false;
        this.errorMessage = err.message || 'Failed to update password. Please try again.';
        modalRoot.innerHTML = this.render();
        this.bindEvents(modalRoot);
      }
    });
  }
};
