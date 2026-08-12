/* Currency and date formatting utilities (exact replica of Formatters in Flutter) */
import { AppConstants } from './constants.js';

// Setup default Indian number formatting locale for Indian currency (INR) and compact formats
const inrFormatter = new Intl.NumberFormat('en-IN', {
  minimumFractionDigits: 0,
  maximumFractionDigits: 0,
});

const inrFormatterWithDecimals = new Intl.NumberFormat('en-IN', {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

export const Formatters = {
  /**
   * Format amount as currency: ₹1,23,456
   */
  currency(amount, symbol) {
    const s = symbol || AppConstants.currencySymbol;
    return `${s}${inrFormatter.format(amount)}`;
  },

  /**
   * Format amount with decimals: ₹1,23,456.78
   */
  currencyWithDecimals(amount, symbol) {
    const s = symbol || AppConstants.currencySymbol;
    return `${s}${inrFormatterWithDecimals.format(amount)}`;
  },

  /**
   * Format large amounts compactly: ₹1.2L or ₹1.5K
   */
  compactCurrency(amount, symbol) {
    const s = symbol || AppConstants.currencySymbol;
    return `${s}${this.compactNumber(amount)}`;
  },

  /**
   * Format as percentage: 45%
   */
  percentage(value) {
    return `${(value * 100).toFixed(0)}%`;
  },

  /**
   * Format date: 25 Jan 2026
   */
  date(d) {
    const dateObj = new Date(d);
    return dateObj.toLocaleDateString('en-GB', {
      day: 'numeric',
      month: 'short',
      year: 'numeric'
    });
  },

  /**
   * Format short date: 25 Jan
   */
  shortDate(d) {
    const dateObj = new Date(d);
    return dateObj.toLocaleDateString('en-GB', {
      day: 'numeric',
      month: 'short'
    });
  },

  /**
   * Format time: 5:30 PM
   */
  time(d) {
    const dateObj = new Date(d);
    return dateObj.toLocaleTimeString('en-US', {
      hour: 'numeric',
      minute: '2-digit',
      hour12: true
    });
  },

  /**
   * Format date and time: 25 Jan, 5:30 PM
   */
  dateTime(d) {
    return `${this.shortDate(d)}, ${this.time(d)}`;
  },

  /**
   * Format compact number: 1.5K, 2.3L
   */
  compactNumber(amount) {
    if (amount >= 100000) {
      return `${(amount / 100000).toFixed(1)}L`;
    } else if (amount >= 1000) {
      return `${(amount / 1000).toFixed(1)}K`;
    }
    return amount.toFixed(0);
  },

  /**
   * Format month: January 2026
   */
  month(d) {
    const dateObj = new Date(d);
    return dateObj.toLocaleDateString('en-US', {
      month: 'long',
      year: 'numeric'
    });
  },

  /**
   * Format day name: Sunday
   */
  dayName(d) {
    const dateObj = new Date(d);
    return dateObj.toLocaleDateString('en-US', { weekday: 'long' });
  },

  /**
   * Format short day name: Sun
   */
  dayOfWeek(d) {
    const dateObj = new Date(d);
    return dateObj.toLocaleDateString('en-US', { weekday: 'short' });
  },

  /**
   * Get relative date text: Today, Yesterday, or date
   */
  relativeDate(d) {
    const dateVal = new Date(d);
    const now = new Date();
    
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const targetDate = new Date(dateVal.getFullYear(), dateVal.getMonth(), dateVal.getDate());
    
    const diffTime = today - targetDate;
    const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24));
    
    if (diffDays === 0) return 'Today';
    if (diffDays === 1) return 'Yesterday';
    if (diffDays < 7 && diffDays > 0) return this.dayName(d);
    return this.shortDate(d);
  },

  /**
   * Get days remaining in current month
   */
  daysRemainingInMonth() {
    const now = new Date();
    const lastDay = new Date(now.getFullYear(), now.getMonth() + 1, 0);
    return lastDay.getDate() - now.getDate();
  },

  /**
   * Get days elapsed in current month
   */
  daysElapsedInMonth() {
    return new Date().getDate();
  },

  /**
   * Get total days in current month
   */
  daysInCurrentMonth() {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
  }
};
