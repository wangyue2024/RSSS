let initialized = false;
let base_amount = 0;
let offset_percent = 0;
let max_multiplier = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_amount = rng.rand_int(80, 120);
        offset_percent = rng.rand_int(5, 15);
        max_multiplier = rng.rand_int(3, 6);
    }

    if !market.trading_enabled { return; }

    if market.tick >= market.total_ticks * 20 / 100 {
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.high_20 <= market.low_20 {
        return;
    }

    let range_width = market.high_20 - market.low_20;
    let base_range_width = 50_000;

    let width_ratio = if range_width > 0 { base_range_width * 100 / range_width } else { 100 };
    let clamp_ratio = clamp_val(width_ratio, 100, max_multiplier * 100);
    let size_multiplier = clamp_ratio / 100;
    let order_amount = base_amount * size_multiplier;

    let buy_offset = range_width * offset_percent / 10000;
    let buy_price = market.low_20 + buy_offset;
    let sell_offset = range_width * offset_percent / 10000;
    let sell_price = market.high_20 - sell_offset;

    if buy_price < sell_price && buy_price > 0 && sell_price > 0 && order_amount > 0 {
        let max_buy_by_cash = account.cash / buy_price;
        let adjusted_buy_amount = if order_amount > max_buy_by_cash { max_buy_by_cash } else { order_amount };
        if adjusted_buy_amount > 0 {
            orders.submit_limit_buy(buy_price, adjusted_buy_amount);
        }

        let adjusted_sell_amount = if order_amount > account.stock { account.stock } else { order_amount };
        if adjusted_sell_amount > 0 {
            orders.submit_limit_sell(sell_price, adjusted_sell_amount);
        }
    }
}