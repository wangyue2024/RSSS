// Global variables persist across ticks
let buy_order_id = -1;
let sell_order_id = -1;
let buy_order_placed_tick = -1;
let sell_order_placed_tick = -1;

fn on_tick() {
    // Morning Person: Only trade in first 20% of session
    if market.tick * 5 >= market.total_ticks {
        // Cancel any remaining orders if we're past the active period
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        buy_order_id = -1;
        sell_order_id = -1;
        return;
    }

    if !market.trading_enabled { return; }

    // Calculate Bollinger Bands (integer arithmetic only)
    let middle_band = market.ma_20;
    let std_dev = market.std_dev;
    let lower_band = middle_band - 2 * std_dev;
    let upper_band = middle_band + 2 * std_dev;

    // Handle existing buy order
    let current_buy_active = false;
    if buy_order_id != -1 {
        // Check if still pending
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            if my_orders.pending_id(i) == buy_order_id {
                current_buy_active = true;
                // High-Frequency Canceler: Cancel if older than 3 ticks
                if market.tick - buy_order_placed_tick >= 3 {
                    orders.submit_cancel(buy_order_id);
                    buy_order_id = -1;
                    current_buy_active = false;
                }
                break;
            }
            i += 1;
        }
        if !current_buy_active {
            buy_order_id = -1;
        }
    }

    // Handle existing sell order
    let current_sell_active = false;
    if sell_order_id != -1 {
        // Check if still pending
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            if my_orders.pending_id(i) == sell_order_id {
                current_sell_active = true;
                // High-Frequency Canceler: Cancel if older than 3 ticks
                if market.tick - sell_order_placed_tick >= 3 {
                    orders.submit_cancel(sell_order_id);
                    sell_order_id = -1;
                    current_sell_active = false;
                }
                break;
            }
            i += 1;
        }
        if !current_sell_active {
            sell_order_id = -1;
        }
    }

    // Place new buy order if none active
    if !current_buy_active {
        // Use 1 share for simplicity, can be adjusted
        let buy_amount = 1;
        buy_order_id = orders.submit_limit_buy(lower_band, buy_amount);
        buy_order_placed_tick = market.tick;
    }

    // Place new sell order if none active AND price > avg_cost (Stubborn Holder)
    if !current_sell_active && market.price > account.avg_cost && account.stock > 0 {
        // Use 1 share for simplicity, can be adjusted
        let sell_amount = 1;
        sell_order_id = orders.submit_limit_sell(upper_band, sell_amount);
        sell_order_placed_tick = market.tick;
    }
}