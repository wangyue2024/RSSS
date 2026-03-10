let initialized = false;
let lot_size = 0;
let volatility_threshold = 2_000_000;
let cluster_multiplier = 3;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        let max_lot = account.total_equity * 5 / 100;
        if max_lot > 0 {
            lot_size = rng.rand_int(1, max_lot);
        } else {
            lot_size = 1;
        }
    }

    if market.tick % 50 != 0 { return; }

    if market.std_dev > volatility_threshold { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let current_price = market.price;
    let lower_bound = current_price * 99 / 100;

    let bids = [
        [market.bid_price_0, market.bid_vol_0],
        [market.bid_price_1, market.bid_vol_1],
        [market.bid_price_2, market.bid_vol_2],
        [market.bid_price_3, market.bid_vol_3],
        [market.bid_price_4, market.bid_vol_4]
    ];

    let cluster_volume = 0;
    let lowest_bid = current_price;
    let idx = 0;
    while idx < 3 {
        let price = bids[idx][0];
        let volume = bids[idx][1];
        if price >= lower_bound && price <= current_price && price > 0 {
            cluster_volume += volume;
            if price < lowest_bid {
                lowest_bid = price;
            }
        }
        idx += 1;
    }

    if cluster_volume > cluster_multiplier * lot_size && account.stock >= lot_size {
        orders.submit_market_sell(lot_size);
        let buy_price = lowest_bid - (current_price - lowest_bid) / 2;
        if buy_price < 1 { buy_price = 1; }
        orders.submit_limit_buy(buy_price, lot_size);
    }
}