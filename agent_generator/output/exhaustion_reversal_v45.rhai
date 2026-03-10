// Global variables persist across ticks
let initialized = false;
let personality = 0;
let lot_size = 0;
let last_trade_profit = true;
let volume_history = [];
const SCALING_FACTOR = 1_000_000;

fn on_tick() {
    if !initialized {
        initialized = true;
        // Randomly choose personality: 0=risk-averse, 1=risk-seeking
        personality = rng.rand_int(0, 1);
        
        // Initialize lot size based on personality
        if personality == 0 {
            // Risk-averse: less than 5% of total capital
            let max_cap = account.total_equity * 5 / 100;
            lot_size = rng.rand_int(1, max_cap) / market.price;
            if lot_size < 1 { lot_size = 1; }
        } else {
            // Risk-seeking: up to 50% of available cash
            let max_cash = account.cash * 50 / 100;
            lot_size = rng.rand_int(max_cash / 2, max_cash) / market.price;
            if lot_size < 1 { lot_size = 1; }
        }
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders first
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Update volume history (keep last 20 ticks)
    volume_history.push(market.volume);
    if volume_history.len() > 20 {
        volume_history.remove(0);
    }
    
    // Check if last trade was a loss for Martingale sizing
    if account.stock != 0 {
        let current_value = account.stock * market.price;
        let cost_basis = account.stock * account.avg_cost;
        last_trade_profit = current_value >= cost_basis;
        
        // Double lot size if last trade was loss
        if !last_trade_profit {
            lot_size = lot_size * 2;
        }
    }
    
    // Risk-averse condition: don't trade if std_dev is high (>5% of price)
    let std_dev_threshold = market.price * 5 / 100;
    if personality == 0 && market.std_dev > std_dev_threshold {
        return;
    }
    
    // Calculate average volume for exhaustion detection
    let avg_volume = 0;
    if volume_history.len() > 0 {
        let sum = 0;
        for vol in volume_history {
            sum += vol;
        }
        avg_volume = sum / volume_history.len();
    }
    
    // Exhaustion reversal condition
    // 1. Price has gone up significantly (high_20 > ma_60)
    // 2. Current volume suddenly drops to near zero (<10% of average)
    let exhaustion_condition = false;
    if avg_volume > 0 && volume_history.len() >= 10 {
        let volume_drop = market.volume * 100 / avg_volume < 10;
        let price_up = market.high_20 > market.ma_60;
        exhaustion_condition = volume_drop && price_up;
    }
    
    // Execute strategy
    if exhaustion_condition {
        // Calculate position size (minimum 1 share)
        let shares_to_trade = lot_size;
        if shares_to_trade < 1 { shares_to_trade = 1; }
        
        // Short/sell position
        if account.stock > 0 {
            // Sell existing long position
            orders.submit_market_sell(account.stock);
        } else {
            // Initiate short position
            orders.submit_market_sell(shares_to_trade);
        }
    }
    
    // Optional: cover short if price drops below ma_20
    if account.stock < 0 && market.price < market.ma_20 {
        let cover_amount = -account.stock;  // Positive amount to buy back
        orders.submit_market_buy(cover_amount);
    }
}