#!/usr/bin/env python3
"""
Test script to verify the ICT backtest system is working correctly
"""

import os
import sys

def test_imports():
    """Test that all required packages can be imported"""
    print("Testing imports...")
    try:
        import pandas as pd
        import numpy as np
        import matplotlib.pyplot as plt
        print("  ✓ All required packages imported successfully")
        return True
    except ImportError as e:
        print(f"  ✗ Import error: {e}")
        print("  Run: pip install pandas numpy matplotlib")
        return False

def test_script_exists():
    """Test that new_trader.py exists"""
    print("Checking for new_trader.py...")
    if os.path.exists('new_trader.py'):
        print("  ✓ new_trader.py found")
        return True
    else:
        print("  ✗ new_trader.py not found")
        return False

def test_data_generator():
    """Test the sample data generator"""
    print("Testing data generator...")
    try:
        import generate_sample_data as gen
        # Generate small test dataset
        from datetime import datetime
        gen.generate_eurusd_data(datetime(2021, 1, 1), 7, 'test_data.csv')
        
        if os.path.exists('test_data.csv'):
            print("  ✓ Sample data generated successfully")
            # Clean up
            os.remove('test_data.csv')
            return True
        else:
            print("  ✗ Data generation failed")
            return False
    except Exception as e:
        print(f"  ✗ Error: {e}")
        return False

def test_backtest_structure():
    """Test that the backtest script has required components"""
    print("Checking backtest implementation...")
    required_components = [
        'detect_1h_trend',
        'detect_liquidity_sweep',
        'detect_mss',
        'detect_fvg',
        'ICTBacktester',
        'calculate_position_size',
        'save_trade_journal',
        'plot_equity_curve'
    ]
    
    with open('new_trader.py', 'r') as f:
        content = f.read()
    
    missing = []
    for component in required_components:
        if component not in content:
            missing.append(component)
    
    if not missing:
        print(f"  ✓ All {len(required_components)} required components found")
        return True
    else:
        print(f"  ✗ Missing components: {', '.join(missing)}")
        return False

def test_configuration():
    """Test that configuration parameters are present"""
    print("Checking configuration parameters...")
    required_configs = [
        'CSV_PATH',
        'INITIAL_BALANCE',
        'RISK_PER_TRADE',
        'LONDON_NY_START',
        'LONDON_NY_END',
        'MAX_TRADES_PER_DAY',
        'MIN_FVG_PIPS'
    ]
    
    with open('new_trader.py', 'r') as f:
        content = f.read()
    
    missing = []
    for config in required_configs:
        if config not in content:
            missing.append(config)
    
    if not missing:
        print(f"  ✓ All {len(required_configs)} configuration parameters found")
        return True
    else:
        print(f"  ✗ Missing configs: {', '.join(missing)}")
        return False

def main():
    """Run all tests"""
    print("=" * 70)
    print("ICT BACKTEST SYSTEM - VERIFICATION TEST")
    print("=" * 70)
    print()
    
    tests = [
        test_imports,
        test_script_exists,
        test_backtest_structure,
        test_configuration,
        test_data_generator
    ]
    
    results = []
    for test in tests:
        result = test()
        results.append(result)
        print()
    
    print("=" * 70)
    print("TEST SUMMARY")
    print("=" * 70)
    
    passed = sum(results)
    total = len(results)
    
    print(f"Passed: {passed}/{total}")
    
    if all(results):
        print("\n✓ All tests passed! The ICT backtest system is ready to use.")
        print("\nNext steps:")
        print("  1. Generate data: python3 generate_sample_data.py")
        print("  2. Run backtest: python3 new_trader.py")
        print("\nNote: Use real EURUSD 15M data for meaningful results.")
        return 0
    else:
        print("\n✗ Some tests failed. Please check the errors above.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
