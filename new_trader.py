#!/usr/bin/env python3
"""
ICT (Inner Circle Trader) Smart Money Backtest System
Implements a strict ICT strategy backtest on EURUSD 15-minute data
"""

import pandas as pd
import numpy as np
from datetime import datetime, time
import matplotlib.pyplot as plt
from typing import List, Dict, Tuple, Optional
import warnings
warnings.filterwarnings('ignore')

# ============================================================================
# CONFIGURATION
# ============================================================================

CSV_PATH = "EURUSD15.csv"           # Your data file
INITIAL_BALANCE = 10000.0            # Starting capital
RISK_PER_TRADE = 0.01                # 1% risk per trade

# Session times (UTC)
LONDON_NY_START = time(7, 0)         # 07:00 UTC
LONDON_NY_END = time(16, 0)          # 16:00 UTC

# Trading parameters
MAX_TRADES_PER_DAY = 5                # Increased from 2 to allow more opportunities
MIN_FVG_PIPS = 3                      # Reduced from 5 to capture smaller but valid FVGs
STOP_LOSS_BUFFER_PIPS = 2             # Buffer beyond sweep extreme
TARGET_MIN_R = 3.0                    # Minimum risk-reward ratio
TARGET_MAX_R = 5.0                    # Maximum risk-reward ratio

# Chart generation
GENERATE_TRADE_CHARTS = True          # Generate candlestick charts for each trade
TRADE_CHARTS_FOLDER = "trade_charts"  # Folder to save trade charts

# Swing detection parameters
SWING_LOOKBACK = 3                    # Reduced from 5 - more sensitive swing detection
SWEEP_REJECTION_PIPS = 2              # Reduced from 3 - minimum rejection size for sweep

# Debug mode - set to True to see detailed pattern detection
DEBUG = False

# Relaxed mode - set to True to allow neutral trend entries (less strict)
RELAXED_MODE = True                   # Enabled by default for more trading opportunities

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

def pips_to_price(pips: float) -> float:
    """Convert pips to price for EURUSD"""
    return pips * 0.0001

def price_to_pips(price_diff: float) -> float:
    """Convert price difference to pips for EURUSD"""
    return price_diff / 0.0001

def is_trading_session(dt: datetime) -> bool:
    """Check if datetime is within London + New York session"""
    t = dt.time()
    return LONDON_NY_START <= t <= LONDON_NY_END

# ============================================================================
# DATA LOADING
# ============================================================================

def load_data(filepath: str) -> pd.DataFrame:
    """Load and prepare EURUSD 15M data"""
    print(f"Loading data from {filepath}...")
    
    # Load CSV without header, combining first two columns as datetime
    df = pd.read_csv(
        filepath,
        header=None,
        sep=r'\s+',
        names=['date_part', 'time_part', 'open', 'high', 'low', 'close', 'volume']
    )
    
    # Combine date and time columns
    df['datetime'] = pd.to_datetime(df['date_part'] + ' ' + df['time_part'])
    df = df.drop(['date_part', 'time_part'], axis=1)
    
    df = df.sort_values('datetime').reset_index(drop=True)
    df['date'] = df['datetime'].dt.date
    df['time'] = df['datetime'].dt.time
    df['is_session'] = df['datetime'].apply(is_trading_session)
    
    print(f"Loaded {len(df)} candles from {df['datetime'].min()} to {df['datetime'].max()}")
    return df

# ============================================================================
# HIGHER TIMEFRAME TREND BIAS
# ============================================================================

def detect_1h_trend(df: pd.DataFrame, current_idx: int) -> str:
    """
    Detect 1-hour trend bias using swing highs/lows
    Returns: 'bullish', 'bearish', or 'neutral'
    """
    # Get last 4 hours of data (16 candles)
    lookback = min(32, current_idx)
    if lookback < 16:
        return 'neutral'
    
    subset = df.iloc[current_idx - lookback:current_idx]
    
    # Simple trend detection: compare recent prices to older prices
    recent_high = subset.iloc[-8:]['high'].max()
    recent_low = subset.iloc[-8:]['low'].min()
    older_high = subset.iloc[:8]['high'].max()
    older_low = subset.iloc[:8]['low'].min()
    
    # Higher highs and higher lows = bullish
    if recent_high > older_high and recent_low > older_low:
        return 'bullish'
    
    # Lower highs and lower lows = bearish
    if recent_high < older_high and recent_low < older_low:
        return 'bearish'
    
    return 'neutral'

# ============================================================================
# LIQUIDITY SWEEP DETECTION
# ============================================================================

def detect_liquidity_sweep(df: pd.DataFrame, current_idx: int) -> Optional[Dict]:
    """
    Detect liquidity sweep (new swing high or low)
    Returns: {'type': 'bull_sweep' or 'bear_sweep', 'price': float, 'idx': int} or None
    """
    lookback = min(15, current_idx)
    if lookback < 5:
        return None
    
    current = df.iloc[current_idx]
    prev_highs = df.iloc[current_idx - lookback:current_idx]['high']
    prev_lows = df.iloc[current_idx - lookback:current_idx]['low']
    
    # Bear sweep: price makes new high then rejects
    if current['high'] > prev_highs.max():
        # Check for rejection (close below high)
        if current['close'] < current['high'] - pips_to_price(SWEEP_REJECTION_PIPS):
            return {
                'type': 'bear_sweep',
                'price': current['high'],
                'idx': current_idx
            }
    
    # Bull sweep: price makes new low then rejects
    if current['low'] < prev_lows.min():
        # Check for rejection (close above low)
        if current['close'] > current['low'] + pips_to_price(SWEEP_REJECTION_PIPS):
            return {
                'type': 'bull_sweep',
                'price': current['low'],
                'idx': current_idx
            }
    
    return None

# ============================================================================
# MARKET STRUCTURE SHIFT (MSS)
# ============================================================================

def detect_mss(df: pd.DataFrame, sweep_idx: int, current_idx: int, sweep_type: str) -> bool:
    """
    Detect Market Structure Shift after a liquidity sweep
    """
    if current_idx <= sweep_idx + 1:
        return False
    
    # Get candles since sweep
    candles_since_sweep = df.iloc[sweep_idx:current_idx + 1]
    
    if sweep_type == 'bear_sweep':
        # For bearish MSS, need break below recent structure
        sweep_low = candles_since_sweep.iloc[0]['low']
        recent_lows = candles_since_sweep.iloc[1:]['low']
        if len(recent_lows) > 0 and recent_lows.min() < sweep_low - pips_to_price(5):
            return True
    
    elif sweep_type == 'bull_sweep':
        # For bullish MSS, need break above recent structure
        sweep_high = candles_since_sweep.iloc[0]['high']
        recent_highs = candles_since_sweep.iloc[1:]['high']
        if len(recent_highs) > 0 and recent_highs.max() > sweep_high + pips_to_price(5):
            return True
    
    return False

# ============================================================================
# FAIR VALUE GAP (FVG) DETECTION
# ============================================================================

def detect_fvg(df: pd.DataFrame, current_idx: int) -> Optional[Dict]:
    """
    Detect Fair Value Gap (3-candle imbalance)
    Returns: {'type': 'bullish' or 'bearish', 'top': float, 'bottom': float, 'idx': int} or None
    """
    if current_idx < 2:
        return None
    
    candle1 = df.iloc[current_idx - 2]
    candle2 = df.iloc[current_idx - 1]
    candle3 = df.iloc[current_idx]
    
    # Bullish FVG: gap between candle1 high and candle3 low
    if candle3['low'] > candle1['high']:
        gap_size = candle3['low'] - candle1['high']
        if price_to_pips(gap_size) >= MIN_FVG_PIPS:
            return {
                'type': 'bullish',
                'bottom': candle1['high'],
                'top': candle3['low'],
                'idx': current_idx
            }
    
    # Bearish FVG: gap between candle1 low and candle3 high
    if candle3['high'] < candle1['low']:
        gap_size = candle1['low'] - candle3['high']
        if price_to_pips(gap_size) >= MIN_FVG_PIPS:
            return {
                'type': 'bearish',
                'bottom': candle3['high'],
                'top': candle1['low'],
                'idx': current_idx
            }
    
    return None

# ============================================================================
# ORDER BLOCK DETECTION
# ============================================================================

def detect_order_block(df: pd.DataFrame, current_idx: int, direction: str) -> bool:
    """
    Detect order block (consolidation before move)
    Simplified version: check for recent consolidation
    """
    lookback = min(10, current_idx)
    if lookback < 5:
        return False
    
    recent = df.iloc[current_idx - lookback:current_idx]
    
    # Check for consolidation (small range)
    avg_range = (recent['high'] - recent['low']).mean()
    if price_to_pips(avg_range) < 15:  # Small average range
        return True
    
    return False

# ============================================================================
# DISCRETION FILTERS
# ============================================================================

def is_messy_candle_cluster(df: pd.DataFrame, current_idx: int) -> bool:
    """Check if recent candles are messy (overlapping small ranges)"""
    lookback = min(5, current_idx)
    if lookback < 3:
        return False
    
    recent = df.iloc[current_idx - lookback:current_idx + 1]
    ranges = recent['high'] - recent['low']
    
    # If average range is very small, consider it messy
    avg_range = ranges.mean()
    if price_to_pips(avg_range) < 8:
        return True
    
    return False

def is_low_liquidity(df: pd.DataFrame, current_idx: int) -> bool:
    """Check if current period has low liquidity (low volume)"""
    lookback = min(10, current_idx)
    if lookback < 5:
        return False
    
    recent = df.iloc[current_idx - lookback:current_idx + 1]
    avg_volume = recent['volume'].mean()
    
    # If volume is very low, skip
    if avg_volume < 50:  # Threshold for low liquidity
        return True
    
    return False

# ============================================================================
# TRADE MANAGEMENT
# ============================================================================

class Trade:
    """Represents a single trade"""
    def __init__(self, entry_time, entry_price, direction, stop_loss, take_profit, position_size):
        self.entry_time = entry_time
        self.entry_price = entry_price
        self.direction = direction  # 'long' or 'short'
        self.stop_loss = stop_loss
        self.take_profit = take_profit
        self.position_size = position_size
        
        self.exit_time = None
        self.exit_price = None
        self.result = None  # 'TP', 'SL', 'Timeout'
        self.pnl_pips = 0
        self.pnl_usd = 0

def calculate_position_size(balance: float, risk_pct: float, sl_pips: float) -> float:
    """Calculate position size based on risk and SL distance"""
    # Safeguards against invalid values
    if balance <= 0 or np.isnan(balance) or np.isinf(balance):
        return 0
    
    if sl_pips <= 0 or np.isnan(sl_pips) or np.isinf(sl_pips):
        return 0
    
    # Minimum SL must be at least 1 pip
    sl_pips = max(sl_pips, 1.0)
    
    risk_amount = balance * risk_pct
    # For EURUSD, 1 pip = $0.0001 per unit
    # Position size = Risk Amount / (SL in pips * pip value)
    pip_value = 0.0001
    position_size = risk_amount / (sl_pips * pip_value)
    
    # Additional safeguard against unreasonably large position sizes
    if np.isnan(position_size) or np.isinf(position_size):
        return 0
    
    return position_size

def check_trade_exit(trade: Trade, candle: pd.Series) -> bool:
    """Check if trade should be exited (TP or SL hit)"""
    if trade.direction == 'long':
        # Check stop loss
        if candle['low'] <= trade.stop_loss:
            trade.exit_price = trade.stop_loss
            trade.exit_time = candle['datetime']
            trade.result = 'SL'
            trade.pnl_pips = -abs(price_to_pips(trade.entry_price - trade.stop_loss))
            trade.pnl_usd = trade.pnl_pips * 0.0001 * trade.position_size
            return True
        
        # Check take profit
        if candle['high'] >= trade.take_profit:
            trade.exit_price = trade.take_profit
            trade.exit_time = candle['datetime']
            trade.result = 'TP'
            trade.pnl_pips = price_to_pips(trade.take_profit - trade.entry_price)
            trade.pnl_usd = trade.pnl_pips * 0.0001 * trade.position_size
            return True
    
    else:  # short
        # Check stop loss
        if candle['high'] >= trade.stop_loss:
            trade.exit_price = trade.stop_loss
            trade.exit_time = candle['datetime']
            trade.result = 'SL'
            trade.pnl_pips = -abs(price_to_pips(trade.stop_loss - trade.entry_price))
            trade.pnl_usd = trade.pnl_pips * 0.0001 * trade.position_size
            return True
        
        # Check take profit
        if candle['low'] <= trade.take_profit:
            trade.exit_price = trade.take_profit
            trade.exit_time = candle['datetime']
            trade.result = 'TP'
            trade.pnl_pips = price_to_pips(trade.entry_price - trade.take_profit)
            trade.pnl_usd = trade.pnl_pips * 0.0001 * trade.position_size
            return True
    
    return False

# ============================================================================
# BACKTEST ENGINE
# ============================================================================

class ICTBacktester:
    """Main backtesting engine for ICT strategy"""
    
    def __init__(self, df: pd.DataFrame, initial_balance: float):
        self.df = df
        self.initial_balance = initial_balance
        self.balance = initial_balance
        
        self.trades: List[Trade] = []
        self.active_trade: Optional[Trade] = None
        self.equity_curve = []
        
        # Tracking
        self.daily_trades = {}
        self.recent_sweeps = []  # Store recent sweeps (last 20 candles)
    
    def run(self):
        """Execute the backtest bar-by-bar"""
        print("\nStarting ICT backtest...")
        print(f"Initial balance: ${self.initial_balance:,.2f}")
        print("=" * 80)
        
        total_candles = len(self.df)
        print_interval = max(1000, total_candles // 20)  # Print progress every 5%
        
        for idx in range(len(self.df)):
            # Progress indicator
            if idx > 0 and idx % print_interval == 0:
                progress = (idx / total_candles) * 100
                print(f"Progress: {progress:.1f}% ({idx}/{total_candles} candles)")
            
            candle = self.df.iloc[idx]
            
            # Update equity curve (sample every 100 candles to reduce memory)
            if idx % 100 == 0 or idx == len(self.df) - 1:
                self.equity_curve.append({
                    'datetime': candle['datetime'],
                    'equity': self.balance
                })
            
            # Check active trade for exit
            if self.active_trade:
                if check_trade_exit(self.active_trade, candle):
                    # Safeguard against NaN in P&L
                    if np.isnan(self.active_trade.pnl_usd) or np.isinf(self.active_trade.pnl_usd):
                        print(f"WARNING: Trade #{len(self.trades) + 1} has invalid P&L (NaN/Inf), skipping balance update")
                        self.active_trade.pnl_usd = 0  # Reset to 0 to avoid NaN propagation
                    
                    self.balance += self.active_trade.pnl_usd
                    
                    # Safeguard against negative or NaN balance
                    if self.balance < 0:
                        print(f"WARNING: Balance went negative (${self.balance:.2f}), stopping backtest")
                        self.balance = 0
                    
                    if np.isnan(self.balance) or np.isinf(self.balance):
                        print(f"WARNING: Balance became NaN/Inf, resetting to last valid value")
                        self.balance = self.initial_balance
                    
                    self.trades.append(self.active_trade)
                    
                    print(f"Trade #{len(self.trades)} closed: {self.active_trade.result} "
                          f"| {self.active_trade.pnl_pips:.1f} pips | ${self.active_trade.pnl_usd:.2f}")
                    
                    self.active_trade = None
                continue  # Don't look for new trades while in a trade
            
            # Only look for trades during trading session
            if not candle['is_session']:
                continue
            
            # Check daily trade limit
            trade_date = candle['date']
            daily_count = self.daily_trades.get(trade_date, 0)
            if daily_count >= MAX_TRADES_PER_DAY:
                continue
            
            # Check for entry setup
            trade = self.check_entry_setup(idx)
            if trade:
                self.active_trade = trade
                self.daily_trades[trade_date] = daily_count + 1
                
                print(f"\nTrade #{len(self.trades) + 1} opened at {trade.entry_time}")
                print(f"  Direction: {trade.direction.upper()}")
                print(f"  Entry: {trade.entry_price:.5f}")
                print(f"  SL: {trade.stop_loss:.5f} ({price_to_pips(abs(trade.entry_price - trade.stop_loss)):.1f} pips)")
                print(f"  TP: {trade.take_profit:.5f} ({price_to_pips(abs(trade.take_profit - trade.entry_price)):.1f} pips)")
                print(f"  Position size: {trade.position_size:,.0f} units")
        
        # Close any remaining trade
        if self.active_trade:
            last_candle = self.df.iloc[-1]
            self.active_trade.exit_time = last_candle['datetime']
            self.active_trade.exit_price = last_candle['close']
            self.active_trade.result = 'Timeout'
            
            if self.active_trade.direction == 'long':
                self.active_trade.pnl_pips = price_to_pips(
                    self.active_trade.exit_price - self.active_trade.entry_price
                )
            else:
                self.active_trade.pnl_pips = price_to_pips(
                    self.active_trade.entry_price - self.active_trade.exit_price
                )
            
            self.active_trade.pnl_usd = self.active_trade.pnl_pips * 0.0001 * self.active_trade.position_size
            self.balance += self.active_trade.pnl_usd
            self.trades.append(self.active_trade)
        
        print("\n" + "=" * 80)
        print("Backtest completed!")
    
    def check_entry_setup(self, idx: int) -> Optional[Trade]:
        """
        Check if all ICT confluence conditions are met for entry
        This version tracks recent sweeps and checks for subsequent MSS and FVG
        """
        # Need minimum data
        if idx < 50:
            return None
        
        candle = self.df.iloc[idx]
        
        # 1. Check trend bias
        trend = detect_1h_trend(self.df, idx)
        if trend == 'neutral' and not RELAXED_MODE:
            return None
        
        # In relaxed mode, allow neutral trend but infer from sweep type
        if trend == 'neutral' and RELAXED_MODE:
            trend = 'neutral_relaxed'
        
        # 2. Detect and store new liquidity sweeps
        sweep = detect_liquidity_sweep(self.df, idx)
        if sweep:
            # Store this sweep with trend info
            sweep['trend'] = trend
            sweep['detected_at'] = idx
            self.recent_sweeps.append(sweep)
            if DEBUG:
                print(f"  Sweep detected at {candle['datetime']}: {sweep['type']}, trend={trend}")
        
        # Clean up old sweeps (older than 20 candles)
        self.recent_sweeps = [s for s in self.recent_sweeps if idx - s['detected_at'] <= 20]
        
        # 3. Check recent sweeps for MSS and FVG formation
        for sweep in self.recent_sweeps:
            # In relaxed mode, infer trend from sweep type
            if trend == 'neutral_relaxed':
                expected_trend = 'bullish' if sweep['type'] == 'bull_sweep' else 'bearish'
            else:
                # Skip if sweep doesn't align with current trend
                if sweep['trend'] != trend:
                    continue
                expected_trend = trend
            
            # Skip if sweep is too recent (need at least 2 candles for MSS)
            if idx < sweep['idx'] + 2:
                continue
            
            # Check for MSS
            has_mss = detect_mss(self.df, sweep['idx'], idx, sweep['type'])
            if not has_mss:
                continue
            
            if DEBUG:
                print(f"  MSS confirmed at {candle['datetime']} for sweep at idx {sweep['idx']}")
            
            # Check for FVG
            fvg = detect_fvg(self.df, idx)
            if not fvg:
                continue
            
            if DEBUG:
                print(f"  FVG detected at {candle['datetime']}: {fvg['type']}")
            
            # Check FVG type aligns with trend
            if expected_trend == 'bullish' and fvg['type'] != 'bullish':
                continue
            if expected_trend == 'bearish' and fvg['type'] != 'bearish':
                continue
            
            # Apply discretion filters
            if is_messy_candle_cluster(self.df, idx):
                if DEBUG:
                    print(f"  Skipped: messy candle cluster")
                continue
            
            if is_low_liquidity(self.df, idx):
                if DEBUG:
                    print(f"  Skipped: low liquidity")
                continue
            
            # All conditions met! Remove this sweep and prepare trade
            if DEBUG:
                print(f"  ✓ ALL CONDITIONS MET - Preparing trade")
            self.recent_sweeps.remove(sweep)
            return self.prepare_trade(idx, expected_trend, sweep, fvg)
        
        return None
    
    def prepare_trade(self, idx: int, trend: str, sweep: Dict, fvg: Dict) -> Trade:
        """Prepare trade with proper SL, TP, and position sizing"""
        candle = self.df.iloc[idx]
        
        if trend == 'bullish':
            # Long trade
            direction = 'long'
            entry_price = fvg['bottom']  # Enter at bottom of FVG
            
            # Stop loss beyond sweep low with buffer
            stop_loss = sweep['price'] - pips_to_price(STOP_LOSS_BUFFER_PIPS)
            
            # Take profit 3-5x SL distance
            sl_distance = entry_price - stop_loss
            
            # Validate SL distance is positive
            if sl_distance <= 0:
                if DEBUG:
                    print(f"  WARNING: Invalid SL distance for long trade: {sl_distance}")
                return None
            
            tp_distance = sl_distance * TARGET_MAX_R  # Use max R:R for consistency
            take_profit = entry_price + tp_distance
            
        else:  # bearish
            # Short trade
            direction = 'short'
            entry_price = fvg['top']  # Enter at top of FVG
            
            # Stop loss beyond sweep high with buffer
            stop_loss = sweep['price'] + pips_to_price(STOP_LOSS_BUFFER_PIPS)
            
            # Take profit 3-5x SL distance
            sl_distance = stop_loss - entry_price
            
            # Validate SL distance is positive
            if sl_distance <= 0:
                if DEBUG:
                    print(f"  WARNING: Invalid SL distance for short trade: {sl_distance}")
                return None
            
            tp_distance = sl_distance * TARGET_MAX_R  # Use max R:R for consistency
            take_profit = entry_price - tp_distance
        
        # Calculate position size
        sl_pips = price_to_pips(abs(entry_price - stop_loss))
        position_size = calculate_position_size(self.balance, RISK_PER_TRADE, sl_pips)
        
        # Validate position size
        if position_size <= 0 or np.isnan(position_size) or np.isinf(position_size):
            if DEBUG:
                print(f"  WARNING: Invalid position size: {position_size}")
            return None
        
        # Create trade
        trade = Trade(
            entry_time=candle['datetime'],
            entry_price=entry_price,
            direction=direction,
            stop_loss=stop_loss,
            take_profit=take_profit,
            position_size=position_size
        )
        
        return trade
    
    def get_performance_metrics(self) -> Dict:
        """Calculate comprehensive performance metrics"""
        if not self.trades:
            return {}
        
        total_trades = len(self.trades)
        
        # Filter out trades with NaN P&L
        valid_trades = [t for t in self.trades if not np.isnan(t.pnl_usd) and not np.isinf(t.pnl_usd)]
        winning_trades = [t for t in valid_trades if t.pnl_usd > 0]
        losing_trades = [t for t in valid_trades if t.pnl_usd < 0]
        
        win_count = len(winning_trades)
        loss_count = len(losing_trades)
        win_rate = (win_count / total_trades * 100) if total_trades > 0 else 0
        
        total_pnl = sum(t.pnl_usd for t in valid_trades)
        avg_win = sum(t.pnl_usd for t in winning_trades) / win_count if win_count > 0 else 0
        avg_loss = sum(t.pnl_usd for t in losing_trades) / loss_count if loss_count > 0 else 0
        avg_pnl = total_pnl / len(valid_trades) if len(valid_trades) > 0 else 0
        
        # Calculate max drawdown
        peak = self.initial_balance
        max_dd = 0
        for eq in self.equity_curve:
            equity = eq['equity']
            # Skip NaN values
            if np.isnan(equity) or np.isinf(equity):
                continue
            if equity > peak:
                peak = equity
            dd = (peak - equity) / peak * 100 if peak > 0 else 0
            if dd > max_dd:
                max_dd = dd
        
        # Average R:R achieved
        avg_rr = abs(avg_win / avg_loss) if avg_loss != 0 else 0
        
        metrics = {
            'total_trades': total_trades,
            'winning_trades': win_count,
            'losing_trades': loss_count,
            'win_rate': win_rate,
            'total_pnl_usd': total_pnl,
            'avg_win_usd': avg_win,
            'avg_loss_usd': avg_loss,
            'avg_pnl_usd': avg_pnl,
            'avg_rr': avg_rr,
            'ending_balance': self.balance,
            'return_pct': (self.balance - self.initial_balance) / self.initial_balance * 100,
            'max_drawdown_pct': max_dd
        }
        
        return metrics
    
    def save_trade_journal(self, filename: str = 'trade_journal.csv'):
        """Save detailed trade journal to CSV"""
        if not self.trades:
            print("No trades to save.")
            return
        
        journal_data = []
        for trade in self.trades:
            sl_pips = price_to_pips(abs(trade.entry_price - trade.stop_loss))
            tp_pips = price_to_pips(abs(trade.take_profit - trade.entry_price))
            
            journal_data.append({
                'entry_time': trade.entry_time,
                'entry_price': trade.entry_price,
                'exit_time': trade.exit_time,
                'exit_price': trade.exit_price,
                'direction': trade.direction,
                'pnl_pips': round(trade.pnl_pips, 1),
                'pnl_usd': round(trade.pnl_usd, 2),
                'sl_pips': round(sl_pips, 1),
                'tp_pips': round(tp_pips, 1),
                'result': trade.result,
                'position_size': round(trade.position_size, 0)
            })
        
        df_journal = pd.DataFrame(journal_data)
        df_journal.to_csv(filename, index=False)
        print(f"\nTrade journal saved to {filename}")
    
    def plot_equity_curve(self, filename: str = 'equity_curve.png'):
        """Generate and save equity curve chart"""
        if not self.equity_curve:
            print("No equity data to plot.")
            return
        
        eq_df = pd.DataFrame(self.equity_curve)
        
        plt.figure(figsize=(14, 7))
        plt.plot(eq_df['datetime'], eq_df['equity'], linewidth=2, color='#2E86AB')
        plt.axhline(y=self.initial_balance, color='gray', linestyle='--', linewidth=1, alpha=0.7, label='Initial Balance')
        
        plt.title('ICT Strategy - Equity Curve', fontsize=16, fontweight='bold')
        plt.xlabel('Date', fontsize=12)
        plt.ylabel('Account Balance ($)', fontsize=12)
        plt.grid(True, alpha=0.3)
        plt.legend()
        plt.tight_layout()
        
        plt.savefig(filename, dpi=150)
        print(f"Equity curve saved to {filename}")
        plt.close()
    
    def generate_trade_charts(self):
        """Generate TradingView-style candlestick charts for each trade"""
        if not GENERATE_TRADE_CHARTS:
            return
        
        if not self.trades:
            print("No trades to generate charts for.")
            return
        
        import os
        from matplotlib.patches import FancyBboxPatch
        # Create folder if it doesn't exist
        if not os.path.exists(TRADE_CHARTS_FOLDER):
            os.makedirs(TRADE_CHARTS_FOLDER)
        
        print(f"\nGenerating TradingView-style trade charts in {TRADE_CHARTS_FOLDER}/...")
        
        for i, trade in enumerate(self.trades, 1):
            try:
                # Find the trade in the dataframe
                entry_idx = self.df[self.df['datetime'] == trade.entry_time].index[0]
                exit_idx = self.df[self.df['datetime'] == trade.exit_time].index[0]
                
                # Get data window (40 candles before entry, 40 after exit for better context)
                start_idx = max(0, entry_idx - 40)
                end_idx = min(len(self.df) - 1, exit_idx + 40)
                
                chart_data = self.df.iloc[start_idx:end_idx + 1].copy()
                chart_data = chart_data.reset_index(drop=True)
                
                # Create TradingView-style candlestick chart
                fig, ax = plt.subplots(figsize=(18, 11))
                
                # TradingView-style background
                ax.set_facecolor('#131722')
                fig.patch.set_facecolor('#131722')
                
                # Plot candlesticks
                for i_plot, (idx, row) in enumerate(chart_data.iterrows()):
                    # TradingView colors: green for bullish, red for bearish
                    is_bullish = row['close'] >= row['open']
                    color = '#26a69a' if is_bullish else '#ef5350'
                    
                    # Draw high-low line (wick)
                    ax.plot([i_plot, i_plot], [row['low'], row['high']], color=color, linewidth=1.5, solid_capstyle='round')
                    
                    # Draw candle body
                    body_height = abs(row['close'] - row['open'])
                    if body_height < 0.00001:  # Doji
                        body_height = 0.00001
                    body_bottom = min(row['open'], row['close'])
                    ax.add_patch(plt.Rectangle((i_plot - 0.4, body_bottom), 0.8, body_height, 
                                               facecolor=color, edgecolor=color, linewidth=0))
                
                # Calculate exact position in the chart data
                entry_pos = entry_idx - start_idx
                exit_pos = exit_idx - start_idx
                num_candles = len(chart_data)
                
                # TradingView-style SL/TP ZONES (rectangles instead of lines)
                # SL Zone - Red transparent rectangle
                sl_zone_height = abs(trade.entry_price - trade.stop_loss) * 0.3  # Zone height
                if trade.direction == 'long':
                    sl_bottom = trade.stop_loss - sl_zone_height / 2
                else:
                    sl_bottom = trade.stop_loss - sl_zone_height / 2
                
                sl_zone = FancyBboxPatch((0, sl_bottom), num_candles, sl_zone_height,
                                        boxstyle="round,pad=0", 
                                        facecolor='#F44336', alpha=0.15,
                                        edgecolor='#F44336', linewidth=2.5, linestyle='--',
                                        zorder=1)
                ax.add_patch(sl_zone)
                
                # TP Zone - Green transparent rectangle
                tp_zone_height = abs(trade.entry_price - trade.take_profit) * 0.3
                if trade.direction == 'long':
                    tp_bottom = trade.take_profit - tp_zone_height / 2
                else:
                    tp_bottom = trade.take_profit - tp_zone_height / 2
                
                tp_zone = FancyBboxPatch((0, tp_bottom), num_candles, tp_zone_height,
                                        boxstyle="round,pad=0",
                                        facecolor='#4CAF50', alpha=0.15,
                                        edgecolor='#4CAF50', linewidth=2.5, linestyle='--',
                                        zorder=1)
                ax.add_patch(tp_zone)
                
                # TradingView-style LONG/SHORT position markers
                if trade.direction == 'long':
                    # LONG position - Blue upward triangle with "LONG" label
                    entry_marker_color = '#2962FF'
                    marker_shape = '^'
                    position_text = 'LONG'
                    text_y_offset = -0.015 * (chart_data['high'].max() - chart_data['low'].min())
                else:
                    # SHORT position - Purple downward triangle with "SHORT" label
                    entry_marker_color = '#9C27B0'
                    marker_shape = 'v'
                    position_text = 'SHORT'
                    text_y_offset = 0.015 * (chart_data['high'].max() - chart_data['low'].min())
                
                # Entry marker - TradingView style
                ax.scatter(entry_pos, trade.entry_price, color=entry_marker_color, s=500, 
                          marker=marker_shape, zorder=15, edgecolors='white', linewidths=3)
                
                # Add "LONG" or "SHORT" text near entry
                ax.text(entry_pos, trade.entry_price + text_y_offset, position_text, 
                       color='white', fontsize=12, fontweight='bold', ha='center',
                       bbox=dict(boxstyle='round,pad=0.5', facecolor=entry_marker_color, 
                                alpha=0.9, edgecolor='white', linewidth=2), zorder=16)
                
                # Exit marker - TradingView style with result indicator
                if trade.result == 'TP':
                    exit_color = '#00E676'  # Bright green for TP
                    exit_label = 'TAKE PROFIT'
                elif trade.result == 'SL':
                    exit_color = '#FF1744'  # Bright red for SL
                    exit_label = 'STOP LOSS'
                else:
                    exit_color = '#FFC107'  # Amber for timeout
                    exit_label = 'TIMEOUT'
                
                ax.scatter(exit_pos, trade.exit_price, color=exit_color, s=500, 
                          marker='X', zorder=15, edgecolors='white', linewidths=3)
                
                # Add exit label
                exit_text_y_offset = -text_y_offset
                ax.text(exit_pos, trade.exit_price + exit_text_y_offset, exit_label, 
                       color='white', fontsize=11, fontweight='bold', ha='center',
                       bbox=dict(boxstyle='round,pad=0.5', facecolor=exit_color, 
                                alpha=0.9, edgecolor='white', linewidth=2), zorder=16)
                
                # Central SL and TP price lines
                ax.axhline(y=trade.stop_loss, color='#F44336', linestyle=':', linewidth=2, 
                          alpha=0.7, zorder=2)
                ax.axhline(y=trade.take_profit, color='#4CAF50', linestyle=':', linewidth=2, 
                          alpha=0.7, zorder=2)
                
                # Add SL/TP labels on the right
                ax.text(num_candles + 1, trade.stop_loss, f'SL: {trade.stop_loss:.5f}', 
                       color='#F44336', fontsize=11, fontweight='bold', va='center',
                       bbox=dict(boxstyle='round,pad=0.4', facecolor='#131722', 
                                alpha=0.8, edgecolor='#F44336', linewidth=2))
                ax.text(num_candles + 1, trade.take_profit, f'TP: {trade.take_profit:.5f}', 
                       color='#4CAF50', fontsize=11, fontweight='bold', va='center',
                       bbox=dict(boxstyle='round,pad=0.4', facecolor='#131722', 
                                alpha=0.8, edgecolor='#4CAF50', linewidth=2))
                
                # Enhanced info box - TradingView style
                pnl_color = '#00E676' if trade.pnl_usd > 0 else '#FF1744'
                pnl_sign = '+' if trade.pnl_usd > 0 else ''
                
                info_text = f"{'█' * 35}\n"
                info_text += f"  TRADE #{i:03d} - {position_text} POSITION\n"
                info_text += f"{'█' * 35}\n\n"
                info_text += f"  ENTRY  \n"
                info_text += f"  Time:  {str(trade.entry_time)[11:16]}\n"
                info_text += f"  Price: {trade.entry_price:.5f}\n\n"
                info_text += f"  EXIT - {trade.result}\n"
                info_text += f"  Time:  {str(trade.exit_time)[11:16]}\n"
                info_text += f"  Price: {trade.exit_price:.5f}\n\n"
                info_text += f"  P&L\n"
                info_text += f"  Pips:  {pnl_sign}{trade.pnl_pips:.1f}\n"
                info_text += f"  USD:   {pnl_sign}${abs(trade.pnl_usd):.2f}\n\n"
                info_text += f"  ICT SIGNALS:\n"
                info_text += f"  ✓ Liquidity Sweep\n"
                info_text += f"  ✓ MSS Confirmed\n"
                info_text += f"  ✓ FVG Entry Zone"
                
                ax.text(0.015, 0.98, info_text, transform=ax.transAxes, 
                       fontsize=11, verticalalignment='top', family='monospace',
                       color='white', weight='bold',
                       bbox=dict(boxstyle='round,pad=1', facecolor='#1E2A3A', 
                                alpha=0.95, edgecolor=pnl_color, linewidth=3),
                       zorder=20)
                
                # Title - TradingView style
                title_color = '#00E676' if trade.pnl_usd > 0 else '#FF1744'
                ax.set_title(f'ICT Smart Money Strategy | Trade #{i} | {position_text} | Result: {trade.result} | P&L: {pnl_sign}${abs(trade.pnl_usd):.2f}', 
                           fontsize=17, fontweight='bold', pad=20, color='white',
                           bbox=dict(boxstyle='round,pad=0.8', facecolor='#1E2A3A', 
                                    alpha=0.9, edgecolor=title_color, linewidth=3))
                
                # X-axis: TIME TIMESTAMPS (not candle index)
                tick_interval = max(5, num_candles // 15)  # ~15 time labels
                tick_positions = list(range(0, num_candles, tick_interval))
                if num_candles - 1 not in tick_positions:
                    tick_positions.append(num_candles - 1)
                
                # Extract time in format: HH:MM
                tick_labels = []
                for pos in tick_positions:
                    dt_val = chart_data.iloc[pos]['datetime']
                    time_str = str(dt_val)[11:16]  # Extract HH:MM
                    tick_labels.append(time_str)
                
                ax.set_xticks(tick_positions)
                ax.set_xticklabels(tick_labels, rotation=0, ha='center', fontsize=12, 
                                  color='#B2B5BE', weight='bold')
                ax.set_xlabel('Time (15-Minute Timeframe)', fontsize=14, fontweight='bold', 
                             color='white', labelpad=10)
                
                # Y-axis: PRICE
                ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda x, p: f'{x:.5f}'))
                ax.tick_params(axis='y', labelsize=12, colors='#B2B5BE', labelcolor='#B2B5BE')
                ax.set_ylabel('Price', fontsize=14, fontweight='bold', color='white', labelpad=10)
                
                # TradingView-style grid
                ax.grid(True, alpha=0.1, linestyle='-', linewidth=0.5, color='#363A45')
                ax.set_axisbelow(True)
                
                # Remove top and right spines for cleaner look
                ax.spines['top'].set_visible(False)
                ax.spines['right'].set_visible(False)
                ax.spines['left'].set_color('#363A45')
                ax.spines['bottom'].set_color('#363A45')
                
                plt.tight_layout()
                
                # Save chart
                chart_filename = f"{TRADE_CHARTS_FOLDER}/trade_{i:03d}_{trade.direction}_{trade.result}.png"
                plt.savefig(chart_filename, dpi=220, bbox_inches='tight', facecolor='#131722')
                plt.close()
                
                if i % 10 == 0:
                    print(f"  Generated {i}/{len(self.trades)} charts...")
                    
            except Exception as e:
                print(f"  Warning: Could not generate chart for trade #{i}: {e}")
                plt.close()
        
        print(f"Trade charts complete! Saved {len(self.trades)} charts to {TRADE_CHARTS_FOLDER}/")
    
    def print_summary(self):
        """Print comprehensive backtest summary"""
        metrics = self.get_performance_metrics()
        
        if not metrics:
            print("\n" + "=" * 80)
            print("No trades executed.")
            print("=" * 80)
            print("\nPossible reasons:")
            print("  • The data doesn't contain the specific ICT patterns required")
            print("  • The strategy is very strict and requires ALL conditions to align:")
            print("    - Liquidity sweep")
            print("    - Market structure shift")
            print("    - Fair value gap")
            print("    - Trend alignment")
            print("    - Quality filters passed")
            print("\nTip: Use real market data with clear trends and reversals for better results.")
            print("     The sample data is randomly generated for testing purposes only.")
            print("\nTo diagnose further, enable DEBUG mode by setting DEBUG=True in new_trader.py")
            return
        
        print("\n" + "=" * 80)
        print("BACKTEST PERFORMANCE SUMMARY")
        print("=" * 80)
        print(f"Total Trades:        {metrics['total_trades']}")
        print(f"Winning Trades:      {metrics['winning_trades']}")
        print(f"Losing Trades:       {metrics['losing_trades']}")
        print(f"Win Rate:            {metrics['win_rate']:.1f}%")
        print("-" * 80)
        print(f"Total P&L:           ${metrics['total_pnl_usd']:,.2f}")
        print(f"Average Win:         ${metrics['avg_win_usd']:,.2f}")
        print(f"Average Loss:        ${metrics['avg_loss_usd']:,.2f}")
        print(f"Average P&L:         ${metrics['avg_pnl_usd']:,.2f}")
        print(f"Average R:R:         {metrics['avg_rr']:.2f}")
        print("-" * 80)
        print(f"Starting Balance:    ${self.initial_balance:,.2f}")
        print(f"Ending Balance:      ${metrics['ending_balance']:,.2f}")
        print(f"Total Return:        {metrics['return_pct']:.2f}%")
        print(f"Max Drawdown:        {metrics['max_drawdown_pct']:.2f}%")
        print("=" * 80)

# ============================================================================
# MAIN EXECUTION
# ============================================================================

def main():
    """Main execution function"""
    print("=" * 80)
    print("ICT SMART MONEY BACKTEST SYSTEM")
    print("=" * 80)
    
    # Load data
    df = load_data(CSV_PATH)
    
    # Initialize backtest
    backtest = ICTBacktester(df, INITIAL_BALANCE)
    
    # Run backtest
    backtest.run()
    
    # Print summary
    backtest.print_summary()
    
    # Save outputs
    backtest.save_trade_journal('trade_journal.csv')
    backtest.plot_equity_curve('equity_curve.png')
    backtest.generate_trade_charts()
    
    if GENERATE_TRADE_CHARTS and len(backtest.trades) > 0:
        print(f"\nBacktest complete! Check trade_journal.csv, equity_curve.png, and {TRADE_CHARTS_FOLDER}/ for details.")
    else:
        print("\nBacktest complete! Check trade_journal.csv and equity_curve.png for details.")

if __name__ == "__main__":
    main()
