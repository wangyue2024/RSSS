let initialized = false;
let base_lot_size = 0;
let lot_size = 0;
let last_trade_side = -1;
let last_trade_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let cash_in_shares = account.cash / market.price;
        base_lot_size = rng.rand_int(1, cash_in_shares * 50 / 100);
        lot_size = base_lot_size;
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let idx = fill_cnt - 1;
        last_trade_side = my_orders.fill_side(idx);
        last_trade_price = my_orders.fill_price(idx);
    }

    let is_loss = false;
    if last_trade_side == 0 && market.price < last_trade_price {
        is_loss = true;
    }
    if last_trade_side == 1 && market.price > last_trade_price {
        is_loss = true;
    }

    if is_loss {
        lot_size = lot_size * 2;
    } else {
        lot_size = base_lot_size;
    }

    let roll = rng.rand_int(0, 99);

    if roll < 5 {
        let offset = rng.rand_int(0, 1000);
        let price = market.price - offset;
        if price > 0 {
            orders.submit_limit_buy(price, lot_size);
        }
    }

    if roll > 95 && market.price > account.avg_cost {
        let offset = rng.rand_int(0, 1000);
        let price = market.price + offset;
        orders.submit_limit_sell(price, lot_size);
    }
}