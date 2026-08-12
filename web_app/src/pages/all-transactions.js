/* All Transactions See-All Overlay Screen Module (list, filters, and search note text inputs) */
import { StateManager } from '../state.js';
import { Formatters } from '../utils/formatters.js';
import { IconHelper } from '../utils/icons.js';
import { Router } from '../router.js';

export const AllTransactionsPage = {
  activeTypeFilter: 'all', // 'all', 'income', 'expense'
  searchQuery: '',

  render(state) {
    const list = this.getFilteredTransactions(state);

    return `
      <div class="modal-card animate-fade-in" style="background:#131124; max-height:90vh; display:flex; flex-direction:column; width:100%; max-width:600px; padding:32px 40px;">
        <div class="modal-header" style="border-bottom:1px solid var(--divider); padding-bottom:12px; margin-bottom:12px;">
          <div style="display:flex; align-items:center; gap:8px;">
            <span class="material-icons" style="color:var(--primary);">history</span>
            <h3 style="color:#FFF; font-size:20px;">Transaction History</h3>
          </div>
          <button class="modal-close" id="history-close-btn">&times;</button>
        </div>

        <!-- Search Bar and Filter Tabs -->
        <div style="display:flex; flex-direction:column; gap:12px; margin-bottom:16px;">
          <div class="form-input-container">
            <span class="material-icons form-input-icon">search</span>
            <input type="text" class="form-input" id="history-search-field" placeholder="Search by note..." value="${this.searchQuery}">
          </div>

          <div class="tab-bar" style="padding:2px; border-radius:20px;">
            <button class="tab-button ${this.activeTypeFilter === 'all' ? 'active' : ''}" 
                    style="padding: 6px 12px; font-size: 11px; border-radius: 16px;" 
                    id="history-filter-all">All</button>
            <button class="tab-button ${this.activeTypeFilter === 'income' ? 'active' : ''}" 
                    style="padding: 6px 12px; font-size: 11px; border-radius: 16px;" 
                    id="history-filter-income">Income</button>
            <button class="tab-button ${this.activeTypeFilter === 'expense' ? 'active' : ''}" 
                    style="padding: 6px 12px; font-size: 11px; border-radius: 16px;" 
                    id="history-filter-expense">Expenses</button>
          </div>
        </div>

        <!-- Scrollable List -->
        <div class="glass-card" style="padding:10px 20px; flex:1; overflow-y:auto;">
          ${list.length === 0 ? `
            <div style="text-align:center; padding:40px 0; color:var(--text-muted); font-size:14px;">No transactions match criteria.</div>
          ` : list.map(tx => this.renderTransactionRow(tx, state.categories)).join('')}
        </div>
      </div>
    `;
  },

  renderTransactionRow(tx, categories) {
    const cat = categories.find(c => c.id === tx.categoryId || c.sync_id === tx.categoryId);
    const icon = IconHelper.getMaterialIcon(cat ? cat.icon : 'category');
    const isIncome = tx.type === 'income';
    const formattedAmount = (isIncome ? '+' : '-') + Formatters.currency(tx.amount);
    
    let iconBg = 'rgba(255, 255, 255, 0.08)';
    if (cat) {
      if (cat.type === 'income') iconBg = 'rgba(16, 185, 129, 0.15)';
      else iconBg = 'rgba(255, 95, 31, 0.15)';
    }

    return `
      <div class="history-tx-row" data-sync-id="${tx.sync_id}" data-id="${tx.id || ''}"
           style="display:flex; align-items:center; justify-content:space-between; padding:14px 0; border-bottom:1px solid var(--divider); cursor:pointer;">
        <div class="transaction-icon-box" style="background: ${iconBg}; color: ${isIncome ? 'var(--success)' : 'var(--primary)'}; width:38px; height:38px;">
          <span class="material-icons" style="font-size:20px;">${icon}</span>
        </div>
        <div class="tx-details" style="margin-left:12px;">
          <div class="tx-note" style="font-size:14px; font-weight:600;">${tx.note || (cat ? cat.name : 'Transaction')}</div>
          <div class="tx-category" style="font-size:11px; color:var(--text-muted);">${cat ? cat.name : 'Other'}</div>
        </div>
        <div style="text-align:right;">
          <div class="tx-amount ${isIncome ? 'income' : 'expense'}" style="font-size:14px; font-weight:700;">${formattedAmount}</div>
          <div class="tx-date" style="font-size:10px; color:var(--text-muted); margin-top:2px;">${Formatters.dateTime(tx.timestamp)}</div>
        </div>
      </div>
    `;
  },

  getFilteredTransactions(state) {
    return state.transactions
      .filter(t => {
        // Type filter
        if (this.activeTypeFilter !== 'all' && t.type !== this.activeTypeFilter) return false;
        
        // Search query
        if (this.searchQuery && this.searchQuery.trim() !== '') {
          const query = this.searchQuery.toLowerCase();
          const noteMatch = t.note && t.note.toLowerCase().includes(query);
          const cat = state.categories.find(c => c.id === t.categoryId || c.sync_id === t.categoryId);
          const catMatch = cat && cat.name.toLowerCase().includes(query);
          return noteMatch || catMatch;
        }
        
        return true;
      })
      .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
  },

  bindEvents(state) {
    // Close button
    document.getElementById('history-close-btn').addEventListener('click', () => {
      Router.closeOverlay();
      this.searchQuery = ''; // reset buffers
    });

    // Search bar event
    const searchField = document.getElementById('history-search-field');
    searchField.addEventListener('input', (e) => {
      this.searchQuery = e.target.value;
      
      // Update matching list in UI dynamically without a full render (or re-render panel)
      // For simplicity in Vanilla JS SPA: trigger StateManager notify or overlay re-render
      StateManager.notify();
    });

    // Filters clicks
    document.getElementById('history-filter-all').addEventListener('click', () => {
      this.activeTypeFilter = 'all';
      StateManager.notify();
    });

    document.getElementById('history-filter-income').addEventListener('click', () => {
      this.activeTypeFilter = 'income';
      StateManager.notify();
    });

    document.getElementById('history-filter-expense').addEventListener('click', () => {
      this.activeTypeFilter = 'expense';
      StateManager.notify();
    });

    // Row clicks to edit
    const rows = document.querySelectorAll('.history-tx-row');
    rows.forEach(row => {
      row.addEventListener('click', () => {
        const syncId = row.getAttribute('data-sync-id');
        const localId = parseInt(row.getAttribute('data-id'), 10) || null;
        const tx = state.transactions.find(t => t.sync_id === syncId || (localId && t.id === localId));
        
        if (tx) {
          import('./add-transaction.js').then(({ AddTransactionModal }) => {
            AddTransactionModal.show(tx);
          });
        }
      });
    });
  }
};
