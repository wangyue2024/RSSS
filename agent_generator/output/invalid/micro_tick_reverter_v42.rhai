let initialized = false;
let last_price = 0;
let patience_ticks = 3;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_price = market.price;
        return;
    }

    if !market.trading_enabled { return; }

    // Cancel orders older than patience_ticks
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed = my_orders.pending_placed_tick(i);
        if market.tick - placed >= patience_ticks {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    // Determine price movement
    let price_down = market.price < last_price;
    let price_up = market.price > last_price;

    // Only act if no pending orders remain after potential cancellations
    if my_orders.pending_count() == 0 {
        if price_down {
            // Buy: risk-seeking lot size (up to 50% of cash)
            let max_shares = account.cash / market.price;
            let aggressive_pct = rng.rand_int(25, 50);
            let buy_shares = (max_shares * aggressive_pct) / 100;
            if buy_shares > 0 {
                let buy_price = market.price - 100; // Slightly below
                if buy_price > 0 {
                    orders.submit_limit_buy(buy_price, buy_shares);
                }
            }
        } else if price_up && market.price > account.avg_cost {
            // Sell only at profit: use up to 50% of current stock
            if account.stock > 0 {
                let aggressive_pct = rng.rand_int(25, 50);
                let sell_shares = (account.stock * aggressive_pct) / 100;
                if sell_shares > 0 {
                    let sell_price = market.price + 100; // Slightly above
                    orders.submit_limit_sell(sell_price, sell_shares);
                }
            }
        }
    }

    last_price = market.price;
}