let initialized = false;
let last_price = 0;
let last_trade_was_loss = false;
let base_lot_size = 0;
let current_lot_size = 0;
let offset_micros = 1000;

fn on_tick() {
    if !initialized {
        if market.trading_enabled && market.price > 0 {
            last_price = market.price;
            let max_shares = (account.cash * 50 / 100) / market.price;
            if max_shares < 1 {
                max_shares = 1;
            }
            base_lot_size = rng.rand_int(max_shares / 2, max_shares);
            current_lot_size = base_lot_size;
            initialized = true;
        }
        return;
    }

    if !market.trading_enabled {
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.stock > 0 {
        if market.price < account.avg_cost {
            last_trade_was_loss = true;
        } else {
            last_trade_was_loss = false;
        }
    } else if account.stock < 0 {
        if market.price > account.avg_cost {
            last_trade_was_loss = true;
        } else {
            last_trade_was_loss = false;
        }
    } else {
        last_trade_was_loss = false;
    }

    let max_shares = (account.cash * 50 / 100) / market.price;
    if max_shares < 1 {
        max_shares = 1;
    }
    base_lot_size = max_shares;

    if last_trade_was_loss {
        current_lot_size = current_lot_size * 2;
        if current_lot_size > base_lot_size * 8 {
            current_lot_size = base_lot_size;
        }
    } else {
        current_lot_size = base_lot_size;
    }

    if market.price < last_price {
        let target_price = market.price - offset_micros;
        let rounded_price = ((target_price + 500_000) / 1_000_000) * 1_000_000;
        if current_lot_size > 0 && account.cash >= rounded_price * current_lot_size {
            orders.submit_limit_buy(rounded_price, current_lot_size);
        }
    } else if market.price > last_price {
        let target_price = market.price + offset_micros;
        let rounded_price = ((target_price + 500_000) / 1_000_000) * 1_000_000;
        if current_lot_size > 0 {
            orders.submit_limit_sell(rounded_price, current_lot_size);
        }
    }

    last_price = market.price;
}