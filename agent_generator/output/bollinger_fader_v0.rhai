let initialized = false;
let order_amount = 100;
let delayed_price = 0;
let price_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled {
        return;
    }

    // Update delayed price queue
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    if price_history.len() == 5 {
        delayed_price = price_history[0];
    }

    // Lazy trader: only act every 50 ticks
    if market.tick % 50 != 0 {
        return;
    }

    // Cancel all pending orders
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    // Use delayed price (5 ticks old) for decisions
    if delayed_price == 0 {
        return;
    }

    // Calculate Bollinger Bands (ma_20 +/- 2 * std_dev)
    let lower_band = market.ma_20 - 2 * market.std_dev;
    let upper_band = market.ma_20 + 2 * market.std_dev;

    // Place limit buy at lower band
    orders.submit_limit_buy(lower_band, order_amount);

    // Diamond hands: only sell if price > avg_cost
    if delayed_price > account.avg_cost {
        orders.submit_limit_sell(upper_band, order_amount);
    }
}