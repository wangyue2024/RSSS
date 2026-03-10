let initialized = false;
let lot_size = 0;
let volatility_threshold = 0;
let cluster_threshold = 0;
let short_position_active = false;
let short_entry_price = 0;
let short_ticks_held = 0;
let max_hold_ticks = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_shares = account.total_equity * 5 / 100 / market.price;
        if max_shares < 1 {
            max_shares = 1;
        }
        lot_size = rng.rand_int(1, max_shares);
        volatility_threshold = market.price * 2 / 100;
        cluster_threshold = lot_size * 10;
        max_hold_ticks = rng.rand_int(20, 100);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.std_dev > volatility_threshold { return; }

    if short_position_active {
        short_ticks_held += 1;
        let current_price = market.price;

        let profit_target = short_entry_price * 99 / 100;
        let stop_loss = short_entry_price * 1005 / 1000;

        if current_price <= profit_target {
            orders.submit_limit_buy(profit_target, lot_size);
            short_position_active = false;
            short_ticks_held = 0;
        } else if current_price >= stop_loss {
            orders.submit_market_buy(lot_size);
            short_position_active = false;
            short_ticks_held = 0;
        } else if short_ticks_held > max_hold_ticks {
            orders.submit_market_buy(lot_size);
            short_position_active = false;
            short_ticks_held = 0;
        }
        return;
    }

    let current_price = market.price;
    let lower_bound = current_price * 98 / 100;
    let total_bid_volume = 0;

    let bid_price_0 = market.bid_price_0;
    let bid_vol_0 = market.bid_vol_0;
    if bid_price_0 >= lower_bound && bid_price_0 <= current_price {
        total_bid_volume += bid_vol_0;
    }

    let bid_price_1 = market.bid_price_1;
    let bid_vol_1 = market.bid_vol_1;
    if bid_price_1 >= lower_bound && bid_price_1 <= current_price {
        total_bid_volume += bid_vol_1;
    }

    let bid_price_2 = market.bid_price_2;
    let bid_vol_2 = market.bid_vol_2;
    if bid_price_2 >= lower_bound && bid_price_2 <= current_price {
        total_bid_volume += bid_vol_2;
    }

    let bid_price_3 = market.bid_price_3;
    let bid_vol_3 = market.bid_vol_3;
    if bid_price_3 >= lower_bound && bid_price_3 <= current_price {
        total_bid_volume += bid_vol_3;
    }

    let bid_price_4 = market.bid_price_4;
    let bid_vol_4 = market.bid_vol_4;
    if bid_price_4 >= lower_bound && bid_price_4 <= current_price {
        total_bid_volume += bid_vol_4;
    }

    if total_bid_volume > cluster_threshold {
        orders.submit_market_sell(lot_size);
        short_position_active = true;
        short_entry_price = current_price;
        short_ticks_held = 0;
    }
}