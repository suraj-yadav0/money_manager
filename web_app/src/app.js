/* Main Web App Entry Point: CSS imports, auth state binding, and router initialization */
import './css/variables.css';
import './css/base.css';
import './css/components.css';
import './css/layout.css';
import './css/pages.css';

import { StateManager } from './state.js';
import { AuthService } from './auth.js';
import { DbService } from './db.js';
import { Router } from './router.js';

// Setup theme switcher baseline (default: dark theme)
function initializeTheme() {
  const savedTheme = localStorage.getItem('money_manager_theme') || 'dark';
  document.documentElement.setAttribute('data-theme', savedTheme);
}

// Initialise Application
async function initApp() {
  initializeTheme();
  
  // 1. Initialize client-side SPA routing inside '#app' element
  Router.init('#app');

  // 2. Watch Firebase Auth state changes
  AuthService.watchAuthState(async (user) => {
    if (user) {
      // User is logged in, sync with cloud Firestore in real-time
      DbService.startSync(user.uid);
      
      // Auto transition/close Auth overlays if active
      if (Router.activeOverlayPage === 'auth') {
        Router.closeOverlay();
      }
    } else {
      // User is logged out, disable Firestore listeners
      DbService.stopSync();
      
      // Check if user was using Guest/Offline Mode
      if (StateManager.state.isGuestMode) {
        StateManager.loadGuestState();
      } else {
        // Clear active data lists since they are logged out and not guest
        StateManager.setState({
          transactions: [],
          categories: [],
          goals: [],
          goalContributions: [],
          categorizationRules: [],
          assets: []
        });
      }
    }
  });
}

// Start app on DOMContentLoaded
window.addEventListener('DOMContentLoaded', initApp);
