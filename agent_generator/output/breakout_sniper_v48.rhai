let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
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
    
    // FOMO condition: price jumped >2% in last 3 ticks
    let fomo_triggered = false;
    if market.history_len() >= 3 {
        let price_now = market.price;
        let price_3_ago = market.history_price(2);
        if price_3_ago > 0 {
            let jump_pct = (price_now - price_3_ago) * 10000 / price_3_ago;
            if jump_pct > 200 {
                fomo_triggered = true;
            }
        }
    }
    
    // Aggressive buy conditions
    if fomo_triggered {
        // FOMO buy: use 80% of cash
        let buy_amount = account.cash * 80 / 100 / market.price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
    } else if market.price > market.high_20 {
        // Breakout buy: use 50% of cash
        let buy_amount = account.cash * 50 / 100 / market.price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
    }
    
    // Diamond hands: only sell if price > avg_cost (profit)
    if account.stock > 0 && market.price > account.avg_cost {
        // Sell all stock at market
        orders.submit_market_sell(account.stock);
    }
}