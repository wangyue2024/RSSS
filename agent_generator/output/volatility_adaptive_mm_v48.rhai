let initialized = false;
let base_spread = 0;
let position_risk = 0;
let max_position = 0;
let min_spread = 2000;
let max_spread = 50000;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(min_spread, 25000);
        position_risk = rng.rand_int(30, 50);
        max_position = rng.rand_int(500, 2000);
    }

    if !market.trading_enabled { return; }

    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let volatility = market.std_dev;
    let vol_multiplier = 1000 + volatility / 100;
    let spread = clamp_val(base_spread * vol_multiplier / 1000, min_spread, max_spread);
    let half_spread = spread / 2;

    let bid_price = market.price - half_spread;
    let ask_price = market.price + half_spread;

    let cash_available = account.cash;
    let stock_available = account.stock;

    let buy_size = cash_available * position_risk / 100 / market.price;
    let buy_amount = clamp_val(buy_size, 1, max_position);

    let sell_size = stock_available * position_risk / 100;
    let sell_amount = clamp_val(sell_size, 1, max_position);

    if buy_amount >= 1 && bid_price > 0 {
        orders.submit_limit_buy(bid_price, buy_amount);
    }

    if ask_price > account.avg_cost && sell_amount >= 1 {
        orders.submit_limit_sell(ask_price, sell_amount);
    }
}