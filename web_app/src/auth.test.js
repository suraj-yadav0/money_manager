import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { formatAuthError } from './auth.js';
import { ForgotPasswordModal } from './pages/forgot-password-modal.js';
import { ResetPasswordModal } from './pages/reset-password-modal.js';
import { ChangePasswordModal } from './pages/change-password-modal.js';

describe('Authentication Error Formatting', () => {
  it('formats expired action code error correctly', () => {
    const error = { code: 'auth/expired-action-code' };
    assert.equal(
      formatAuthError(error),
      'This password reset link has expired. Please request a new one.'
    );
  });

  it('formats invalid action code error correctly', () => {
    const error = { code: 'auth/invalid-action-code' };
    assert.equal(
      formatAuthError(error),
      'This password reset link is invalid or has already been used. Please request a new link.'
    );
  });

  it('formats requires recent login error correctly', () => {
    const error = { code: 'auth/requires-recent-login' };
    assert.equal(
      formatAuthError(error),
      'This operation requires recent authentication. Please sign in again and retry.'
    );
  });

  it('formats weak password error correctly', () => {
    const error = { code: 'auth/weak-password' };
    assert.equal(
      formatAuthError(error),
      'Password should be at least 6 characters.'
    );
  });

  it('formats invalid email error correctly', () => {
    const error = { code: 'auth/invalid-email' };
    assert.equal(
      formatAuthError(error),
      'Please enter a valid email address.'
    );
  });

  it('formats user not found and wrong password errors consistently', () => {
    assert.equal(
      formatAuthError({ code: 'auth/user-not-found' }),
      'Invalid email or password. Please check your credentials and try again.'
    );
    assert.equal(
      formatAuthError({ code: 'auth/wrong-password' }),
      'Invalid email or password. Please check your credentials and try again.'
    );
  });

  it('returns default message for unknown error', () => {
    assert.equal(
      formatAuthError({ message: 'Firebase: Something broke' }),
      'Something broke'
    );
  });
});

describe('Forgot Password Modal Structure & State', () => {
  it('initializes with prefilled email and default states', () => {
    ForgotPasswordModal.email = 'test@example.com';
    ForgotPasswordModal.isLoading = false;
    ForgotPasswordModal.isSent = false;
    ForgotPasswordModal.errorMessage = null;

    const html = ForgotPasswordModal.render();
    assert.ok(html.includes('Reset Your Password'));
    assert.ok(html.includes('test@example.com'));
    assert.ok(html.includes('Send Reset Link'));
  });

  it('renders sent confirmation state when isSent is true', () => {
    ForgotPasswordModal.email = 'sent@example.com';
    ForgotPasswordModal.isSent = true;

    const html = ForgotPasswordModal.render();
    assert.ok(html.includes('Check Your Inbox'));
    assert.ok(html.includes('sent@example.com'));
    assert.ok(html.includes('Back to Sign In'));
  });

  it('renders error message when present', () => {
    ForgotPasswordModal.isSent = false;
    ForgotPasswordModal.errorMessage = 'Network error occurred';

    const html = ForgotPasswordModal.render();
    assert.ok(html.includes('Network error occurred'));
  });
});

describe('Reset Password Modal Structure & State', () => {
  it('renders verifying state while code is checked', () => {
    ResetPasswordModal.isVerifying = true;
    ResetPasswordModal.isSuccess = false;
    ResetPasswordModal.errorMessage = null;

    const html = ResetPasswordModal.render();
    assert.ok(html.includes('Verifying password reset link...'));
  });

  it('renders password input form when verified', () => {
    ResetPasswordModal.isVerifying = false;
    ResetPasswordModal.userEmail = 'verified@example.com';
    ResetPasswordModal.isSuccess = false;
    ResetPasswordModal.errorMessage = null;

    const html = ResetPasswordModal.render();
    assert.ok(html.includes('Set New Password'));
    assert.ok(html.includes('verified@example.com'));
    assert.ok(html.includes('reset-new-pwd-input'));
    assert.ok(html.includes('reset-confirm-pwd-input'));
  });

  it('renders success state when password is reset', () => {
    ResetPasswordModal.isVerifying = false;
    ResetPasswordModal.isSuccess = true;

    const html = ResetPasswordModal.render();
    assert.ok(html.includes('Password Reset Complete'));
    assert.ok(html.includes('Sign In with New Password'));
  });

  it('renders error state with request new link option when link is expired', () => {
    ResetPasswordModal.isVerifying = false;
    ResetPasswordModal.userEmail = null;
    ResetPasswordModal.isSuccess = false;
    ResetPasswordModal.errorMessage = 'Link expired';

    const html = ResetPasswordModal.render();
    assert.ok(html.includes('Link Expired or Invalid'));
    assert.ok(html.includes('Request a New Reset Link'));
  });
});

describe('Change Password Modal Structure & State', () => {
  it('renders change password inputs for email/password users', () => {
    ChangePasswordModal.isSuccess = false;
    ChangePasswordModal.isLoading = false;
    ChangePasswordModal.errorMessage = null;

    const html = ChangePasswordModal.render();
    assert.ok(html.includes('Account Security'));
  });

  it('renders success state after password update', () => {
    ChangePasswordModal.isSuccess = true;
    ChangePasswordModal.successMessage = 'Password updated successfully.';

    const html = ChangePasswordModal.render();
    assert.ok(html.includes('Password Updated'));
    assert.ok(html.includes('Password updated successfully.'));
  });
});
