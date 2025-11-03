#!/usr/bin/env python3
"""
Gold (XAUUSD) Scalping Strategy - Simple Momentum System
========================================================

A practical scalping strategy for Gold (XAUUSD) using 5-minute candles.
Trades momentum moves with proper risk management and realistic costs.

Key Features:
- Simple momentum-based entries
- Conservative profit targets
- Strict risk management
- Realistic trading costs modeled

NOTE: This prioritizes REALISTIC results over impressive backtest returns.
"""

import pandas as pd
import numpy as np
from datetime import datetime, time
import matplotlib.pyplot as plt
import warnings
warnings.filterwarnings('ignore')

# =================================
# CONFIGURATION
# =================================

CSV_PATH = "XAUUSD5.csv"
INITIAL_BALANCE = 10000.0

# Risk Management
RISK_PER_TRADE = 0.01       # 1% risk per trade
MAX_TRADES_PER_DAY = 4
MAX_DAILY_LOSS = 0.03       # 3%

# Trading Hours (UTC)
TRADING_START = time(8, 0)
TRADING_END = time(19, 0)

# Entry Parameters
MOMENTUM_CANDLES = 2        # Consecutive candles in same direction
MIN_CANDLE_BODY = 0.8       # Minimum candle body size ($)
REQUIRE_STRONG_CANDLE = True  # Require strong momentum candle

# Exit Parameters
PROFIT_TARGET_DOLLARS = 10.0  # Take profit in dollars
STOP_LOSS_DOLLARS = 7.0       # Stop loss in dollars

# Costs (REALISTIC for Gold)
SPREAD_DOLLARS = 0.40      # $0.40 spread per unit
SLIPPAGE_DOLLARS = 0.25    # $0.25 slippage
COMMISSION_PER_LOT = 7.0   # $7 commission per lot

# Position Sizing
# For gold: 1 lot = 100 oz
# $1 move = $100 per lot
MIN_BALANCE = 5000.0
MAX_POSITION_LOTS = 8.0

# =================================
# UTILITIES
# =================================

def is_trading_time(dt):
    t = dt.time()
    return TRADING_START <= t <= TRADING_END

def calculate_position_size(balance, stop_dollars):
    """
    Position sizing based on risk %
    For gold: $1 move in price = $100 move per lot
    """
    if balance <= 0 or stop_dollars <= 0:
        return 0.0
    risk_amount = balance * RISK_PER_TRADE
    # Convert stop in dollars to position size
    # If stop is $8 and we risk $100, position = $100 / ($8 * $100/lot) = 0.125 lots
    position_lots = risk_amount / (stop_dollars * 100)
    return min(position_lots, MAX_POSITION_LOTS)

def calculate_costs(position_lots):
    """Calculate all trading costs"""
    spread_cost = SPREAD_DOLLARS * 100 * position_lots
    slippage_cost = SLIPPAGE_DOLLARS * 100 * position_lots
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
    
    # Add simple metrics
    df['candle_body'] = abs(df['close'] - df['open'])
    df['is_bullish'] = df['close'] > df['open']
    df['is_bearish'] = df['close'] < df['open']
    
    # Simple moving average for trend filter
    df['sma_20'] = df['close'].rolling(20).mean()
    
    df['date'] = df['datetime'].dt.date
    df['is_trading_time'] = df['datetime'].apply(is_trading_time)
    
    print(f"Loaded {len(df):,} candles: {df['datetime'].min()} to {df['datetime'].max()}")
    print(f"Price range: ${df['close'].min():.2f} to ${df['close'].max():.2f}")
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
        self.pnl_dollars = 0.0
        self.costs = 0.0

def check_momentum_entry(df, idx):
    """Check for momentum entry signal"""
    if idx < 25:  # Need history
        return None
    
    current = df.iloc[idx]
    
    # Skip if SMA not ready
    if pd.isna(current['sma_20']):
        return None
    
    # Check last N candles for momentum
    lookback = df.iloc[idx-MOMENTUM_CANDLES:idx+1]
    
    bullish_count = lookback['is_bullish'].sum()
    bearish_count = lookback['is_bearish'].sum()
    
    # Check current candle body size (avoid doji/small candles)
    if current['candle_body'] < MIN_CANDLE_BODY:
        return None
    
    # Calculate strength of current candle
    candle_range = current['high'] - current['low']
    if candle_range <= 0:
        return None
    body_ratio = current['candle_body'] / candle_range
    
    # Require strong candle (body is majority of range, not lots of wicks)
    if REQUIRE_STRONG_CANDLE and body_ratio < 0.6:
        return None
    
    # Bullish momentum + above SMA
    if (bullish_count >= MOMENTUM_CANDLES and
        current['close'] > current['sma_20'] and
        current['is_bullish']):  # Current candle must also be bullish
        return 'long'
    
    # Bearish momentum + below SMA
    if (bearish_count >= MOMENTUM_CANDLES and
        current['close'] < current['sma_20'] and
        current['is_bearish']):  # Current candle must also be bearish
        return 'short'
    
    return None

def check_exit(trade, candle):
    """Check if trade should exit"""
    if trade.direction == 'long':
        if candle['low'] <= trade.stop_loss:
            trade.exit_price = trade.stop_loss
            trade.exit_time = candle['datetime']
            trade.result = 'SL'
            price_move = trade.exit_price - trade.entry_price
            trade.pnl_dollars = price_move
            trade.pnl_usd = price_move * 100 * trade.position_size - trade.costs
            return True
        if candle['high'] >= trade.take_profit:
            trade.exit_price = trade.take_profit
            trade.exit_time = candle['datetime']
            trade.result = 'TP'
            price_move = trade.exit_price - trade.entry_price
            trade.pnl_dollars = price_move
            trade.pnl_usd = price_move * 100 * trade.position_size - trade.costs
            return True
    else:  # short
        if candle['high'] >= trade.stop_loss:
            trade.exit_price = trade.stop_loss
            trade.exit_time = candle['datetime']
            trade.result = 'SL'
            price_move = trade.entry_price - trade.exit_price
            trade.pnl_dollars = price_move
            trade.pnl_usd = price_move * 100 * trade.position_size - trade.costs
            return True
        if candle['low'] <= trade.take_profit:
            trade.exit_price = trade.take_profit
            trade.exit_time = candle['datetime']
            trade.result = 'TP'
            price_move = trade.entry_price - trade.exit_price
            trade.pnl_dollars = price_move
            trade.pnl_usd = price_move * 100 * trade.position_size - trade.costs
            return True
    
    return False

# =================================
# BACKTESTER
# =================================

def run_backtest(df):
    print("\n" + "="*80)
    print("GOLD SCALPING BACKTEST - MOMENTUM SYSTEM")
    print("="*80)
    print(f"Period: {df['datetime'].min()} to {df['datetime'].max()}")
    print(f"Initial Balance: ${INITIAL_BALANCE:,.2f}")
    print(f"Risk per Trade: {RISK_PER_TRADE*100:.1f}%")
    print("="*80 + "\n")
    
    balance = INITIAL_BALANCE
    trades = []
    active_trade = None
    equity_curve = []
    daily_trades = {}
    daily_pnl = {}
    
    for idx in range(len(df)):
        if idx % 10000 == 0:
            pct = idx / len(df) * 100
            print(f"Progress: {pct:.0f}% | Balance: ${balance:,.2f} | Trades: {len(trades)}")
        
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
        signal = check_momentum_entry(df, idx)
        if signal:
            position_size = calculate_position_size(balance, STOP_LOSS_DOLLARS)
            
            if position_size > 0:
                costs = calculate_costs(position_size)
                
                entry_price = candle['close']
                
                if signal == 'long':
                    stop_loss = entry_price - STOP_LOSS_DOLLARS
                    take_profit = entry_price + PROFIT_TARGET_DOLLARS
                else:  # short
                    stop_loss = entry_price + STOP_LOSS_DOLLARS
                    take_profit = entry_price - PROFIT_TARGET_DOLLARS
                
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
            price_move = active_trade.exit_price - active_trade.entry_price
        else:
            price_move = active_trade.entry_price - active_trade.exit_price
        active_trade.pnl_dollars = price_move
        active_trade.pnl_usd = price_move * 100 * active_trade.position_size - active_trade.costs
        balance += active_trade.pnl_usd
        trades.append(active_trade)
    
    print_results(trades, balance, equity_curve)
    plot_equity(equity_curve)

def print_results(trades, final_balance, equity_curve):
    if not trades:
        print("\n⚠ WARNING: No trades generated!")
        return
    
    # Calculate metrics
    total_trades = len(trades)
    winners = [t for t in trades if t.pnl_usd > 0]
    losers = [t for t in trades if t.pnl_usd <= 0]
    
    win_rate = len(winners) / total_trades * 100 if total_trades > 0 else 0
    total_pnl = sum(t.pnl_usd for t in trades)
    total_costs = sum(t.costs for t in trades)
    
    avg_win = sum(t.pnl_usd for t in winners) / len(winners) if winners else 0
    avg_loss = sum(t.pnl_usd for t in losers) / len(losers) if losers else 0
    
    sum_wins = sum(t.pnl_usd for t in winners)
    sum_losses = abs(sum(t.pnl_usd for t in losers))
    profit_factor = sum_wins / sum_losses if sum_losses > 0 else 0
    
    # Max drawdown
    peak = INITIAL_BALANCE
    max_dd_pct = 0
    max_dd_usd = 0
    for point in equity_curve:
        if point['balance'] > peak:
            peak = point['balance']
        dd_usd = peak - point['balance']
        dd_pct = dd_usd / peak * 100 if peak > 0 else 0
        if dd_pct > max_dd_pct:
            max_dd_pct = dd_pct
            max_dd_usd = dd_usd
    
    # Exit breakdown
    exit_types = {}
    for t in trades:
        exit_types[t.result] = exit_types.get(t.result, 0) + 1
    
    # Print results
    print("\n" + "="*80)
    print("BACKTEST RESULTS - GOLD MOMENTUM SCALPER")
    print("="*80)
    
    print(f"\n📊 ACCOUNT PERFORMANCE")
    print("-" * 80)
    print(f"  Initial Balance:       ${INITIAL_BALANCE:,.2f}")
    print(f"  Final Balance:         ${final_balance:,.2f}")
    print(f"  Net P&L:               ${total_pnl:+,.2f}")
    print(f"  Return:                {(final_balance/INITIAL_BALANCE-1)*100:+.2f}%")
    print(f"  Max Drawdown:          ${max_dd_usd:,.2f} ({max_dd_pct:.2f}%)")
    
    print(f"\n📈 TRADE STATISTICS")
    print("-" * 80)
    print(f"  Total Trades:          {total_trades}")
    print(f"  Winning Trades:        {len(winners)} ({win_rate:.1f}%)")
    print(f"  Losing Trades:         {len(losers)} ({100-win_rate:.1f}%)")
    print(f"  Average Win:           ${avg_win:+.2f}")
    print(f"  Average Loss:          ${avg_loss:+.2f}")
    if winners:
        print(f"  Largest Win:           ${max(winners, key=lambda t: t.pnl_usd).pnl_usd:+.2f}")
    if losers:
        print(f"  Largest Loss:          ${min(losers, key=lambda t: t.pnl_usd).pnl_usd:+.2f}")
    print(f"  Profit Factor:         {profit_factor:.2f}")
    
    print(f"\n🎯 EXIT BREAKDOWN")
    print("-" * 80)
    for exit_type, count in sorted(exit_types.items(), key=lambda x: x[1], reverse=True):
        print(f"  {exit_type:15s}        {count:3d} ({count/total_trades*100:5.1f}%)")
    
    print(f"\n💰 COSTS")
    print("-" * 80)
    print(f"  Total Costs:           ${total_costs:,.2f}")
    print(f"  Avg Cost per Trade:    ${total_costs/total_trades:.2f}")
    if total_pnl + total_costs > 0:
        print(f"  Cost as % of Gross:    {total_costs/(total_pnl+total_costs)*100:.1f}%")
    
    print("\n" + "="*80)
    print("⚖️  REALISTIC ASSESSMENT")
    print("="*80)
    
    if win_rate >= 55 and profit_factor >= 1.5 and max_dd_pct < 20 and total_pnl > 0:
        print("\n✓ PROMISING RESULTS")
        print("  • Strategy shows potential profitability")
        print("  • Win rate and profit factor are acceptable")
        print("  • Test on demo account before live trading")
    elif win_rate >= 50 and profit_factor >= 1.3 and total_pnl > 0:
        print("\n⚠ MARGINAL PROFITABILITY")
        print("  • Results are borderline")
        print("  • Extended demo testing recommended")
    else:
        print("\n✗ BELOW THRESHOLD")
        print("  • Strategy needs improvement")
        print("  • Not recommended for live trading")
    
    print("\n⚠️  DISCLAIMER: Past performance ≠ Future results")
    print("="*80 + "\n")

def plot_equity(equity_curve):
    if not equity_curve:
        return
    
    eq_df = pd.DataFrame(equity_curve)
    
    plt.figure(figsize=(14, 6))
    plt.plot(eq_df['datetime'], eq_df['balance'], linewidth=2, color='#2E86AB')
    plt.axhline(INITIAL_BALANCE, color='gray', linestyle='--', alpha=0.7, label='Initial')
    plt.title('Gold Scalper - Equity Curve', fontsize=14, fontweight='bold')
    plt.xlabel('Date')
    plt.ylabel('Balance ($)')
    plt.legend()
    plt.grid(alpha=0.3)
    plt.tight_layout()
    plt.savefig('gold_scalper_equity.png', dpi=150)
    print("📊 Equity curve saved: gold_scalper_equity.png\n")

# =================================
# MAIN
# =================================

def main():
    print("\n" + "="*80)
    print("GOLD (XAUUSD) SCALPING STRATEGY BACKTEST")
    print("Simple Momentum System with Realistic Costs")
    print("="*80 + "\n")
    
    df = load_data()
    run_backtest(df)

if __name__ == '__main__':
    main()
