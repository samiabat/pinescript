#!/usr/bin/env python3
"""
Gold (XAUUSD) Scalping Strategy - Bollinger Band Mean Reversion
===============================================================

A realistic scalping strategy for Gold using Bollinger Bands.
Buys oversold and sells overbought with proper risk management.

Strategy:
- Buy when price touches/crosses below lower Bollinger Band
- Sell when price touches/crosses above upper Bollinger Band  
- Exit at middle band or at profit/loss targets
- Includes realistic costs (spread, slippage, commission)
"""

import pandas as pd
import numpy as np
from datetime import datetime, time
import matplotlib.pyplot as plt

# =================================
# CONFIGURATION
# =================================

CSV_PATH = "XAUUSD5.csv"
INITIAL_BALANCE = 10000.0

# Risk Management
RISK_PER_TRADE = 0.012      # 1.2% risk
MAX_TRADES_PER_DAY = 6
MAX_DAILY_LOSS = 0.04       # 4%

# Trading Hours (UTC)
TRADING_START = time(8, 0)
TRADING_END = time(20, 0)

# Bollinger Bands
BB_PERIOD = 20
BB_STD = 2.0

# Profit/Loss
PROFIT_TARGET_PIPS = 12.0
STOP_LOSS_PIPS = 8.0

# Costs
SPREAD_PIPS = 2.0
SLIPPAGE_PIPS = 0.5
COMMISSION_PER_LOT = 7.0

# Limits
MIN_BALANCE = 5000.0
MAX_POSITION_LOTS = 10.0

# =================================
# HELPER FUNCTIONS
# =================================

def pips_to_price(pips):
    return pips * 0.01

def price_to_pips(price_diff):
    return price_diff / 0.01

def is_trading_time(dt):
    t = dt.time()
    return TRADING_START <= t <= TRADING_END

def calculate_position_size(balance, stop_pips):
    if balance <= 0 or stop_pips <= 0:
        return 0.0
    risk_amount = balance * RISK_PER_TRADE
    position_lots = risk_amount / (stop_pips * 1.0)
    return min(position_lots, MAX_POSITION_LOTS)

def calculate_costs(position_lots):
    spread_cost = SPREAD_PIPS * 1.0 * position_lots
    slippage_cost = SLIPPAGE_PIPS * 1.0 * position_lots
    commission = COMMISSION_PER_LOT * position_lots
    return spread_cost + slippage_cost + commission

# =================================
# DATA LOADING
# =================================

def load_data():
    print(f"Loading {CSV_PATH}...")
    df = pd.read_csv(CSV_PATH, sep=r'\s+', header=None,
                     names=['date', 'time', 'open', 'high', 'low', 'close', 'volume'])
    df['datetime'] = pd.to_datetime(df['date'] + ' ' + df['time'])
    df = df.drop(['date', 'time'], axis=1).sort_values('datetime').reset_index(drop=True)
    
    # Bollinger Bands
    df['bb_middle'] = df['close'].rolling(BB_PERIOD).mean()
    df['bb_std'] = df['close'].rolling(BB_PERIOD).std()
    df['bb_upper'] = df['bb_middle'] + (BB_STD * df['bb_std'])
    df['bb_lower'] = df['bb_middle'] - (BB_STD * df['bb_std'])
    
    # Additional metrics
    df['bb_width'] = df['bb_upper'] - df['bb_lower']
    df['bb_pct'] = (df['close'] - df['bb_lower']) / (df['bb_upper'] - df['bb_lower'])
    
    df['date'] = df['datetime'].dt.date
    df['is_trading_time'] = df['datetime'].apply(is_trading_time)
    
    print(f"Loaded {len(df):,} candles from {df['datetime'].min()} to {df['datetime'].max()}")
    return df

# =================================
# TRADING LOGIC
# =================================

class Trade:
    def __init__(self, entry_time, direction, entry_price, stop_loss, take_profit, position_size):
        self.entry_time = entry_time
        self.direction = direction
        self.entry_price = entry_price
        self.stop_loss = stop_loss
        self.take_profit = take_profit
        self.position_size = position_size
        self.exit_time = None
        self.exit_price = None
        self.result = None
        self.pnl_usd = 0.0
        self.pnl_pips = 0.0
        self.costs = 0.0

def check_entry_signal(df, idx):
    """Check for BB mean reversion entry"""
    if idx < BB_PERIOD + 5:
        return None
    
    current = df.iloc[idx]
    previous = df.iloc[idx-1]
    
    if pd.isna(current['bb_upper']) or pd.isna(current['bb_lower']):
        return None
    
    # Only trade when BB is not too narrow (avoid ranging markets)
    bb_width_pips = price_to_pips(current['bb_width'])
    if bb_width_pips < 15:  # Minimum width
        return None
    
    # Oversold - Buy signal
    # Price crossed below lower BB and now closing above it
    if (previous['close'] <= previous['bb_lower'] and 
        current['close'] > current['bb_lower'] and
        current['close'] < current['bb_middle']):  # Still below middle
        return 'long'
    
    # Overbought - Sell signal
    # Price crossed above upper BB and now closing below it
    if (previous['close'] >= previous['bb_upper'] and 
        current['close'] < current['bb_upper'] and
        current['close'] > current['bb_middle']):  # Still above middle
        return 'short'
    
    return None

def check_exit(trade, candle):
    """Check if trade should exit"""
    if trade.direction == 'long':
        # Stop loss hit
        if candle['low'] <= trade.stop_loss:
            trade.exit_price = trade.stop_loss
            trade.exit_time = candle['datetime']
            trade.result = 'SL'
            trade.pnl_pips = price_to_pips(trade.exit_price - trade.entry_price)
            trade.pnl_usd = trade.pnl_pips * 1.0 * trade.position_size - trade.costs
            return True
        # Take profit hit
        if candle['high'] >= trade.take_profit:
            trade.exit_price = trade.take_profit
            trade.exit_time = candle['datetime']
            trade.result = 'TP'
            trade.pnl_pips = price_to_pips(trade.exit_price - trade.entry_price)
            trade.pnl_usd = trade.pnl_pips * 1.0 * trade.position_size - trade.costs
            return True
        # Exit at BB middle (mean reversion completed)
        if not pd.isna(candle['bb_middle']) and candle['high'] >= candle['bb_middle']:
            trade.exit_price = candle['bb_middle']
            trade.exit_time = candle['datetime']
            trade.result = 'BB_Middle'
            trade.pnl_pips = price_to_pips(trade.exit_price - trade.entry_price)
            trade.pnl_usd = trade.pnl_pips * 1.0 * trade.position_size - trade.costs
            return True
    else:  # short
        # Stop loss hit
        if candle['high'] >= trade.stop_loss:
            trade.exit_price = trade.stop_loss
            trade.exit_time = candle['datetime']
            trade.result = 'SL'
            trade.pnl_pips = price_to_pips(trade.entry_price - trade.exit_price)
            trade.pnl_usd = trade.pnl_pips * 1.0 * trade.position_size - trade.costs
            return True
        # Take profit hit
        if candle['low'] <= trade.take_profit:
            trade.exit_price = trade.take_profit
            trade.exit_time = candle['datetime']
            trade.result = 'TP'
            trade.pnl_pips = price_to_pips(trade.entry_price - trade.exit_price)
            trade.pnl_usd = trade.pnl_pips * 1.0 * trade.position_size - trade.costs
            return True
        # Exit at BB middle (mean reversion completed)
        if not pd.isna(candle['bb_middle']) and candle['low'] <= candle['bb_middle']:
            trade.exit_price = candle['bb_middle']
            trade.exit_time = candle['datetime']
            trade.result = 'BB_Middle'
            trade.pnl_pips = price_to_pips(trade.entry_price - trade.exit_price)
            trade.pnl_usd = trade.pnl_pips * 1.0 * trade.position_size - trade.costs
            return True
    
    return False

# =================================
# BACKTESTER
# =================================

def run_backtest(df):
    print("\n" + "="*80)
    print("GOLD SCALPING BACKTEST - BOLLINGER BAND MEAN REVERSION")
    print("="*80)
    
    balance = INITIAL_BALANCE
    trades = []
    active_trade = None
    equity_curve = []
    daily_trades = {}
    daily_pnl = {}
    
    for idx in range(len(df)):
        if idx % 10000 == 0:
            print(f"Progress: {idx/len(df)*100:.0f}%")
        
        candle = df.iloc[idx]
        
        # Track equity
        if idx % 100 == 0:
            equity_curve.append({'datetime': candle['datetime'], 'balance': balance})
        
        # Check active trade exit
        if active_trade:
            if check_exit(active_trade, candle):
                balance += active_trade.pnl_usd
                trades.append(active_trade)
                day = candle['date']
                daily_pnl[day] = daily_pnl.get(day, 0) + active_trade.pnl_usd
                active_trade = None
            continue
        
        # Check trading conditions
        if not candle['is_trading_time'] or balance < MIN_BALANCE:
            continue
        
        day = candle['date']
        daily_trades[day] = daily_trades.get(day, 0)
        
        # Check daily limits
        if daily_trades[day] >= MAX_TRADES_PER_DAY:
            continue
        
        daily_loss = abs(min(0, daily_pnl.get(day, 0)))
        if daily_loss >= balance * MAX_DAILY_LOSS:
            continue
        
        # Check for entry signal
        signal = check_entry_signal(df, idx)
        if signal:
            position_size = calculate_position_size(balance, STOP_LOSS_PIPS)
            
            if position_size > 0:
                costs = calculate_costs(position_size)
                
                if signal == 'long':
                    entry_price = candle['close']
                    stop_loss = entry_price - pips_to_price(STOP_LOSS_PIPS)
                    take_profit = entry_price + pips_to_price(PROFIT_TARGET_PIPS)
                else:  # short
                    entry_price = candle['close']
                    stop_loss = entry_price + pips_to_price(STOP_LOSS_PIPS)
                    take_profit = entry_price - pips_to_price(PROFIT_TARGET_PIPS)
                
                active_trade = Trade(candle['datetime'], signal, entry_price, 
                                   stop_loss, take_profit, position_size)
                active_trade.costs = costs
                daily_trades[day] += 1
    
    # Close any remaining trade
    if active_trade:
        last = df.iloc[-1]
        active_trade.exit_time = last['datetime']
        active_trade.exit_price = last['close']
        active_trade.result = 'Timeout'
        if active_trade.direction == 'long':
            active_trade.pnl_pips = price_to_pips(active_trade.exit_price - active_trade.entry_price)
        else:
            active_trade.pnl_pips = price_to_pips(active_trade.entry_price - active_trade.exit_price)
        active_trade.pnl_usd = active_trade.pnl_pips * 1.0 * active_trade.position_size - active_trade.costs
        balance += active_trade.pnl_usd
        trades.append(active_trade)
    
    print_results(trades, balance, equity_curve)
    plot_equity(equity_curve)

def print_results(trades, final_balance, equity_curve):
    if not trades:
        print("\nNo trades generated!")
        return
    
    # Calculate metrics
    total_trades = len(trades)
    winners = [t for t in trades if t.pnl_usd > 0]
    losers = [t for t in trades if t.pnl_usd <= 0]
    
    win_rate = len(winners) / total_trades * 100
    total_pnl = sum(t.pnl_usd for t in trades)
    total_costs = sum(t.costs for t in trades)
    
    avg_win = sum(t.pnl_usd for t in winners) / len(winners) if winners else 0
    avg_loss = sum(t.pnl_usd for t in losers) / len(losers) if losers else 0
    
    profit_factor = (abs(sum(t.pnl_usd for t in winners)) / 
                    abs(sum(t.pnl_usd for t in losers))) if losers and sum(t.pnl_usd for t in losers) != 0 else 0
    
    # Max drawdown
    peak = INITIAL_BALANCE
    max_dd_pct = 0
    for point in equity_curve:
        if point['balance'] > peak:
            peak = point['balance']
        dd_pct = (peak - point['balance']) / peak * 100
        if dd_pct > max_dd_pct:
            max_dd_pct = dd_pct
    
    # Exit type breakdown
    exit_types = {}
    for t in trades:
        exit_types[t.result] = exit_types.get(t.result, 0) + 1
    
    # Print results
    print("\n" + "="*80)
    print("BACKTEST RESULTS - GOLD BOLLINGER BAND SCALPER")
    print("="*80)
    print(f"\nAccount Performance:")
    print(f"  Initial Balance:    ${INITIAL_BALANCE:,.2f}")
    print(f"  Final Balance:      ${final_balance:,.2f}")
    print(f"  Net P&L:            ${total_pnl:+,.2f}")
    print(f"  Return:             {(final_balance/INITIAL_BALANCE-1)*100:+.2f}%")
    print(f"  Max Drawdown:       {max_dd_pct:.2f}%")
    
    print(f"\nTrade Statistics:")
    print(f"  Total Trades:       {total_trades}")
    print(f"  Winners:            {len(winners)} ({win_rate:.1f}%)")
    print(f"  Losers:             {len(losers)} ({100-win_rate:.1f}%)")
    print(f"  Average Win:        ${avg_win:+.2f}")
    print(f"  Average Loss:       ${avg_loss:+.2f}")
    print(f"  Profit Factor:      {profit_factor:.2f}")
    
    print(f"\nExit Types:")
    for exit_type, count in sorted(exit_types.items(), key=lambda x: x[1], reverse=True):
        print(f"  {exit_type:15s}: {count} ({count/total_trades*100:.1f}%)")
    
    print(f"\nCosts (Realistic):")
    print(f"  Total Costs:        ${total_costs:,.2f}")
    print(f"  Avg Cost per Trade: ${total_costs/total_trades:.2f}")
    if total_pnl + total_costs > 0:
        print(f"  Cost % of Gross:    {total_costs/(total_pnl+total_costs)*100:.1f}%")
    
    print("\n" + "="*80)
    print("REALISTIC ASSESSMENT:")
    print("-"*80)
    
    if win_rate >= 55 and profit_factor >= 1.5 and max_dd_pct < 20:
        print("✓ Strategy shows reasonable performance")
        print("✓ Win rate and profit factor in acceptable range")
        print("✓ Consider demo testing with conservative parameters")
    elif win_rate >= 50 and profit_factor >= 1.3:
        print("⚠ Strategy shows marginal profitability")
        print("⚠ Results are borderline for live trading")
        print("⚠ Extended demo testing strongly recommended")
    else:
        print("✗ Strategy does not meet minimum profitability thresholds")
        print("✗ Win rate or profit factor too low")
        print("✗ Requires optimization or different approach")
    
    print("\nNOTE: Backtest results do NOT guarantee future performance!")
    print("Always test thoroughly on demo account before risking real money!")
    print("="*80)

def plot_equity(equity_curve):
    if not equity_curve:
        return
    
    eq_df = pd.DataFrame(equity_curve)
    
    plt.figure(figsize=(14, 6))
    plt.plot(eq_df['datetime'], eq_df['balance'], linewidth=2, color='blue', label='Balance')
    plt.axhline(INITIAL_BALANCE, color='gray', linestyle='--', alpha=0.7, label='Initial Balance')
    plt.title('Gold Scalper - Bollinger Band Strategy - Equity Curve', fontsize=14, fontweight='bold')
    plt.xlabel('Date', fontsize=12)
    plt.ylabel('Balance ($)', fontsize=12)
    plt.legend(fontsize=10)
    plt.grid(alpha=0.3)
    plt.tight_layout()
    plt.savefig('gold_scalper_equity.png', dpi=150)
    print(f"\nEquity curve saved to: gold_scalper_equity.png")

# =================================
# MAIN
# =================================

def main():
    df = load_data()
    run_backtest(df)

if __name__ == '__main__':
    main()
