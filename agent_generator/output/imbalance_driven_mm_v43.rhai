let initialized = false;
let base_spread = 20_000;
let base_lot = 100;
let current_lot = 100;
let max_lot = 3200;
let last_trade_loss = false;
let imbalance_sensitivity = 10;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        base_spread = 20_000;
        base_lot = 100;
        current_lot = base_lot;
        max_lot = base_lot * 32;
        last_trade_loss = false;
        imbalance_sensitivity = rng.rand_int(5, 20);
    }

    if market.tick >= market.total_ticks / 5 {
        let pc = my_orders.pending_count();
        let i = 0;
        while i < pc {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }

    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let last_idx = fill_cnt - 1;
        let fill_price = my_orders.fill_price(last_idx);
        let fill_side = my_orders.fill_side(last_idx);
        let current_mid = (market.bid_price_0 + market.ask_price_0) / 2;
        if (fill_side == 0 && current_mid < fill_price) || (fill_side == 1 && current_mid > fill_price) {
            last_trade_loss = true;
        } else {
            last_trade_loss = false;
        }
    }

    if last_trade_loss {
        current_lot = current_lot * 2;
        if current_lot > max_lot {
            current_lot = max_lot;
        }
    } else {
        current_lot = base_lot;
    }

    let imbalance = market.order_imbalance;
    let adjustment = imbalance * imbalance_sensitivity;

    let mid_price = 0;
    if market.bid_price_0 > 0 && market.ask_price_0 > 0 {
        mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    } else {
        mid_price = market.price;
    }

    let adjusted_mid = mid_price + adjustment;
    let bid_price = adjusted_mid - base_spread / 2;
    let ask_price = adjusted_mid + base_spread / 2;

    let pc = my_orders.pending_count();
    let i = 0;
    while i < pc {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    if bid_price > 0 && current_lot > 0 {
        orders.submit_limit_buy(bid_price, current_lot);
    }
    if ask_price > 0 && current_lot > 0 {
        orders.submit_limit_sell(ask_price, current_lot);
    }
}