let initialized = false;
let spread_factor = 5000;
let base_amount = 100;
let last_fomo_check = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        spread_factor = rng.rand_int(4000, 6000);
    }
    
    if !market.trading_enabled { return; }
    
    // FOMO check: price jump >2% in last 3 ticks
    if market.tick - last_fomo_check > 2 {
        last_fomo_check = market.tick;
        if market.history_len() >= 3 {
            let old_price = market.history_price(2);
            if old_price > 0 {
                let change = abs_val(market.price - old_price) * 10000 / old_price;
                if change > 200 {
                    orders.submit_market_buy(base_amount);
                    return;
                }
            }
        }
    }
    
    // Cancel orders older than 3 ticks
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Adaptive spread based on volatility
    let volatility = market.std_dev;
    let base_spread = market.price * spread_factor / 10000;
    let adjusted_spread = base_spread + volatility * 2;
    
    // Ensure spread is reasonable
    let half_spread = clamp_val(adjusted_spread / 2, 100, 50000);
    
    let buy_price = market.price - half_spread;
    let sell_price = market.price + half_spread;
    
    if buy_price < 1 {
        buy_price = 1;
    }
    
    // Check if we have existing orders
    let has_buy = false;
    let has_sell = false;
    let pending_count = my_orders.pending_count();
    let j = 0;
    while j < pending_count {
        let side = my_orders.pending_side(j);
        if side == 0 {
            has_buy = true;
        } else {
            has_sell = true;
        }
        j += 1;
    }
    
    // Place buy order if none exists
    if !has_buy {
        let buy_amount = base_amount;
        if account.cash < buy_price * buy_amount {
            buy_amount = account.cash / buy_price;
        }
        if buy_amount > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }
    
    // Place sell order if none exists
    if !has_sell {
        let sell_amount = base_amount;
        if account.stock < sell_amount {
            sell_amount = account.stock;
        }
        if sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}