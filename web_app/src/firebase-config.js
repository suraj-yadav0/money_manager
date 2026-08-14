/* Firebase initialization using Web SDK modular syntax */
import { initializeApp } from 'firebase/app';
import { getAuth, GoogleAuthProvider, signInWithCredential } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: "AIzaSyCUzR6hH-DtbnYf2-fADQNdIa77g8KZbVM",
  authDomain: "quantro-money-manager.firebaseapp.com",
  projectId: "quantro-money-manager",
  storageBucket: "quantro-money-manager.firebasestorage.app",
  messagingSenderId: "277150463102",
  appId: "1:277150463102:web:df559845cdc2170731d42f",
  measurementId: "G-QFM43CQK3W"
};

// Initialize Firebase App
const app = initializeApp(firebaseConfig);

// Export instances
export const auth = getAuth(app);
export const db = getFirestore(app);
export const googleAuthProvider = new GoogleAuthProvider();
