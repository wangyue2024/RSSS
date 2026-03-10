let initialized = false;
let my_buy_order_id = -1;
let my_sell_order_id = -1;
let threshold_bps = 50;
let position_target = 1000;

fn round_to_dollar(price) {
    let base = (price / 1_000_000) * 1_000_000;
    let remainder = price % 1_000_000;
    if remainder >= 500_000 {
        base + 1_000_000
    } else {
        base
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
        threshold_bps = rng.rand_int(30, 80);
    }

    if !market.trading_enabled { return; }

    let morning_active = market.tick < market.total_ticks / 5;
    if !morning_active {
        let pending_cnt = my_orders.pending_count();
        let j = 0;
        while j < pending_cnt {
            let oid = my_orders.pending_id(j);
            orders.submit_cancel(oid);
            j += 1;
        }
        my_buy_order_id = -1;
        my_sell_order_id = -1;
        return;
    }

    let vwap = market.vwap;
    let current_price = market.price;
    let threshold = vwap * threshold_bps / 10000;

    let need_new_buy = false;
    let need_new_sell = false;

    if my_buy_order_id != -1 {
        let found = false;
        let i = 0;
        while i < my_orders.pending_count() {
            if my_orders.pending_id(i) == my_buy_order_id {
                found = true;
                break;
            }
            i += 1;
        }
        if !found {
            my_buy_order_id = -1;
            need_new_buy = true;
        }
    } else {
        need_new_buy = true;
    }

    if my_sell_order_id != -1 {
        let found = false;
        let i = 0;
        while i < my_orders.pending_count() {
            if my_orders.pending_id(i) == my_sell_order_id {
                found = true;
                break;
            }
            i += 1;
        }
        if !found {
            my_sell_order_id = -1;
            need_new_sell = true;
        }
    } else {
        need_new_sell = true;
    }

    if current_price < vwap - threshold && need_new_buy {
        let raw_bid = current_price;
        let rounded_bid = round_to_dollar(raw_bid);
        let final_bid = rounded_bid + 1;
        let buy_amount = position_target - account.stock;
        if buy_amount > 0 {
            my_buy_order_id = orders.submit_limit_buy(final_bid, buy_amount);
        }
    }

    if account.stock > 0 && need_new_sell {
        let rounded_ask = round_to_dollar(vwap);
        my_sell_order_id = orders.submit_limit_sell(rounded_ask, account.stock);
    }
}