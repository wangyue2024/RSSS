let initialized = false;
let lot_size = 0;
let panic_threshold = 0;
let order_tracker = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_lot_value = account.total_equity * 5 / 100;
        let max_lot_shares = max_lot_value / market.price;
        if max_lot_shares < 1 {
            max_lot_shares = 1;
        }
        lot_size = rng.rand_int(1, max_lot_shares);
        panic_threshold = -rng.rand_int(50_000, 500_000);
    }

    if !market.trading_enabled { return; }

    let current_tick = market.tick;

    let i = 0;
    while i < my_orders.pending_count() {
        let oid = my_orders.pending_id(i);
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let high_vol = market.std_dev > (market.price * 300 / 10000);
    if high_vol {
        return;
    }

    let rand_val = rng.rand_int(0, 99);

    if rand_val < 5 && account.cash > 0 {
        let qty = rng.rand_int(1, lot_size);
        let price_offset = rng.rand_int(-100, 100);
        let target_price = market.price + market.price * price_offset / 10000;
        if target_price < 1 {
            target_price = 1;
        }
        orders.submit_limit_buy(target_price, qty);
    } else if rand_val > 95 && account.stock > 0 {
        let qty = rng.rand_int(1, lot_size);
        let price_offset = rng.rand_int(-100, 100);
        let target_price = market.price + market.price * price_offset / 10000;
        if target_price < 1 {
            target_price = 1;
        }
        orders.submit_limit_sell(target_price, qty);
    }
}