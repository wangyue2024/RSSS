let initialized = false;
let recent_volumes = [];
let last_signal_tick = 0;
let cooldown_ticks = 20;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        cooldown_ticks = rng.rand_int(15, 25);
    }

    let current_tick = market.tick;

    // Cancel orders older than 3 ticks
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed = my_orders.pending_placed_tick(i);
        if current_tick - placed >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    // Update volume history
    recent_volumes.push(market.volume);
    if recent_volumes.len() > 20 {
        recent_volumes.remove(0);
    }

    // Check for exhaustion signal
    let vol_condition = false;
    let price_condition = market.high_20 > market.ma_60;

    if recent_volumes.len() >= 20 {
        let avg_vol = arr_mean(recent_volumes);
        if avg_vol > 0 {
            let threshold = avg_vol * 5 / 100;
            vol_condition = market.volume < threshold;
        }
    }

    let signal = price_condition && vol_condition;
    let cooldown_passed = current_tick - last_signal_tick > cooldown_ticks;
    let no_pending = my_orders.pending_count() == 0;

    if signal && cooldown_passed && no_pending {
        last_signal_tick = current_tick;

        // Round to nearest dollar (1_000_000 micros)
        let raw_price = market.price;
        let rounded_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;

        // Fixed order size
        let order_amount = 1000;

        orders.submit_limit_sell(rounded_price, order_amount);
    }
}