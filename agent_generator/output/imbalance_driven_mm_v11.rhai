let initialized = false;
let my_spread = 500_000;
let my_order_size = 100;
let my_imbalance_threshold = 200;

fn on_tick() {
    if !initialized {
        initialized = true;
        my_spread = rng.rand_int(400_000, 600_000);
        my_order_size = rng.rand_int(80, 120);
        my_imbalance_threshold = rng.rand_int(150, 250);
    }

    if !market.trading_enabled { return; }

    if market.tick >= market.total_ticks / 5 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let mid_price = market.price;
    let imbalance_effect = market.order_imbalance * 50_000 / 100;

    let raw_bid = mid_price + imbalance_effect - my_spread / 2;
    let raw_ask = mid_price + imbalance_effect + my_spread / 2;

    let round_to = 1_000_000;
    let half_round = 500_000;

    let bid_price = if raw_bid >= 0 {
        ((raw_bid + half_round) / round_to) * round_to
    } else {
        ((raw_bid - half_round) / round_to) * round_to
    };

    let ask_price = if raw_ask >= 0 {
        ((raw_ask + half_round) / round_to) * round_to
    } else {
        ((raw_ask - half_round) / round_to) * round_to
    };

    if bid_price < ask_price && bid_price > 0 {
        let max_buy_shares = account.cash / bid_price;
        let buy_amount = if my_order_size < max_buy_shares { my_order_size } else { max_buy_shares };
        if buy_amount > 0 {
            orders.submit_limit_buy(bid_price, buy_amount);
        }

        let sell_amount = if my_order_size < account.stock { my_order_size } else { account.stock };
        if sell_amount > 0 {
            orders.submit_limit_sell(ask_price, sell_amount);
        }
    }
}