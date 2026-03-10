let initialized = false;
let target_position = 0;
let slice_size = 0;
let ticks_between = 0;
let panic_threshold = 0;
let last_buy_tick = -1000;

fn on_tick() {
    if !initialized {
        target_position = rng.rand_int(40000, 60000);
        slice_size = rng.rand_int(400, 600);
        ticks_between = rng.rand_int(8, 12);
        panic_threshold = -rng.rand_int(50_000_000, 200_000_000);
        last_buy_tick = market.tick;
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let remaining = target_position - account.stock;

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let tick_diff = market.tick - last_buy_tick;
    if remaining > 0 && tick_diff >= ticks_between {
        let buy_amt = slice_size;
        if buy_amt > remaining {
            buy_amt = remaining;
        }
        if buy_amt > 0 {
            orders.submit_market_buy(buy_amt);
            last_buy_tick = market.tick;
        }
    }
}