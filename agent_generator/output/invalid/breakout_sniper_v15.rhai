// Global state
let initialized = false;
let base_lot_size = 1000;
let current_lot_size = 1000;
let last_trade_was_loss = false;
let price_history = [];
let entry_prices = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(800, 1200);
        current_lot_size = base_lot_size;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders at start of tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Update price history for FOMO detection
    if price_history.len() >= 5 {
        price_history.remove(0);
    }
    price_history.push(market.price);
    
    // Process recent fills to track trade outcomes
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let last_fill_idx = fill_cnt - 1;
        let fill_side = my_orders.fill_side(last_fill_idx);
        let fill_price = my_orders.fill_price(last_fill_idx);
        
        if fill_side == 1 { // Sell fill
            if entry_prices.len() > 0 {
                let entry_price = entry_prices[0];
                if fill_price < entry_price {
                    last_trade_was_loss = true;
                } else {
                    last_trade_was_loss = false;
                }
                entry_prices.remove(0);
            }
        } else if fill_side == 0 { // Buy fill
            entry_prices.push(market.price);
        }
    }
    
    // Martingale sizing
    current_lot_size = base_lot_size;
    if last_trade_was_loss {
        current_lot_size = current_lot_size * 2;
        current_lot_size = clamp_val(current_lot_size, base_lot_size, base_lot_size * 8);
    }
    
    // FOMO condition - price jumped >2% in 5 ticks
    let fomo_triggered = false;
    if price_history.len() >= 5 {
        let old_price = price_history[0];
        if old_price > 0 {
            let pct_change = (market.price - old_price) * 10000 / old_price;
            if pct_change > 200 { // 2% = 200 basis points
                fomo_triggered = true;
            }
        }
    }
    
    // Aggressive FOMO buy
    if fomo_triggered && account.stock == 0 {
        orders.submit_market_buy(current_lot_size);
        return;
    }
    
    // Main breakout logic
    if account.stock == 0 {
        // Buy if price breaks above 20-tick high
        if market.price > market.high_20 {
            // Aggressive buy at ask price
            let buy_price = market.ask_price_0;
            if buy_price > 0 {
                orders.submit_limit_buy(buy_price, current_lot_size);
            }
        }
    } else {
        // We have position - diamond hands: only sell if profitable
        if market.price > account.avg_cost {
            let sell_price = market.bid_price_0;
            if sell_price > 0 {
                orders.submit_limit_sell(sell_price, account.stock);
            }
        }
    }
}