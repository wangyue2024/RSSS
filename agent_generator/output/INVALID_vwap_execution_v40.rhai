// Generation Failed after 5 retries.
// Last error: Violated NO FLOATS rule. Found floating point numbers like 0.5 or 12.34.
// Global variables persist across ticks
let initialized = false;
let total_target = 10000;
let remaining_target = total_target;
let last_fill_price = 0;
let loss_multiplier = 1;
let base_lot_size = 100;
let volume_lookback = 20;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(50, 200);
        volume_lookback = rng.rand_int(10, 30);
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

    // Update last fill price from recent fills
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        // Get the most recent fill (last in the array)
        let last_fill_idx = fill_cnt - 1;
        last_fill_price = my_orders.fill_price(last_fill_idx);
    }

    // Check if last trade was a loss
    if last_fill_price > 0 && market.price > 0 {
        if market.price < last_fill_price {
            loss_multiplier = 2;
        } else {
            loss_multiplier = 1;
        }
    }

    // Update remaining target based on current holdings
    remaining_target = total_target - account.stock;
    if remaining_target <= 0 { return; }

    // Calculate volume ratio (current vs average)
    let current_vol = market.volume;
    let avg_vol = 0;
    let hist_len = market.history_len();
    if hist_len > 0 {
        let lookback = if volume_lookback < hist_len { volume_lookback } else { hist_len };
        let vol_sum = 0;
        let j = 0;
        while j < lookback {
            vol_sum += market.history_volume(j);
            j += 1;
        }
        avg_vol = vol_sum / lookback;
    }

    let volume_ratio = 1000; // default 1.0
    if avg_vol > 0 {
        volume_ratio = (current_vol * 1000) / avg_vol;
        if volume_ratio < 500 { volume_ratio = 500; } // min 0.5
        if volume_ratio > 2000 { volume_ratio = 2000; } // max 2.0
    }

    // Calculate dynamic lot size
    let dynamic_lot = (base_lot_size * volume_ratio * loss_multiplier) / 1000;
    if dynamic_lot < 1 { dynamic_lot = 1; }

    // Ensure we don't exceed remaining target
    let order_amount = dynamic_lot;
    if order_amount > remaining_target {
        order_amount = remaining_target;
    }

    // Place limit buy order at best ask
    if order_amount > 0 && market.ask_price_0 > 0 {
        orders.submit_limit_buy(market.ask_price_0, order_amount);
    }
}