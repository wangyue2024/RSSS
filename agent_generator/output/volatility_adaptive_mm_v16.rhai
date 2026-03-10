let initialized = false;
let base_spread = 0;
let volatility_multiplier = 0;
let panic_threshold = 0;
let order_size = 0;
let spread = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(1500, 4500);
        volatility_multiplier = rng.rand_int(50, 200);
        panic_threshold = -rng.rand_int(50000, 200000);
        order_size = rng.rand_int(50, 200);
    }

    if !market.trading_enabled { return; }

    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    spread = base_spread + (market.std_dev * volatility_multiplier) / 1000;
    if spread < 1000 { spread = 1000; }

    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    if mid_price == 0 { return; }

    let bid_price = mid_price - spread / 2;
    let ask_price = mid_price + spread / 2;

    if bid_price > 0 && account.cash > bid_price * order_size {
        orders.submit_limit_buy(bid_price, order_size);
    }

    if ask_price > 0 && account.stock >= order_size {
        orders.submit_limit_sell(ask_price, order_size);
    }
}