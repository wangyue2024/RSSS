let initialized = false;
let target_position = 0;
let slice_size = 0;
let panic_threshold = 0;
let tick_modulus = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        target_position = 50000;
        tick_modulus = 50;
        let cash_percent = rng.rand_int(30, 50);
        let price = if market.price > 0 { market.price } else { 1_000_000 };
        let max_possible = (account.cash * cash_percent) / (100 * price);
        slice_size = max_possible;
        if slice_size < 500 { slice_size = 500; }
        panic_threshold = -rng.rand_int(100_000, 500_000);
    }

    if !market.trading_enabled { return; }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        orders.submit_market_sell(account.stock);
        return;
    }

    if market.tick % tick_modulus != 0 { return; }

    let remaining = target_position - account.stock;
    if remaining <= 0 { return; }

    let to_buy = remaining;
    if to_buy > slice_size {
        to_buy = slice_size;
    }

    orders.submit_market_buy(to_buy);
}