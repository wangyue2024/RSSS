let initialized = false;
let fomo_threshold = 0;
let base_position = 0;
let spread_multiplier = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        fomo_threshold = 20000;
        base_position = rng.rand_int(5, 25);
        spread_multiplier = rng.rand_int(1, 3);
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.history_len() >= 5 {
        let old_price = market.history_price(market.history_len() - 5);
        let price_change = market.price - old_price;
        if price_change * 10000 > old_price * fomo_threshold {
            let buy_amount = account.cash / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }

    let range_high = market.high_20;
    let range_low = market.low_20;
    let spread = range_high - range_low;

    if spread <= 0 || range_high <= 0 || range_low <= 0 { return; }

    let buy_price = range_low + spread * 10 / 100;
    let sell_price = range_high - spread * 10 / 100;

    if buy_price >= market.price || sell_price <= market.price { return; }

    let spread_narrow = spread * 10000 < market.price * 100;
    let position_size = base_position * (if spread_narrow { spread_multiplier } else { 1 });

    if position_size > 0 {
        let max_buy = account.cash / buy_price;
        let buy_qty = if position_size < max_buy { position_size } else { max_buy };
        if buy_qty > 0 {
            orders.submit_limit_buy(buy_price, buy_qty);
        }

        let sell_qty = if position_size < account.stock { position_size } else { account.stock };
        if sell_qty > 0 {
            orders.submit_limit_sell(sell_price, sell_qty);
        }
    }
}