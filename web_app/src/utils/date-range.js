/* Date Range calculations matching dashboard_providers.dart filter logic */

export const DateRangeHelper = {
  getDateRange(filter) {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    let start = new Date();
    let end = new Date();

    switch (filter) {
      case 'thisWeek': {
        // ISO 8601: Week starts on Monday
        const day = today.getDay();
        const diff = today.getDate() - day + (day === 0 ? -6 : 1); // adjust when day is sunday
        start = new Date(today.setDate(diff));
        
        const endDate = new Date(start);
        endDate.setDate(start.getDate() + 6);
        end = new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate(), 23, 59, 59, 999);
        break;
      }
      case 'lastWeek': {
        const day = today.getDay();
        const diff = today.getDate() - day + (day === 0 ? -6 : 1) - 7;
        start = new Date(today.setDate(diff));
        
        const endDate = new Date(start);
        endDate.setDate(start.getDate() + 6);
        end = new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate(), 23, 59, 59, 999);
        break;
      }
      case 'thisMonth': {
        start = new Date(now.getFullYear(), now.getMonth(), 1);
        const lastDay = new Date(now.getFullYear(), now.getMonth() + 1, 0);
        end = new Date(lastDay.getFullYear(), lastDay.getMonth(), lastDay.getDate(), 23, 59, 59, 999);
        break;
      }
      case 'lastMonth': {
        start = new Date(now.getFullYear(), now.getMonth() - 1, 1);
        const lastDay = new Date(now.getFullYear(), now.getMonth(), 0);
        end = new Date(lastDay.getFullYear(), lastDay.getMonth(), lastDay.getDate(), 23, 59, 59, 999);
        break;
      }
      case 'thisYear': {
        start = new Date(now.getFullYear(), 0, 1);
        end = new Date(now.getFullYear(), 11, 31, 23, 59, 59, 999);
        break;
      }
      case 'allTime':
      default: {
        start = new Date(2000, 0, 1);
        end = new Date(2100, 11, 31, 23, 59, 59, 999);
        break;
      }
    }

    return { start, end };
  }
};
