let initialized = false;
let stop_loss_threshold = 0;
let delayed_price_history = [];
let delayed_volume_history = [];
let target_position = 0;
let base_order_size = 0;
let accumulated_stock = 0;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        stop_loss_threshold = -1 * rng.rand_int(10000, 50000);
        base_order_size = rng.rand_int(50, 200);
        target_position = rng.rand_int(5000, 15000);
        accumulated_stock = 0;
    }

    // Panic stop-loss check
    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    // Store current data for delayed reaction
    delayed_price_history.push(market.price);
    delayed_volume_history.push(market.volume);
    
    if delayed_price_history.len() > 5 {
        delayed_price_history.remove(0);
        delayed_volume_history.remove(0);
    }

    // Need at least 5 ticks of history to act
    if delayed_price_history.len() < 5 {
        return;
    }

    // Cancel all pending orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    // Process fills to update accumulated stock
    let fill_cnt = my_orders.fill_count();
    let j = 0;
    while j < fill_cnt {
        let side = my_orders.fill_side(j);
        let amount = my_orders.fill_amount(j);
        if side == 0 {
            accumulated_stock += amount;
        } else if side == 1 {
            accumulated_stock -= amount;
        }
        j += 1;
    }

    // Use 5-tick-old data for decision making
    let delayed_price = delayed_price_history[0];
    let delayed_volume = delayed_volume_history[0];

    // Calculate dynamic slice size based on volume (relative to average of last 5 delayed volumes)
    let vol_sum = 0;
    let k = 0;
    while k < delayed_volume_history.len() {
        vol_sum += delayed_volume_history[k];
        k += 1;
    }
    let avg_vol = vol_sum / delayed_volume_history.len();
    let volume_ratio = if avg_vol > 0 { delayed_volume * 100 / avg_vol } else { 100 };
    
    let dynamic_slice = base_order_size * volume_ratio / 100;
    let slice_size = clamp_val(dynamic_slice, 10, 500);

    // Calculate remaining to buy
    let remaining_to_buy = target_position - accumulated_stock;
    if remaining_to_buy <= 0 {
        return;
    }

    let order_amount = clamp_val(slice_size, 1, remaining_to_buy);

    // Round price to nearest dollar (1,000,000 micros)
    let rounded_price = ((delayed_price + 500_000) / 1_000_000) * 1_000_000;

    // Place limit buy at rounded price
    if order_amount > 0 && rounded_price > 0 {
        orders.submit_limit_buy(rounded_price, order_amount);
    }
}