let initialized = false;
let base_lot = 0;
let panic_threshold = 0;
let buy_price_offset = 0;
let sell_price_offset = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_lot = account.cash * 50 / (market.price * 100);
        if max_lot < 1 {
            max_lot = 1;
        }
        base_lot = rng.rand_int(10, max_lot);
        panic_threshold = rng.rand_int(-50000, -10000);
        buy_price_offset = rng.rand_int(1, 5);
        sell_price_offset = rng.rand_int(1, 5);
    }

    if !market.trading_enabled {
        return;
    }

    if market.tick >= market.total_ticks / 5 {
        let cancel_count = my_orders.pending_count();
        let j = 0;
        while j < cancel_count {
            let oid = my_orders.pending_id(j);
            orders.submit_cancel(oid);
            j += 1;
        }
        return;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let range_low = market.low_20;
    let range_high = market.high_20;
    let spread = range_high - range_low;

    if spread <= 0 {
        return;
    }

    let spread_ratio = spread * 100 / market.price;
    let position_multiplier = if spread_ratio < 300 { 2 } else { 1 };
    let trade_lot = base_lot * position_multiplier;

    let buy_price = range_low + buy_price_offset;
    let sell_price = range_high - sell_price_offset;

    if buy_price < sell_price && trade_lot > 0 {
        let max_buy = account.cash / buy_price;
        let buy_amount = if trade_lot < max_buy { trade_lot } else { max_buy };
        if buy_amount > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }

        let sell_amount = if trade_lot < account.stock { trade_lot } else { account.stock };
        if sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}