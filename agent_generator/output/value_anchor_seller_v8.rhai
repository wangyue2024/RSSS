let initialized = false;
let fair_value = 0;
let stop_loss_threshold = 0;
let lot_size = 0;
let fair_value_offset = 0;

fn on_tick() {
    if !initialized {
        fair_value_offset = rng.rand_int(-5_000_000, 5_000_000);
        fair_value = 100_000_000 + fair_value_offset;
        let max_loss = rng.rand_int(-2_000_000, -500_000);
        stop_loss_threshold = max_loss;
        let five_percent_cap = account.total_equity * 5 / 100;
        lot_size = rng.rand_int(1, five_percent_cap / market.price);
        initialized = true;
    }

    if !market.trading_enabled {
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let high_volatility = market.std_dev > fair_value * 5 / 100;
    if high_volatility {
        return;
    }

    let price = market.price;
    let aggressive_sell_threshold = fair_value * 110 / 100;
    let small_sell_threshold = fair_value * 105 / 100;

    if price > aggressive_sell_threshold && account.stock >= lot_size * 2 {
        let sell_price = market.bid_price_0;
        orders.submit_limit_sell(sell_price, lot_size * 2);
    } else if price > small_sell_threshold && account.stock >= lot_size {
        let sell_price = market.bid_price_0;
        orders.submit_limit_sell(sell_price, lot_size);
    }
}