#!/usr/bin/env python3
"""
ICT Backtest — FIXED & HIGH-FREQUENCY
Guaranteed trades on real EURUSD15 data
"""

import pandas as pd
import numpy as np
from datetime import datetime, time
import matplotlib.pyplot as plt
from typing import List, Dict, Optional
import warnings, os
warnings.filterwarnings('ignore')

# ============================================================================
# CONFIG — RELAXED + REALISTIC
# ============================================================================

CSV_PATH = "EURUSD15.csv"
INITIAL_BALANCE = 200.0
RISK_PER_TRADE = 0.015
MAX_TRADES_PER_DAY = 40

# === REAL TRADING SESSION (UTC) ===
LONDON_OPEN_UTC = time(7, 0)    # 8 AM London
LONDON_CLOSE_UTC = time(16, 0) # 5 PM London
NY_OPEN_UTC = time(12, 0)      # 8 AM NY
NY_CLOSE_UTC = time(21, 0)     # 5 PM NY

# === ICT THRESHOLDS (RELAXED FOR 15M) ===
MIN_FVG_PIPS = 2.0
SWEEP_REJECTION_PIPS = 0.5
STOP_LOSS_BUFFER_PIPS = 2.0
TARGET_MIN_R = 3.0
TARGET_MAX_R = 5.0

# === COSTS ===
BASE_SPREAD_PIPS = 0.6
SLIPPAGE_PIPS_BASE = 0.3
COMMISSION_PER_M = 7

# === SAFETY ===
MIN_BALANCE_THRESHOLD = 100.0
MAX_POSITION_UNITS = 100000
FVG_CONFIRMATION_CANDLES = 0   # ← FIXED: NO DELAY

RELAXED_MODE = True
DEBUG = False

# ============================================================================
# UTILITIES
# ============================================================================

def pips_to_price(p): return p * 0.0001
def price_to_pips(d): return d / 0.0001

def is_trading_session(dt: datetime) -> bool:
    t = dt.time()
    in_london = LONDON_OPEN_UTC <= t <= LONDON_CLOSE_UTC
    in_ny = NY_OPEN_UTC <= t <= NY_CLOSE_UTC
    return in_london or in_ny

# ============================================================================
# DATA LOADING
# ============================================================================

def load_data(filepath: str) -> pd.DataFrame:
    df = pd.read_csv(filepath, delim_whitespace=True,
                     header=None,
                     names=['date_part','time_part','open','high','low','close','volume'])
    df['datetime'] = pd.to_datetime(df['date_part'] + ' ' + df['time_part'])
    df = df.drop(['date_part','time_part'], axis=1)
    df = df.sort_values('datetime').reset_index(drop=True)
    df['date'] = df['datetime'].dt.date
    df['time'] = df['datetime'].dt.time
    df['is_session'] = df['datetime'].apply(is_trading_session)
    print(f"Loaded {len(df):,} candles – {df['datetime'].min()} → {df['datetime'].max()}")
    return df

# ============================================================================
# HIGHER-TF BIAS (1H)
# ============================================================================

def detect_1h_trend(df: pd.DataFrame, idx: int) -> str:
    look = min(32, idx)
    if look < 16: return 'neutral'
    sub = df.iloc[idx-look:idx]
    recent_h = sub.iloc[-8:]['high'].max()
    recent_l = sub.iloc[-8:]['low'].min()
    older_h = sub.iloc[:8]['high'].max()
    older_l = sub.iloc[:8]['low'].min()
    if recent_h > older_h and recent_l > older_l: return 'bullish'
    if recent_h < older_h and recent_l < older_l: return 'bearish'
    return 'neutral'

# ============================================================================
# SWEEP, MSS, FVG
# ============================================================================

def detect_liquidity_sweep(df: pd.DataFrame, idx: int) -> Optional[Dict]:
    if idx < 5: return None
    cur = df.iloc[idx]
    prev_h = df.iloc[idx-20:idx]['high']
    prev_l = df.iloc[idx-20:idx]['low']

    # Bearish sweep
    if cur['high'] > prev_h.max() and cur['close'] < cur['high'] - pips_to_price(SWEEP_REJECTION_PIPS):
        return {'type':'bear_sweep','price':cur['high'],'idx':idx}
    # Bullish sweep
    if cur['low'] < prev_l.min() and cur['close'] > cur['low'] + pips_to_price(SWEEP_REJECTION_PIPS):
        return {'type':'bull_sweep','price':cur['low'],'idx':idx}
    return None

def detect_mss(df: pd.DataFrame, sweep_idx: int, cur_idx: int, sweep_type: str) -> bool:
    if cur_idx <= sweep_idx: return False
    candles = df.iloc[sweep_idx:cur_idx+1]
    if sweep_type == 'bear_sweep':
        return candles.iloc[1:]['low'].min() < candles.iloc[0]['low']
    else:
        return candles.iloc[1:]['high'].max() > candles.iloc[0]['high']

def detect_fvg(df: pd.DataFrame, idx: int) -> Optional[Dict]:
    if idx < 2: return None
    c1, c2, c3 = df.iloc[idx-2], df.iloc[idx-1], df.iloc[idx]
    # Bullish FVG
    if c3['low'] > c1['high']:
        gap = c3['low'] - c1['high']
        if price_to_pips(gap) >= MIN_FVG_PIPS:
            return {'type':'bullish','bottom':c1['high'],'top':c3['low'],'idx':idx}
    # Bearish FVG
    if c3['high'] < c1['low']:
        gap = c1['low'] - c3['high']
        if price_to_pips(gap) >= MIN_FVG_PIPS:
            return {'type':'bearish','bottom':c3['high'],'top':c1['low'],'idx':idx}
    return None

# ============================================================================
# COSTS
# ============================================================================

def spread_pips(candle: pd.Series) -> float:
    vol = candle['volume']
    if vol > 300:   return BASE_SPREAD_PIPS
    if vol > 100:   return BASE_SPREAD_PIPS * 1.5
    return BASE_SPREAD_PIPS * 2.5

# Dynamic slippage
def slippage_pips(units: float) -> float:
    if units <= 50_000:   return 0.5
    if units <= 200_000:  return 1.0
    return min(3.0, units / 100_000 * 0.8)

def commission_usd(units: float) -> float:
    return COMMISSION_PER_M * (units / 1_000_000)

# ============================================================================
# TRADE CLASS
# ============================================================================

class Trade:
    def __init__(self, entry_time, entry_price, direction, sl, tp, size):
        self.entry_time = entry_time
        self.entry_price = entry_price
        self.direction = direction
        self.stop_loss = sl
        self.take_profit = tp
        self.position_size = min(size, MAX_POSITION_UNITS)
        self.exit_time = self.exit_price = None
        self.result = None
        self.pnl_pips = self.pnl_usd = 0.0

# ============================================================================
# POSITION SIZING
# ============================================================================

def calculate_position_size(balance: float, sl_pips: float) -> float:
    if balance <= 0 or sl_pips <= 0: return 0
    risk = balance * RISK_PER_TRADE
    size = risk / (sl_pips * 0.0001)
    return min(size, MAX_POSITION_UNITS)

# ============================================================================
# EXIT
# ============================================================================

def check_trade_exit(trade: Trade, candle: pd.Series) -> bool:
    pos = trade.position_size
    spr = spread_pips(candle)
    slp = slippage_pips(pos)
    comm = commission_usd(pos)

    if trade.direction == 'long':
        if candle['low'] <= trade.stop_loss:
            trade.exit_price = max(trade.stop_loss, candle['low']) - pips_to_price(slp)
            trade.exit_time = candle['datetime']
            trade.result = 'SL'
            trade.pnl_pips = -price_to_pips(trade.entry_price - trade.exit_price)
            trade.pnl_usd = trade.pnl_pips * 0.0001 * pos - comm
            return True
        if candle['high'] >= trade.take_profit:
            trade.exit_price = min(trade.take_profit, candle['high']) - pips_to_price(slp)
            trade.exit_time = candle['datetime']
            trade.result = 'TP'
            trade.pnl_pips = price_to_pips(trade.take_profit - trade.entry_price)
            trade.pnl_usd = trade.pnl_pips * 0.0001 * pos - comm
            return True
    else:
        if candle['high'] >= trade.stop_loss:
            trade.exit_price = min(trade.stop_loss, candle['high']) + pips_to_price(slp)
            trade.exit_time = candle['datetime']
            trade.result = 'SL'
            trade.pnl_pips = -price_to_pips(trade.exit_price - trade.entry_price)
            trade.pnl_usd = trade.pnl_pips * 0.0001 * pos - comm
            return True
        if candle['low'] <= trade.take_profit:
            trade.exit_price = max(trade.take_profit, candle['low']) + pips_to_price(slp)
            trade.exit_time = candle['datetime']
            trade.result = 'TP'
            trade.pnl_pips = price_to_pips(trade.entry_price - trade.exit_price)
            trade.pnl_usd = trade.pnl_pips * 0.0001 * pos - comm
            return True
    return False

# ============================================================================
# BACKTESTER
# ============================================================================

class ICTBacktester:
    def __init__(self, df, init_bal):
        self.df = df
        self.balance = init_bal
        self.initial = init_bal
        self.trades = []
        self.active = None
        self.equity = []
        self.daily_cnt = {}
        self.recent_sweeps = []

    def run(self):
        print("\n=== ICT BACKTEST — FIXED & WORKING ===\n")
        total = len(self.df)
        prog = max(1000, total//20)

        for i in range(total):
            if i % prog == 0:
                print(f"Progress: {i/total:.1%} ({i}/{total})")
            c = self.df.iloc[i]

            if i % 100 == 0 or i == total-1:
                self.equity.append({'dt':c['datetime'], 'eq':self.balance})

            if self.active and check_trade_exit(self.active, c):
                self.balance += self.active.pnl_usd
                self.trades.append(self.active)
                print(f"Trade #{len(self.trades)} closed: {self.active.result} | "
                      f"{self.active.pnl_pips:+.1f} pips | ${self.active.pnl_usd:,.0f}")
                self.active = None
                continue

            if not c['is_session'] or self.balance < MIN_BALANCE_THRESHOLD:
                continue

            day = c['date']
            self.daily_cnt[day] = self.daily_cnt.get(day, 0)
            if self.daily_cnt[day] >= MAX_TRADES_PER_DAY:
                continue

            trade = self.check_entry(i)
            if trade:
                self.active = trade
                self.daily_cnt[day] += 1
                print(f"\nTrade #{len(self.trades)+1} opened at {trade.entry_time}")
                print(f"  {trade.direction.upper()} | Entry: {trade.entry_price:.5f} | "
                      f"SL: {trade.stop_loss:.5f} ({price_to_pips(abs(trade.entry_price-trade.stop_loss)):.1f}p) | "
                      f"TP: {trade.take_profit:.5f}")

        if self.active:
            last = self.df.iloc[-1]
            self.active.exit_time = last['datetime']
            self.active.exit_price = last['close']
            self.active.result = 'Timeout'
            self.active.pnl_pips = price_to_pips(
                self.active.exit_price - self.active.entry_price
                if self.active.direction == 'long' else
                self.active.entry_price - self.active.exit_price
            )
            self.active.pnl_usd = self.active.pnl_pips * 0.0001 * self.active.position_size
            self.balance += self.active.pnl_usd
            self.trades.append(self.active)

        self.summary()

    def check_entry(self, idx: int) -> Optional[Trade]:
        if idx < 50: return None
        c = self.df.iloc[idx]
        trend = detect_1h_trend(self.df, idx)
        if trend == 'neutral' and not RELAXED_MODE: return None

        sweep = detect_liquidity_sweep(self.df, idx)
        if sweep:
            sweep['trend'] = trend
            sweep['detected'] = idx
            self.recent_sweeps = [s for s in self.recent_sweeps if idx - s['detected'] <= 30]
            self.recent_sweeps.append(sweep)

        for sw in self.recent_sweeps[:]:
            if idx < sw['idx'] + 1: continue
            if trend != 'neutral' and sw['trend'] != trend: continue
            if not detect_mss(self.df, sw['idx'], idx, sw['type']): continue

            fvg = detect_fvg(self.df, idx)
            if not fvg: continue
            if idx - fvg['idx'] < FVG_CONFIRMATION_CANDLES: continue

            expected = 'bullish' if sw['type'] == 'bull_sweep' else 'bearish'
            if fvg['type'] != expected: continue

            self.recent_sweeps.remove(sw)
            return self.build_trade(idx, expected, sw, fvg)
        return None

    def build_trade(self, idx: int, direction: str, sweep: Dict, fvg: Dict) -> Trade:
        c = self.df.iloc[idx]
        spr = spread_pips(c)

        if direction == 'bullish':
            entry = fvg['bottom'] + pips_to_price(spr)
            sl = sweep['price'] - pips_to_price(STOP_LOSS_BUFFER_PIPS)
            sl_pips = price_to_pips(entry - sl)
            rr = np.random.uniform(TARGET_MIN_R, TARGET_MAX_R)
            tp = entry + sl_pips * rr * 0.0001
        else:
            entry = fvg['top'] - pips_to_price(spr)
            sl = sweep['price'] + pips_to_price(STOP_LOSS_BUFFER_PIPS)
            sl_pips = price_to_pips(sl - entry)
            rr = np.random.uniform(TARGET_MIN_R, TARGET_MAX_R)
            tp = entry - sl_pips * rr * 0.0001

        pos = calculate_position_size(self.balance, sl_pips)
        return Trade(c['datetime'], entry, direction, sl, tp, pos)

    def summary(self):
        if not self.trades:
            print("No trades generated.")
            return

        df = pd.DataFrame([{'pnl': t.pnl_usd, 'res': t.result} for t in self.trades])
        wins = df[df['pnl'] > 0]
        loss = df[df['pnl'] <= 0]
        win_rate = len(wins)/len(df)*100
        avg_r = abs(wins['pnl'].mean() / loss['pnl'].mean()) if len(loss) else 0

        peak = self.initial
        maxdd = 0
        for e in self.equity:
            if e['eq'] > peak: peak = e['eq']
            dd = (peak - e['eq'])/peak*100
            if dd > maxdd: maxdd = dd

        print("\n" + "="*80)
        print("BACKTEST SUMMARY")
        print("="*80)
        print(f"Total Trades     : {len(self.trades)}")
        print(f"Win Rate         : {win_rate:.1f}%")
        print(f"Avg R:R          : {avg_r:.2f}")
        print(f"Total P&L        : ${self.balance - self.initial:,.2f}")
        print(f"Return           : {(self.balance/self.initial-1)*100:,.1f}%")
        print(f"Max Drawdown     : {maxdd:.2f}%")
        print(f"Ending Balance   : ${self.balance:,.2f}")
        print("="*80)

        eq = pd.DataFrame(self.equity)
        plt.figure(figsize=(12,6))
        plt.plot(eq['dt'], eq['eq'], label='Equity')
        plt.axhline(self.initial, color='gray', linestyle='--')
        plt.title('ICT Backtest Equity Curve')
        plt.legend(); plt.grid(alpha=0.3)
        plt.tight_layout()
        plt.savefig('equity_fixed.png', dpi=180)
        print("Equity curve → equity_fixed.png")

# ============================================================================
# MAIN
# ============================================================================

def main():
    df = load_data(CSV_PATH)
    bt = ICTBacktester(df, INITIAL_BALANCE)
    bt.run()

if __name__ == '__main__':
    main()