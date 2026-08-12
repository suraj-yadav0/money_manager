/* Authentication service (Firebase Auth + Guest Mode integrations) */
import { 
  createUserWithEmailAndPassword, 
  signInWithEmailAndPassword, 
  signInWithPopup, 
  sendPasswordResetEmail,
  signOut as firebaseSignOut,
  onAuthStateChanged
} from 'firebase/auth';
import { auth, googleAuthProvider } from './firebase-config.js';
import { StateManager } from './state.js';

export const AuthService = {
  // Get current logged in user
  getCurrentUser() {
    return auth.currentUser;
  },

  // Check if logged in
  isLoggedIn() {
    return this.getCurrentUser() !== null;
  },

  // Sign up with Email and Password
  async signUpWithEmail(email, password) {
    const credential = await createUserWithEmailAndPassword(auth, email.trim(), password);
    // Disable guest mode upon successful sign-in
    StateManager.disableGuestMode();
    return credential;
  },

  // Sign in with Email and Password
  async signInWithEmail(email, password) {
    const credential = await signInWithEmailAndPassword(auth, email.trim(), password);
    // Disable guest mode upon successful sign-in
    StateManager.disableGuestMode();
    return credential;
  },

  // Sign in with Google OAuth Popup
  async signInWithGoogle() {
    try {
      const result = await signInWithPopup(auth, googleAuthProvider);
      StateManager.disableGuestMode();
      return result.user;
    } catch (error) {
      console.error('Google Auth Popup Error:', error);
      throw error;
    }
  },

  // Send password reset email
  async resetPassword(email) {
    await sendPasswordResetEmail(auth, email.trim());
  },

  // Sign out from Firebase
  async signOut() {
    await firebaseSignOut(auth);
    StateManager.disableGuestMode(); // Clear out guest state values if logging out
  },

  // Watch authentication state changes
  watchAuthState(callback) {
    return onAuthStateChanged(auth, async (user) => {
      StateManager.setState({ user });
      if (callback) callback(user);
    });
  }
};
