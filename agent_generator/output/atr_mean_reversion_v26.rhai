let initialized = false;
let risk_percent = 0;
let std_dev_thresh_percent = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_percent = rng.rand_int(1, 4);
        std_dev_thresh_percent = rng.rand_int(1, 3);
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.ma_20 == 0 || market.atr_14 == 0 { return; }

    let deviation = abs_val(market.price - market.ma_20);
    let atr_threshold = (market.atr_14 * 150) / 100;
    if deviation <= atr_threshold { return; }

    let std_dev_limit = (market.price * std_dev_thresh_percent) / 100;
    if market.std_dev > std_dev_limit { return; }

    let max_capital = (account.total_equity * risk_percent) / 100;
    let price_to_use = market.price;
    if price_to_use == 0 { return; }
    let max_shares = max_capital / price_to_use;
    if max_shares <= 0 { return; }

    let amount = rng.rand_int(1, max_shares);

    if market.price > market.ma_20 {
        let ask = market.ask_price_0;
        if ask == 0 { return; }
        orders.submit_limit_sell(ask, amount);
    } else {
        let bid = market.bid_price_0;
        if bid == 0 { return; }
        orders.submit_limit_buy(bid, amount);
    }
}