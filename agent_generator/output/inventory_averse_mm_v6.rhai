let initialized = false;
let lot_size = 0;
let high_inventory = 1000;
let low_inventory = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_lot = account.total_equity * 5 / 100;
        lot_size = rng.rand_int(1, max_lot);
    }

    if !market.trading_enabled { return; }
    if market.std_dev > 50_000_000 { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let inventory = account.stock;
    let buy_offset;
    let sell_offset;

    if inventory > high_inventory {
        buy_offset = 3_000_000;
        sell_offset = 1_000_000;
    } else if inventory <= low_inventory {
        buy_offset = 1_000_000;
        sell_offset = 3_000_000;
    } else {
        buy_offset = 2_000_000;
        sell_offset = 2_000_000;
    }

    let raw_bid = market.price - buy_offset;
    let raw_ask = market.price + sell_offset;

    let round_bid = (raw_bid / 1_000_000) * 1_000_000;
    let round_ask = (raw_ask / 1_000_000) * 1_000_000;

    if round_bid > 0 && round_ask > round_bid {
        orders.submit_limit_buy(round_bid, lot_size);

        if round_ask > account.avg_cost {
            orders.submit_limit_sell(round_ask, lot_size);
        }
    }
}