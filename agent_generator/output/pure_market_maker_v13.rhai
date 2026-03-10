let initialized = false;
let spread_micros = 0;
let order_size = 0;
let stop_loss_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        spread_micros = rng.rand_int(20_000, 50_000);
        order_size = rng.rand_int(100, 300);
        stop_loss_threshold = -rng.rand_int(500_000, 2_000_000);
    }

    if !market.trading_enabled {
        return;
    }

    if account.unrealized_pnl < stop_loss_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let mid_price = market.price;
    let bid_price = mid_price - spread_micros + 1;
    let ask_price = mid_price + spread_micros;

    if bid_price > 0 {
        orders.submit_limit_buy(bid_price, order_size);
    }
    if ask_price > 0 {
        orders.submit_limit_sell(ask_price, order_size);
    }
}