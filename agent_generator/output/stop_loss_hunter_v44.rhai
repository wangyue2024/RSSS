let initialized = false;
let lot_size = 0;
let last_decision_tick = -100;
let placed_orders = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_capital = account.total_equity * 5 / 100;
        let max_shares = max_capital / market.price;
        if max_shares < 1 {
            lot_size = 1;
        } else {
            lot_size = rng.rand_int(1, max_shares);
        }
    }

    if !market.trading_enabled { return; }

    let current_tick = market.tick;

    let std_dev_threshold = market.price * 2 / 100;
    if market.std_dev > std_dev_threshold {
        let i = 0;
        while i < my_orders.pending_count() {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }

    let i = 0;
    let pending_cnt = my_orders.pending_count();
    while i < pending_cnt {
        let placed = my_orders.pending_placed_tick(i);
        if current_tick - placed >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if current_tick % 50 != 0 { return; }

    let i = 0;
    while i < my_orders.pending_count() {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let cluster_volume = market.bid_vol_0 + market.bid_vol_1 + market.bid_vol_2;
    let price_range = market.bid_price_0 - market.bid_price_2;
    let cluster_threshold = 15000;

    if cluster_volume > cluster_threshold && price_range < micros(0, 500) {
        orders.submit_market_sell(lot_size);

        let buy_price = market.bid_price_2 - micros(0, 100);
        if buy_price > 0 {
            orders.submit_limit_buy(buy_price, lot_size);
        }
    }
}