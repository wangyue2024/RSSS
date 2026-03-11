let initialized = false;
let panic_threshold = 0;
let base_spread_min = 0;
let min_spread = 50000;
let order_offset_pct = 0;
let position_multiplier = 10000;

fn on_tick() {
    if !initialized {
        panic_threshold = -rng.rand_int(5000, 20000);
        base_spread_min = rng.rand_int(10000, 50000);
        order_offset_pct = rng.rand_int(1, 10);
        position_multiplier = rng.rand_int(8000, 12000);
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let high = market.high_20;
    let low = market.low_20;
    let spread = high - low;

    if spread < min_spread {
        return;
    }

    let range_narrow_factor = base_spread_min * 10000 / spread;
    let position_base = (account.total_equity / market.price) * position_multiplier / 10000;
    let position_size = position_base * range_narrow_factor / 10000;
    position_size = clamp_val(position_size, 100, 10000);

    let buy_offset = spread * order_offset_pct / 100;
    let sell_offset = buy_offset;

    let buy_price = low + buy_offset;
    let sell_price = high - sell_offset;

    if buy_price < sell_price && account.cash > buy_price * position_size {
        orders.submit_limit_buy(buy_price, position_size);
    }
    if sell_price > buy_price && account.stock >= position_size {
        orders.submit_limit_sell(sell_price, position_size);
    }
}