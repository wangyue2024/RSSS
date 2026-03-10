let initialized = false;
let base_lot = 100;
let current_lot = 100;
let last_trade_loss = false;
let price_history = [];
let fomo_triggered = false;
let base_spread_pct = 30;
let vol_sensitivity = 5;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread_pct = rng.rand_int(25, 40);
        vol_sensitivity = rng.rand_int(4, 8);
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all existing orders
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    // Update price history for FOMO detection
    price_history.push(market.price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }
    
    // FOMO check: price jumped >2% in last 3 ticks
    if price_history.len() >= 4 {
        let old_price = price_history[price_history.len() - 4];
        let jump_threshold = old_price * 10200 / 10000;
        if market.price > jump_threshold {
            fomo_triggered = true;
            let buy_amount = current_lot * 2;
            if account.cash >= market.price * buy_amount {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }
    fomo_triggered = false;
    
    // Martingale sizing
    current_lot = base_lot;
    if account.stock > 0 {
        if market.price < account.avg_cost {
            last_trade_loss = true;
        } else {
            last_trade_loss = false;
        }
    }
    if last_trade_loss {
        current_lot = current_lot * 2;
    }
    
    // Volatility-adaptive spread calculation
    let vol_factor = market.std_dev * vol_sensitivity / 1_000_000;
    let spread_pct = base_spread_pct + vol_factor;
    if spread_pct > 200 { spread_pct = 200; }
    if spread_pct < 10 { spread_pct = 10; }
    
    let half_spread = market.price * spread_pct / 20000;
    
    // Calculate raw prices
    let raw_bid = market.price - half_spread;
    let raw_ask = market.price + half_spread;
    
    // Round to nearest dollar (1_000_000)
    let round_bid = ((raw_bid + 500_000) / 1_000_000) * 1_000_000;
    let round_ask = ((raw_ask + 500_000) / 1_000_000) * 1_000_000;
    
    // Ensure bid < ask
    if round_bid >= round_ask {
        round_ask = round_bid + 1_000_000;
    }
    
    // Submit limit orders if we have capacity
    if account.cash >= round_bid * current_lot {
        orders.submit_limit_buy(round_bid, current_lot);
    }
    
    if account.stock >= current_lot {
        orders.submit_limit_sell(round_ask, current_lot);
    }
}