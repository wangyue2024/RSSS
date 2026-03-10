let initialized = false;
let lot_size = 0;
let in_position = false;
let std_dev_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size = rng.rand_int(1, 100);
    }

    if !market.trading_enabled { return; }

    std_dev_threshold = market.price * 1 / 100;

    let cancel_buy_orders = false;
    let cancel_sell_orders = false;
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        let side = my_orders.pending_side(i);
        if side == "buy" {
            cancel_buy_orders = true;
        } else {
            cancel_sell_orders = true;
        }
        i += 1;
    }

    if cancel_buy_orders || cancel_sell_orders {
        i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
    }

    if account.stock > 0 {
        in_position = true;
    } else {
        in_position = false;
    }

    let fill_cnt = my_orders.fill_count();
    i = 0;
    while i < fill_cnt {
        let side = my_orders.fill_side(i);
        if side == "buy" {
            in_position = true;
        } else if side == "sell" {
            in_position = false;
        }
        i += 1;
    }

    if in_position {
        let stop_price = account.avg_cost * 98 / 100;
        let remainder_stop = stop_price % 1_000_000;
        let rounded_stop = stop_price - remainder_stop;
        if remainder_stop >= 500_000 {
            rounded_stop = rounded_stop + 1_000_000;
        }

        let has_stop = false;
        i = 0;
        while i < my_orders.pending_count() {
            let side = my_orders.pending_side(i);
            let price = my_orders.pending_price(i);
            if side == "sell" && price == rounded_stop {
                has_stop = true;
                break;
            }
            i += 1;
        }

        if !has_stop && account.stock > 0 {
            orders.submit_limit_sell(rounded_stop, account.stock);
        }
    }

    if market.std_dev <= std_dev_threshold && !in_position && market.price > market.high_20 {
        let max_capital = account.total_equity * 5 / 100;
        let max_shares = max_capital / market.price;
        if max_shares > 0 {
            let lot = rng.rand_int(1, max_shares);
            if lot > 0 && account.cash >= market.price * lot {
                let current_price = market.price;
                let remainder = current_price % 1_000_000;
                let rounded = current_price - remainder;
                if remainder >= 500_000 {
                    rounded = rounded + 1_000_000;
                }
                let buy_price = rounded + 1;
                orders.submit_limit_buy(buy_price, lot);
            }
        }
    }
}