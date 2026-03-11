let initialized = false;
let fair_value = 0;
let agg_buy_threshold = 0;
let cons_buy_threshold = 0;
let max_cancel_ticks = 3;

fn on_tick() {
    if !initialized {
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        agg_buy_threshold = fair_value * 90 / 100;
        cons_buy_threshold = fair_value * 95 / 100;
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel any pending orders older than 3 ticks
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick > max_cancel_ticks {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    let price = market.price;
    let cash = account.cash;
    let stock = account.stock;
    let avg_cost = account.avg_cost;
    
    // Risk-seeking: frequently bet 50% of cash
    let risk_level = rng.rand_int(40, 60);
    let max_buy_cash = cash * risk_level / 100;
    
    // Buy logic
    if price < agg_buy_threshold {
        // Aggressive buy: up to 50% of cash
        let buy_amount = max_buy_cash / price;
        if buy_amount > 0 {
            orders.submit_limit_buy(price, buy_amount);
        }
    } else if price < cons_buy_threshold {
        // Conservative buy: smaller position
        let small_pct = rng.rand_int(5, 15);
        let buy_cash = cash * small_pct / 100;
        let buy_amount = buy_cash / price;
        if buy_amount > 0 {
            orders.submit_limit_buy(price, buy_amount);
        }
    }
    
    // Sell logic: only sell if price > avg_cost (diamond hands)
    if price > avg_cost && stock > 0 {
        // Sell a portion of holdings
        let sell_pct = rng.rand_int(20, 40);
        let sell_amount = stock * sell_pct / 100;
        if sell_amount > 0 {
            orders.submit_limit_sell(price, sell_amount);
        }
    }
}