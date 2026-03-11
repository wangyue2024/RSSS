let initialized = false;
let lot_size = 0;
let tick_counter = 0;

fn round_to_dollar(price_micros) {
    ((price_micros + 500_000) / 1_000_000) * 1_000_000
}

fn on_tick() {
    if !initialized {
        initialized = true;
        let five_pct_capital = account.total_equity * 5 / 100;
        if market.price > 0 {
            let max_lot = five_pct_capital / market.price;
            if max_lot > 0 {
                lot_size = rng.rand_int(1, max_lot);
            } else {
                lot_size = 1;
            }
        }
    }

    if !market.trading_enabled { return; }

    // Cancel old orders (>3 ticks)
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    // Risk check: don't trade if volatility is high
    if market.std_dev > 100_000 {
        return;
    }

    tick_counter += 1;
    if tick_counter % 10 != 0 {
        return;
    }

    // Rebalance logic
    let stock_value = account.stock * market.price;
    let total = account.total_equity;
    if total == 0 { return; }

    let stock_pct = stock_value * 100 / total;

    let target_price = round_to_dollar(market.price);
    let pending_cnt_now = my_orders.pending_count();

    if stock_pct > 55 && pending_cnt_now == 0 && lot_size > 0 {
        // Sell stock
        let sell_amount = if account.stock < lot_size { account.stock } else { lot_size };
        if sell_amount > 0 {
            orders.submit_limit_sell(target_price, sell_amount);
        }
    } else if stock_pct < 45 && pending_cnt_now == 0 && lot_size > 0 {
        // Buy stock
        let max_buy = account.cash / target_price;
        let buy_amount = if max_buy < lot_size { max_buy } else { lot_size };
        if buy_amount > 0 {
            orders.submit_limit_buy(target_price, buy_amount);
        }
    }
}