/* Forgot Password Modal: Allows users to request a password reset email */
import { AuthService } from '../auth.js';

export const ForgotPasswordModal = {
  email: '',
  isLoading: false,
  errorMessage: null,
  isSent: false,

  show(prefilledEmail = '') {
    this.email = prefilledEmail ? prefilledEmail.trim() : '';
    this.isLoading = false;
    this.errorMessage = null;
    this.isSent = false;

    let modalRoot = document.getElementById('forgot-password-modal-root');
    if (!modalRoot) {
      modalRoot = document.createElement('div');
      modalRoot.id = 'forgot-password-modal-root';
      modalRoot.className = 'modal-overlay';
      document.body.appendChild(modalRoot);
    }

    modalRoot.innerHTML = this.render();
    modalRoot.classList.add('active');
    this.bindEvents(modalRoot);

    // Auto-focus email input if not sent
    setTimeout(() => {
      const input = document.getElementById('forgot-pwd-email-input');
      if (input) input.focus();
    }, 100);
  },

  close() {
    const modalRoot = document.getElementById('forgot-password-modal-root');
    if (modalRoot) {
      modalRoot.classList.remove('active');
      modalRoot.innerHTML = '';
    }
  },

  render() {
    return `
      <div class="modern-modal-dialog animate-scale-up" style="max-width: 480px;" id="forgot-password-dialog">
        <div class="modal-header">
          <div class="modal-title">
            <span class="material-icons" style="color: var(--primary);">lock_reset</span>
            <span>Reset Your Password</span>
          </div>
          <button class="modal-close-btn" id="forgot-pwd-close-btn" aria-label="Close">
            <span class="material-icons" style="font-size: 20px; line-height: 1;">close</span>
          </button>
        </div>

        <div style="display: flex; flex-direction: column; gap: 16px; padding: 4px 0;">
          ${this.isSent ? `
            <div style="text-align: center; padding: 16px 8px;">
              <div style="width: 52px; height: 52px; border-radius: 50%; background: var(--success-bg); display: flex; align-items: center; justify-content: center; margin: 0 auto 16px;">
                <span class="material-icons" style="font-size: 28px; color: var(--success);">mark_email_read</span>
              </div>
              <h3 style="font-size: 17px; font-weight: 700; color: var(--text-primary); margin-bottom: 8px;">Check Your Inbox</h3>
              <p style="font-size: 13.5px; color: var(--text-secondary); line-height: 1.5; margin-bottom: 16px;">
                We have sent password reset instructions to:<br>
                <strong style="color: var(--text-primary); font-family: var(--font-mono);">${this.email}</strong>
              </p>
              <p style="font-size: 12px; color: var(--text-muted); line-height: 1.4; margin-bottom: 24px;">
                Click the link in the email to set a new password. If you don't see it, check your spam or junk folder.
              </p>
              <button class="btn-primary" id="forgot-pwd-done-btn" style="width: 100%; justify-content: center;">
                <span>Back to Sign In</span>
              </button>
            </div>
          ` : `
            <p style="font-size: 13.5px; color: var(--text-secondary); line-height: 1.5; margin: 0;">
              Enter the email address registered with your account. We will send you a secure link to reset your password.
            </p>

            ${this.errorMessage ? `
              <div class="auth-error-banner" style="margin: 0;">
                <span class="material-icons" style="font-size: 18px; color: var(--error);">error_outline</span>
                <span>${this.errorMessage}</span>
              </div>
            ` : ''}

            <div class="form-group" style="margin-bottom: 4px;">
              <label class="form-label" style="font-size: 12px;">Email Address</label>
              <input 
                type="email" 
                class="form-control" 
                id="forgot-pwd-email-input" 
                placeholder="you@example.com" 
                value="${this.email}" 
                autocomplete="email"
                ${this.isLoading ? 'disabled' : ''}
              >
            </div>

            <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 8px;">
              <button class="btn-secondary" id="forgot-pwd-cancel-btn" style="width: auto;" ${this.isLoading ? 'disabled' : ''}>
                Cancel
              </button>
              <button class="btn-primary" id="forgot-pwd-submit-btn" style="width: auto;" ${this.isLoading ? 'disabled' : ''}>
                ${this.isLoading ? `
                  <span class="material-icons animate-spin" style="font-size: 16px;">sync</span>
                  <span>Sending Link...</span>
                ` : `
                  <span class="material-icons" style="font-size: 16px;">send</span>
                  <span>Send Reset Link</span>
                `}
              </button>
            </div>
          `}
        </div>
      </div>
    `;
  },

  bindEvents(modalRoot) {
    const closeAndReset = () => {
      this.close();
    };

    modalRoot.querySelector('#forgot-pwd-close-btn')?.addEventListener('click', closeAndReset);
    modalRoot.querySelector('#forgot-pwd-cancel-btn')?.addEventListener('click', closeAndReset);
    modalRoot.querySelector('#forgot-pwd-done-btn')?.addEventListener('click', closeAndReset);

    // Close on backdrop click
    modalRoot.addEventListener('click', (e) => {
      if (e.target === modalRoot) closeAndReset();
    });

    const emailInput = modalRoot.querySelector('#forgot-pwd-email-input');
    if (emailInput) {
      emailInput.addEventListener('input', (e) => {
        this.email = e.target.value;
      });

      emailInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
          modalRoot.querySelector('#forgot-pwd-submit-btn')?.click();
        }
      });
    }

    const submitBtn = modalRoot.querySelector('#forgot-pwd-submit-btn');
    if (submitBtn) {
      submitBtn.addEventListener('click', async () => {
        const val = this.email.trim();
        if (!val || val.indexOf('@') === -1) {
          this.errorMessage = 'Please enter a valid email address.';
          modalRoot.innerHTML = this.render();
          this.bindEvents(modalRoot);
          return;
        }

        this.isLoading = true;
        this.errorMessage = null;
        modalRoot.innerHTML = this.render();
        this.bindEvents(modalRoot);

        try {
          await AuthService.resetPassword(val);
          this.isLoading = false;
          this.isSent = true;
          modalRoot.innerHTML = this.render();
          this.bindEvents(modalRoot);
        } catch (err) {
          this.isLoading = false;
          this.errorMessage = err.message || 'Failed to send password reset email. Please try again.';
          modalRoot.innerHTML = this.render();
          this.bindEvents(modalRoot);
        }
      });
    }
  }
};
