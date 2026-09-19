/* Authentication service (Firebase Auth + Guest Mode integrations) */
import { 
  createUserWithEmailAndPassword, 
  signInWithEmailAndPassword, 
  signInWithPopup, 
  sendPasswordResetEmail,
  confirmPasswordReset,
  verifyPasswordResetCode,
  updatePassword,
  reauthenticateWithCredential,
  EmailAuthProvider,
  signOut as firebaseSignOut,
  onAuthStateChanged
} from 'firebase/auth';
import { auth, googleAuthProvider } from './firebase-config.js';
import { StateManager } from './state.js';

export function formatAuthError(error) {
  if (!error) return 'An unknown error occurred.';
  const code = error.code || '';
  switch (code) {
    case 'auth/invalid-credential':
    case 'auth/wrong-password':
    case 'auth/user-not-found':
      return 'Invalid email or password. Please check your credentials and try again.';
    case 'auth/email-already-in-use':
      return 'An account already exists with this email address. Please sign in instead.';
    case 'auth/weak-password':
      return 'Password should be at least 6 characters.';
    case 'auth/invalid-email':
      return 'Please enter a valid email address.';
    case 'auth/popup-closed-by-user':
      return 'Google sign-in popup was closed before completing.';
    case 'auth/popup-blocked':
      return 'Sign-in popup was blocked by your browser. Please allow popups for this site.';
    case 'auth/unauthorized-domain':
      return 'This web domain is not authorized in Firebase Console. Add it under Authentication > Settings > Authorized domains.';
    case 'auth/network-request-failed':
      return 'Network error. Please check your internet connection and try again.';
    case 'auth/too-many-requests':
      return 'Access temporarily disabled due to many failed login attempts. Please reset password or try again later.';
    case 'auth/expired-action-code':
      return 'This password reset link has expired. Please request a new one.';
    case 'auth/invalid-action-code':
      return 'This password reset link is invalid or has already been used. Please request a new link.';
    case 'auth/user-disabled':
      return 'This user account has been disabled.';
    case 'auth/requires-recent-login':
      return 'This operation requires recent authentication. Please sign in again and retry.';
    default:
      return error.message ? error.message.replace('Firebase:', '').trim() : 'Authentication failed.';
  }
}

export const AuthService = {
  // Get current logged in user
  getCurrentUser() {
    return auth ? auth.currentUser : null;
  },

  // Check if logged in
  isLoggedIn() {
    return this.getCurrentUser() !== null;
  },

  // Check if current user uses password provider
  isPasswordUser() {
    const user = this.getCurrentUser();
    if (!user || !user.providerData) return false;
    return user.providerData.some(p => p.providerId === 'password');
  },

  // Sign up with Email and Password
  async signUpWithEmail(email, password) {
    try {
      const credential = await createUserWithEmailAndPassword(auth, email.trim(), password);
      StateManager.disableGuestMode();
      StateManager.setState({ user: credential.user });
      return credential;
    } catch (err) {
      throw new Error(formatAuthError(err));
    }
  },

  // Sign in with Email and Password
  async signInWithEmail(email, password) {
    try {
      const credential = await signInWithEmailAndPassword(auth, email.trim(), password);
      StateManager.disableGuestMode();
      StateManager.setState({ user: credential.user });
      return credential;
    } catch (err) {
      throw new Error(formatAuthError(err));
    }
  },

  // Sign in with Google OAuth Popup
  async signInWithGoogle() {
    try {
      const result = await signInWithPopup(auth, googleAuthProvider);
      StateManager.disableGuestMode();
      StateManager.setState({ user: result.user });
      return result.user;
    } catch (error) {
      console.error('Google Auth Popup Error:', error);
      throw new Error(formatAuthError(error));
    }
  },

  // Send password reset email
  async resetPassword(email) {
    try {
      await sendPasswordResetEmail(auth, email.trim());
    } catch (err) {
      throw new Error(formatAuthError(err));
    }
  },

  // Verify password reset code from email link
  async verifyResetCode(oobCode) {
    try {
      const email = await verifyPasswordResetCode(auth, oobCode);
      return email;
    } catch (err) {
      throw new Error(formatAuthError(err));
    }
  },

  // Confirm password reset with new password
  async confirmNewPassword(oobCode, newPassword) {
    try {
      await confirmPasswordReset(auth, oobCode, newPassword);
    } catch (err) {
      throw new Error(formatAuthError(err));
    }
  },

  // Change password for logged in user (requires current password for reauthentication)
  async changePassword(currentPassword, newPassword) {
    const user = this.getCurrentUser();
    if (!user || !user.email) {
      throw new Error('No authenticated user found.');
    }
    try {
      const credential = EmailAuthProvider.credential(user.email, currentPassword);
      await reauthenticateWithCredential(user, credential);
      await updatePassword(user, newPassword);
    } catch (err) {
      throw new Error(formatAuthError(err));
    }
  },

  // Sign out from Firebase
  async signOut() {
    try {
      if (auth) await firebaseSignOut(auth);
    } catch (e) {
      console.error('Signout error:', e);
    }
    
    // Clear out user state cleanly
    StateManager.setState({
      user: null,
      isGuestMode: false,
      transactions: [],
      categories: [],
      goals: [],
      goalContributions: [],
      categorizationRules: [],
      assets: [],
      syncStatus: 'idle',
      lastSyncedAt: null,
      userSettings: {
        monthlyIncome: 0,
        currency: 'INR',
        isOnboarded: false,
        showIncomeChart: false,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      }
    });
  },

  // Watch authentication state changes
  watchAuthState(callback) {
    if (!auth) return () => {};
    return onAuthStateChanged(auth, async (user) => {
      StateManager.setState({ user });
      if (callback) callback(user);
    });
  }
};
