/* Dynamic Firebase Initialization: supports Default Cloud, Bring Your Own Firebase (BYOF), and Local-Only mode */
import { initializeApp, getApps } from 'firebase/app';
import { getAuth, GoogleAuthProvider, signInWithCredential } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

export const CUSTOM_FIREBASE_KEY = 'quantro_custom_firebase_config';

export const DEFAULT_FIREBASE_CONFIG = {
  apiKey: "AIzaSyCUzR6hH-DtbnYf2-fADQNdIa77g8KZbVM",
  authDomain: "quantro-money-manager.firebaseapp.com",
  projectId: "quantro-money-manager",
  storageBucket: "quantro-money-manager.firebasestorage.app",
  messagingSenderId: "277150463102",
  appId: "1:277150463102:web:df559845cdc2170731d42f",
  measurementId: "G-QFM43CQK3W"
};

// Retrieve user's custom Firebase config if configured in browser
export function getCustomFirebaseConfig() {
  try {
    const raw = localStorage.getItem(CUSTOM_FIREBASE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    if (parsed && parsed.apiKey && parsed.projectId && parsed.appId) {
      return parsed;
    }
    return null;
  } catch (_) {
    return null;
  }
}

export function isUsingCustomFirebase() {
  return getCustomFirebaseConfig() !== null;
}

export function getActiveFirebaseConfig() {
  const custom = getCustomFirebaseConfig();
  return custom || DEFAULT_FIREBASE_CONFIG;
}

export function getActiveProjectId() {
  const active = getActiveFirebaseConfig();
  return active?.projectId || 'quantro-money-manager';
}

// Validate and persist user's custom Firebase configuration
export function saveCustomFirebaseConfig(config) {
  if (!config || typeof config !== 'object') {
    throw new Error('Invalid configuration object.');
  }

  const apiKey = String(config.apiKey || '').trim();
  const projectId = String(config.projectId || '').trim();
  const appId = String(config.appId || '').trim();

  if (!apiKey || !projectId || !appId) {
    throw new Error('Missing required Firebase keys: apiKey, projectId, or appId.');
  }

  const cleanConfig = {
    apiKey,
    authDomain: config.authDomain ? String(config.authDomain).trim() : `${projectId}.firebaseapp.com`,
    projectId,
    storageBucket: config.storageBucket ? String(config.storageBucket).trim() : `${projectId}.firebasestorage.app`,
    messagingSenderId: config.messagingSenderId ? String(config.messagingSenderId).trim() : '',
    appId,
    measurementId: config.measurementId ? String(config.measurementId).trim() : ''
  };

  localStorage.setItem(CUSTOM_FIREBASE_KEY, JSON.stringify(cleanConfig));
  return cleanConfig;
}

export function removeCustomFirebaseConfig() {
  localStorage.removeItem(CUSTOM_FIREBASE_KEY);
}

// Initialize active Firebase App safely
let appInstance = null;
let authInstance = null;
let dbInstance = null;
let googleAuthProviderInstance = null;

try {
  const activeConfig = getActiveFirebaseConfig();
  appInstance = getApps().length > 0 ? getApps()[0] : initializeApp(activeConfig);
  authInstance = getAuth(appInstance);
  dbInstance = getFirestore(appInstance);
  googleAuthProviderInstance = new GoogleAuthProvider();
  googleAuthProviderInstance.setCustomParameters({ prompt: 'select_account' });
} catch (err) {
  console.warn('Firebase initialization note: offline/local mode will be used.', err);
}

export const app = appInstance;
export const auth = authInstance;
export const db = dbInstance;
export const googleAuthProvider = googleAuthProviderInstance;
export { signInWithCredential };
