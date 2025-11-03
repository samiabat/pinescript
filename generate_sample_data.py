# Example EURUSD 15-Minute Data Generator
# This script generates sample data for testing the ICT backtest system

import random
from datetime import datetime, timedelta

def generate_eurusd_data(start_date, num_days, filename='EURUSD15.csv'):
    """
    Generate realistic EURUSD 15-minute data with some trending patterns
    
    Args:
        start_date: Starting date (datetime object)
        num_days: Number of days to generate
        filename: Output CSV filename
    """
    base_price = 1.1600
    data = []
    
    num_candles = num_days * 24 * 4  # 4 candles per hour
    
    for i in range(num_candles):
        current_time = start_date + timedelta(minutes=15*i)
        
        # Create oscillating trends and reversals
        trend_component = 0.0002 * (i % 200 - 100) / 100
        noise = random.uniform(-0.0005, 0.0005)
        
        price = base_price + trend_component + noise
        
        # Create OHLC with realistic behavior
        open_price = price
        high = price + random.uniform(0, 0.0015)
        low = price - random.uniform(0, 0.0015)
        close = price + random.uniform(-0.0010, 0.0010)
        volume = random.randint(50, 600)
        
        # Format datetime as required
        time_str = current_time.strftime("%Y-%m-%d %H:%M")
        
        data.append(f"{time_str}    {open_price:.5f} {high:.5f} {low:.5f} {close:.5f} {volume}")
    
    # Write to file
    with open(filename, 'w') as f:
        for line in data:
            f.write(line + '\n')
    
    print(f"Generated {len(data)} candles of EURUSD 15M data")
    print(f"Date range: {start_date} to {start_date + timedelta(days=num_days)}")
    print(f"Saved to: {filename}")

if __name__ == "__main__":
    # Generate 1 year of data starting from January 1, 2021
    start_date = datetime(2021, 1, 1, 0, 0)
    num_days = 365
    
    generate_eurusd_data(start_date, num_days, 'EURUSD15.csv')
    print("\nYou can now run: python3 new_trader.py")
