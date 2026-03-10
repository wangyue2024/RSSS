let initialized = false;
let panic_threshold = 0;
let base_lot = 0;
let max_std_dev = 0;

fn round_price(p) {
    ((p + 500_000) / 1_000_000) * 1_000_000
}

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -1 * rng.rand_int(5_000, 50_000);
        let five_pct_cap = account.total_equity * 5 / 100;
        let max_shares = five_pct_cap / market.price;
        if max_shares <= 0 {
            base_lot = 1;
        } else {
            base_lot = rng.rand_int(1, max_shares);
        }
        max_std_dev = market.price * 2 / 100;
    }

    if !market.trading_enabled { return; }

    let pcount = my_orders.pending_count();
    let i = 0;
    while i < pcount {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    if account.unrealized_pnl < panic_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    if market.std_dev > max_std_dev {
        return;
    }

    let imb = market.order_imbalance;
    let shift = imb * 10_000;
    let base_price = market.price + shift;

    let bid_price = round_price(base_price - 5_000);
    let ask_price = round_price(base_price + 5_000);

    if ask_price <= bid_price {
        ask_price = bid_price + 1_000_000;
    }

    if account.cash >= bid_price && base_lot > 0 {
        orders.submit_limit_buy(bid_price, base_lot);
    }
    if account.stock >= base_lot && base_lot > 0 {
        orders.submit_limit_sell(ask_price, base_lot);
    }
}