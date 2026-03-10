let initialized = false;
let lookback = 20;
let slope_window = 10;
let prev_slope = 0;
let prev_price = 0;
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    let current_tick = market.tick;
    
    // Cancel orders older than 3 ticks
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed = my_orders.pending_placed_tick(i);
        if current_tick - placed > 3 {
            orders.submit_cancel(my_orders.pending_id(i));
        }
        i += 1;
    }
    
    // FOMO Check: price jump > 2% in 5 ticks
    if market.history_len() >= 5 {
        let price_now = market.price;
        let price_5_ago = market.history_price(5);
        if price_5_ago > 0 && price_now * 100 > price_5_ago * 102 {
            fomo_triggered = true;
            let buy_amount = account.cash / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }
    
    // Calculate slope if enough history
    if market.history_len() >= slope_window {
        let prices = [];
        let idx = 0;
        while idx < slope_window {
            prices.push(market.history_price(idx));
            idx += 1;
        }
        let current_slope = arr_slope(prices);
        
        // Momentum logic
        if current_slope > 1000 && current_slope > prev_slope {
            // Aggressive buy: use 30% of cash
            let bid_price = market.bid_price_0;
            if bid_price > 0 {
                let buy_price = bid_price + 1; // Off-by-one pumper
                let buy_amount = (account.cash * 30 / 100) / buy_price;
                if buy_amount > 0 {
                    orders.submit_limit_buy(buy_price, buy_amount);
                }
            }
        } else if current_slope < -500 && account.stock > 0 {
            // Panic sell: market sell half
            let sell_amount = account.stock / 2;
            if sell_amount > 0 {
                orders.submit_market_sell(sell_amount);
            }
        }
        prev_slope = current_slope;
    }
    
    prev_price = market.price;
}