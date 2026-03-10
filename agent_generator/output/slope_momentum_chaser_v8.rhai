let initialized = false;
let panic_threshold = 0;
let last_prices = [];
let fomo_triggered = false;
let fomo_cooldown = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(5_000_000, 25_000_000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if fomo_cooldown > 0 {
        fomo_cooldown -= 1;
        if fomo_cooldown == 0 {
            fomo_triggered = false;
        }
    }
    
    if last_prices.len() >= 5 {
        let oldest_idx = last_prices.len() - 5;
        let old_price = last_prices[oldest_idx];
        let price_change_pct = (market.price - old_price) * 10000 / old_price;
        if price_change_pct > 200 && !fomo_triggered {
            fomo_triggered = true;
            fomo_cooldown = 50;
            if account.cash > 1_000_000 {
                let buy_amount = account.cash / market.price;
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount);
                }
            }
            return;
        }
    }
    
    last_prices.push(market.price);
    if last_prices.len() > 100 {
        last_prices.remove(0);
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    let hist_len = market.history_len();
    if hist_len < 10 { return; }
    
    let short_slope_arr = [];
    let long_slope_arr = [];
    let j = 0;
    while j < 10 {
        if hist_len - 1 - j >= 0 {
            short_slope_arr.push(market.history_price(hist_len - 1 - j));
        }
        j += 1;
    }
    let k = 0;
    while k < 30 {
        if hist_len - 1 - k >= 0 {
            long_slope_arr.push(market.history_price(hist_len - 1 - k));
        }
        k += 1;
    }
    
    if short_slope_arr.len() < 5 || long_slope_arr.len() < 5 { return; }
    
    let short_slope = arr_slope(short_slope_arr);
    let long_slope = arr_slope(long_slope_arr);
    
    if short_slope > 0 && short_slope > long_slope * 2 {
        let available_cash = account.cash * 3 / 4;
        if available_cash > 100_000 {
            let buy_amount = available_cash / market.price;
            if buy_amount > 0 {
                let spread = market.ask_price_0 - market.bid_price_0;
                let buy_price = market.bid_price_0 + spread / 3;
                orders.submit_limit_buy(buy_price, buy_amount);
            }
        }
    } else if short_slope < 0 {
        if account.stock > 0 {
            let sell_amount = account.stock / 2;
            if sell_amount > 0 {
                let spread = market.ask_price_0 - market.bid_price_0;
                let sell_price = market.ask_price_0 - spread / 3;
                orders.submit_limit_sell(sell_price, sell_amount);
            }
        }
    }
}