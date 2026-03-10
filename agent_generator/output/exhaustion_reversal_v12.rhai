// Global state
let initialized = false;
let lot_size = 0;
let last_trade_profit = true;
let avg_vol_20 = 0;
let vol_history = [];
let cooldown_until = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        // Risk-averse: lot size < 5% of capital
        let max_lot_value = account.total_equity * 5 / 100;
        let max_shares = max_lot_value / market.price;
        if max_shares < 1 { max_shares = 1; }
        lot_size = rng.rand_int(1, max_shares);
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders each tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    // Update volume history for average calculation
    if vol_history.len() >= 20 {
        vol_history.remove(0);
    }
    vol_history.push(market.volume);
    
    if vol_history.len() >= 20 {
        let sum = 0;
        let j = 0;
        while j < vol_history.len() {
            sum += vol_history[j];
            j += 1;
        }
        avg_vol_20 = sum / vol_history.len();
    }
    
    // Risk-averse: avoid trading if volatility high (std_dev > 2% of price)
    let two_percent = market.price * 2 / 100;
    if market.std_dev > two_percent {
        return;
    }
    
    // Cooldown check
    if market.tick < cooldown_until {
        return;
    }
    
    // Check for exhaustion condition
    // High price > MA60 but volume drops to <10% of 20-period average
    let exhaustion_condition = market.high_20 > market.ma_60 && 
                              avg_vol_20 > 0 && 
                              market.volume * 10 < avg_vol_20;
    
    // Martingale sizing: double after loss
    if !last_trade_profit {
        lot_size = lot_size * 2;
        // Cap at 5% of capital
        let max_lot_value = account.total_equity * 5 / 100;
        let max_shares = max_lot_value / market.price;
        if max_shares < 1 { max_shares = 1; }
        if lot_size > max_shares {
            lot_size = max_shares;
        }
    }
    
    // Stubborn holder: only sell at profit
    if account.stock > 0 {
        if market.price > account.avg_cost {
            orders.submit_limit_sell(market.price, account.stock);
        }
        return;
    }
    
    // Exhaustion reversal: initiate short
    if exhaustion_condition && account.stock == 0 {
        // Short sell (market order)
        orders.submit_market_sell(lot_size);
        cooldown_until = market.tick + 10; // 10 tick cooldown
        return;
    }
    
    // Cover short if profitable (price drops below avg_cost)
    if account.stock < 0 {
        // For short position, avg_cost is sell price, profit when price < avg_cost
        if market.price < account.avg_cost {
            let cover_amount = -account.stock;
            orders.submit_market_buy(cover_amount);
            
            // Update last trade profit status
            if market.price < account.avg_cost {
                last_trade_profit = true;
            } else {
                last_trade_profit = false;
            }
            cooldown_until = market.tick + 10;
        }
    }
}