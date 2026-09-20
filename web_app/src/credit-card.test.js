import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

describe('Credit Card Balance Dynamics', () => {
  it('calculates available limit and debt correctly on expense', () => {
    const card = {
      credit_limit: 100000,
      balance: 15000 // initial debt
    };

    const initialAvailable = Math.max(0, card.credit_limit - card.balance);
    assert.equal(initialAvailable, 85000);

    // After logging a 20,000 expense
    const expenseAmount = 20000;
    const newDebt = card.balance + expenseAmount;
    const newAvailable = Math.max(0, card.credit_limit - newDebt);

    assert.equal(newDebt, 35000);
    assert.equal(newAvailable, 65000);
  });

  it('restores available limit and reduces debt on bill payment', () => {
    const card = {
      credit_limit: 100000,
      balance: 35000 // current debt
    };

    // After paying 30,000 towards the bill
    const paymentAmount = 30000;
    const remainingDebt = Math.max(0, card.balance - paymentAmount);
    const restoredAvailable = Math.max(0, card.credit_limit - remainingDebt);

    assert.equal(remainingDebt, 5000);
    assert.equal(restoredAvailable, 95000);
  });

  it('detects when an expense exceeds available credit limit', () => {
    const card = {
      credit_limit: 50000,
      balance: 42000 // 8000 available
    };

    const available = Math.max(0, card.credit_limit - card.balance);
    const expenseAmount = 10000;

    const exceedsLimit = expenseAmount > available;
    const excessAmount = expenseAmount - available;

    assert.equal(exceedsLimit, true);
    assert.equal(excessAmount, 2000);
  });
});

describe('Credit Card Statement Regex Parsing', () => {
  function parseStatement(text) {
    const totalMatch = text.match(/(?:total\s*(?:amt\s*)?due|total\s*due\s*(?:is|:)?|due\s*amt|amount\s*due)\s*[:\s-]*\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)/i) ||
                       text.match(/(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)/i);
    const cardMatch = text.match(/(?:card|ending with|ending in|ending)\s*(?:no\.?)?\s*[:\s]*[*xX]*([0-9]{3,4})/i) ||
                      text.match(/[*xX]{2,}([0-9]{3,4})/);
    const dueMatch = text.match(/(?:due\s*date|pay\s*by|before|payment\s*due\s*date)\s*(?:is|:)?\s*(\d{1,2}[-/\.](?:[A-Za-z]{3}|\d{1,2})[-/\.]\d{2,4})/i);

    let bankName = 'Credit Card';
    if (/hdfc/i.test(text)) bankName = 'HDFC Bank';
    else if (/icici/i.test(text)) bankName = 'ICICI Bank';
    else if (/sbi/i.test(text)) bankName = 'State Bank of India';
    else if (/axis/i.test(text)) bankName = 'Axis Bank';
    else if (/kotak/i.test(text)) bankName = 'Kotak Bank';

    const totalDue = totalMatch ? parseFloat(totalMatch[1].replace(/,/g, '')) : null;
    const cardLast4 = cardMatch ? cardMatch[1] : null;
    const dueDate = dueMatch ? dueMatch[1] : null;

    return { totalDue, cardLast4, dueDate, bankName };
  }

  it('parses HDFC Bank statement correctly', () => {
    const sms = 'Statement for HDFC Bank Credit Card ending 4321. Total Amt Due: Rs 14,250.00, Min Amt Due: Rs 750.00, Due Date: 15-Oct-2026.';
    const result = parseStatement(sms);

    assert.equal(result.bankName, 'HDFC Bank');
    assert.equal(result.cardLast4, '4321');
    assert.equal(result.totalDue, 14250.0);
    assert.equal(result.dueDate, '15-Oct-2026');
  });

  it('parses ICICI Bank statement correctly', () => {
    const sms = 'Your ICICI Bank Credit Card XX9876 statement is generated. Total Due: INR 32,100.50. Pay by 22-11-2026 to avoid charges.';
    const result = parseStatement(sms);

    assert.equal(result.bankName, 'ICICI Bank');
    assert.equal(result.cardLast4, '9876');
    assert.equal(result.totalDue, 32100.50);
    assert.equal(result.dueDate, '22-11-2026');
  });

  it('parses SBI Card statement correctly', () => {
    const sms = 'Total Amount Due on your SBI Card ending 5544 is Rs. 8,420.00. Payment Due Date: 05/12/2026.';
    const result = parseStatement(sms);

    assert.equal(result.bankName, 'State Bank of India');
    assert.equal(result.cardLast4, '5544');
    assert.equal(result.totalDue, 8420.0);
    assert.equal(result.dueDate, '05/12/2026');
  });
});
