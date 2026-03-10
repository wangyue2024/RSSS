let initialized = false;
let base_lot_size = 100;
let current_lot_size = 100;
let last_trade_loss = false;
let last_realized_pnl = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(50, 200);
        current_lot_size = base_lot_size;
        last_realized_pnl = account.realized_pnl;
    }

    if !market.trading_enabled { return; }

    // Cancel all pending orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    // Martingale sizing based on last trade result
    if last_trade_loss {
        current_lot_size = current_lot_size * 2;
    } else {
        current_lot_size = base_lot_size;
    }

    // Calculate average volume over last 20 periods
    let lookback = 20;
    let hist_len = market.history_len();
    let total_vol = 0;
    let count = 0;
    let j = 0;
    while j < lookback && j < hist_len {
        total_vol += market.history_volume(j);
        count += 1;
        j += 1;
    }
    let avg_volume = 0;
    if count > 0 {
        avg_volume = total_vol / count;
    }

    // Check exhaustion conditions
    let price_above_ma = market.price > market.ma_60;
    let volume_near_zero = avg_volume > 0 && market.volume < (avg_volume * 10 / 100);

    // Update last trade result from realized pnl change
    let pnl_change = account.realized_pnl - last_realized_pnl;
    if pnl_change < 0 {
        last_trade_loss = true;
    } else if pnl_change > 0 {
        last_trade_loss = false;
    }
    last_realized_pnl = account.realized_pnl;

    // Execute strategy
    if price_above_ma && volume_near_zero {
        let amount = current_lot_size;
        if amount > 0 {
            orders.submit_market_sell(amount);
        }
    }
}