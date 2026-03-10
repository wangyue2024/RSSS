let initialized = false;
let base_lot_size = 0;
let current_lot_size = 0;
let prev_in_loss = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        let capital_5percent = account.total_equity * 5 / 100;
        let max_shares = capital_5percent / market.price;
        if max_shares < 1 {
            base_lot_size = 1;
        } else {
            base_lot_size = rng.rand_int(1, max_shares);
        }
        current_lot_size = base_lot_size;
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let std_dev_threshold = market.price * 2 / 100;
    if market.std_dev > std_dev_threshold { return; }

    let in_loss = market.price < account.avg_cost;
    if in_loss && !prev_in_loss {
        current_lot_size = current_lot_size * 2;
    }
    if !in_loss && prev_in_loss {
        current_lot_size = base_lot_size;
    }
    prev_in_loss = in_loss;

    let r = rng.rand_int(0, 99);
    let max_offset = market.price * 2 / 100;

    if r < 5 {
        let offset = rng.rand_int(-max_offset, 0);
        let price = market.price + offset;
        if price < 0 { price = 1; }
        let min_amount = current_lot_size / 2;
        if min_amount < 1 { min_amount = 1; }
        let max_amount = current_lot_size * 3 / 2;
        let amount = rng.rand_int(min_amount, max_amount);
        orders.submit_limit_buy(price, amount);
    }

    if r > 95 && market.price > account.avg_cost {
        let offset = rng.rand_int(0, max_offset);
        let price = market.price + offset;
        let min_amount = current_lot_size / 2;
        if min_amount < 1 { min_amount = 1; }
        let max_amount = current_lot_size * 3 / 2;
        let amount = rng.rand_int(min_amount, max_amount);
        orders.submit_limit_sell(price, amount);
    }
}