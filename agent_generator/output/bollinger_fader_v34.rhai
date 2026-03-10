let initialized = false;
let order_amount = 100;
let price_buffer = [];
let ma20_buffer = [];
let std_buffer = [];

fn on_tick() {
    if !initialized {
        initialized = true;
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

    // Store current market data into buffers
    price_buffer.push(market.price);
    ma20_buffer.push(market.ma_20);
    std_buffer.push(market.std_dev);

    // Keep only last 5 entries
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
        ma20_buffer.remove(0);
        std_buffer.remove(0);
    }

    // React only when we have full 5-tick old data
    if price_buffer.len() == 5 {
        let delayed_price = price_buffer[0];
        let delayed_ma_20 = ma20_buffer[0];
        let delayed_std_dev = std_buffer[0];

        // Calculate Bollinger Bands (integer arithmetic)
        let band_width = 2 * delayed_std_dev;
        let lower_band = delayed_ma_20 - band_width;
        let upper_band = delayed_ma_20 + band_width;

        // Place limit buy order at lower band if we have enough cash
        let buy_cost = order_amount * lower_band;
        if account.cash >= buy_cost {
            orders.submit_limit_buy(lower_band, order_amount);
        }

        // Diamond Hands: Only sell if price > average cost AND we have stock
        if account.stock >= order_amount && upper_band > account.avg_cost {
            orders.submit_limit_sell(upper_band, order_amount);
        }
    }
}