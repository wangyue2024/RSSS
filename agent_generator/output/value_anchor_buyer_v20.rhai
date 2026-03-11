let initialized = false;
let fair_value = 0;
let fomo_triggered = false;
let last_fomo_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    let available_cash = account.cash;
    
    // Cancel all pending orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    // FOMO check: price jumped >2% in last 5 ticks
    let history_len = market.history_len();
    if history_len >= 5 {
        let old_price = market.history_price(4);
        if old_price > 0 {
            let price_change_pct = (current_price - old_price) * 10000 / old_price;
            if price_change_pct > 200 {
                fomo_triggered = true;
                last_fomo_tick = market.tick;
            }
        }
    }
    
    // FOMO behavior lasts for 10 ticks
    if fomo_triggered && (market.tick - last_fomo_tick) < 10 {
        let buy_amount = available_cash * 50 / 100 / current_price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
        return;
    } else {
        fomo_triggered = false;
    }
    
    // Core value strategy (never sells)
    let ninety_five_pct = fair_value * 95 / 100;
    let ninety_pct = fair_value * 90 / 100;
    
    if current_price < ninety_five_pct {
        let buy_price = current_price;
        let buy_amount = 0;
        
        if current_price < ninety_pct {
            // Aggressive buy: 30% of cash
            buy_amount = available_cash * 30 / 100 / buy_price;
        } else {
            // Small buy: 10% of cash
            buy_amount = available_cash * 10 / 100 / buy_price;
        }
        
        if buy_amount > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }
}