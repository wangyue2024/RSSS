let initialized = false;
let risk_factor = 0;
let lot_size_base = 0;
let target_spread = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_factor = rng.rand_int(30, 50);
        lot_size_base = rng.rand_int(5, 15);
        target_spread = rng.rand_int(1500000, 3000000);
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let range_high = market.high_20;
    let range_low = market.low_20;
    let range_width = range_high - range_low;
    if range_width <= 0 { return; }

    let spread_narrow = range_width < target_spread;
    let size_multiplier = if spread_narrow { 3 } else { 1 };
    let max_buy_cash = account.cash * risk_factor / 100;
    let max_buy_shares = max_buy_cash / market.price;
    let buy_amount = lot_size_base * size_multiplier;
    if buy_amount > max_buy_shares { buy_amount = max_buy_shares; }
    if buy_amount < 1 { buy_amount = 1; }

    let raw_buy_price = range_low + range_width * 10 / 100;
    let buy_price_rounded = ((raw_buy_price + 500000) / 1000000) * 1000000;
    if buy_price_rounded <= 0 { return; }

    if account.cash >= buy_price_rounded && buy_amount >= 1 {
        orders.submit_limit_buy(buy_price_rounded, buy_amount);
    }

    if account.stock > 0 {
        let raw_sell_price = range_high - range_width * 10 / 100;
        let sell_price_rounded = ((raw_sell_price + 500000) / 1000000) * 1000000;
        if sell_price_rounded <= 0 { return; }

        let sell_amount = lot_size_base * size_multiplier;
        if sell_amount > account.stock { sell_amount = account.stock; }

        if sell_price_rounded > account.avg_cost && sell_amount >= 1 {
            orders.submit_limit_sell(sell_price_rounded, sell_amount);
        }
    }
}