let initialized = false;
let base_lot_size = 0;
let current_lot_size = 0;
let last_trade_was_loss = false;
let last_avg_cost = 0;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        let five_pct_cap = account.total_equity * 500 / 10000;
        base_lot_size = rng.rand_int(1, five_pct_cap);
        if base_lot_size <= 0 {
            base_lot_size = 1;
        }
        current_lot_size = base_lot_size;
    }

    let count_pending = my_orders.pending_count();
    let i = 0;
    while i < count_pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let two_pct_of_price = market.price * 200 / 10000;
    if market.std_dev > two_pct_of_price {
        return;
    }

    if last_avg_cost != 0 && account.avg_cost != 0 {
        if (account.stock > 0 && market.price < account.avg_cost) || (account.stock < 0 && market.price > account.avg_cost) {
            last_trade_was_loss = true;
        } else {
            last_trade_was_loss = false;
        }
    }

    if last_trade_was_loss {
        let doubled = current_lot_size * 2;
        let five_pct_cap_current = account.total_equity * 500 / 10000;
        if doubled <= five_pct_cap_current {
            current_lot_size = doubled;
        }
    } else {
        current_lot_size = base_lot_size;
    }

    if current_lot_size < 1 {
        current_lot_size = 1;
    }

    let upper_band = market.ma_20 + 2 * market.std_dev;
    let lower_band = market.ma_20 - 2 * market.std_dev;

    if lower_band > 0 && account.cash >= lower_band * current_lot_size {
        orders.submit_limit_buy(lower_band, current_lot_size);
    }

    if account.stock >= current_lot_size {
        orders.submit_limit_sell(upper_band, current_lot_size);
    }

    last_avg_cost = account.avg_cost;
}