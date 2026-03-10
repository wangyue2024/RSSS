let initialized = false;
let prev_ma5 = 0;
let prev_ma20 = 0;
let pending_buy_order_id = -1;
let pending_buy_order_placed_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        prev_ma5 = market.ma_5;
        prev_ma20 = market.ma_20;
    }

    if !market.trading_enabled { return; }

    // Morning person constraint
    if market.tick >= market.total_ticks / 5 {
        // Cancel any pending orders if we leave the active period
        let pcount = my_orders.pending_count();
        let i = 0;
        while i < pcount {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        pending_buy_order_id = -1;
        return;
    }

    // High-frequency canceler logic: cancel stale limit orders
    let current_tick = market.tick;
    if pending_buy_order_id != -1 {
        let found = false;
        let pcount = my_orders.pending_count();
        let j = 0;
        while j < pcount {
            if my_orders.pending_id(j) == pending_buy_order_id {
                found = true;
                if current_tick - my_orders.pending_placed_tick(j) > 3 {
                    orders.submit_cancel(pending_buy_order_id);
                    pending_buy_order_id = -1;
                }
                break;
            }
            j += 1;
        }
        if !found {
            pending_buy_order_id = -1;
        }
    }

    // Crossover detection
    let curr_ma5 = market.ma_5;
    let curr_ma20 = market.ma_20;
    let golden_cross = prev_ma5 <= prev_ma20 && curr_ma5 > curr_ma20;
    let death_cross = prev_ma5 >= prev_ma20 && curr_ma5 < curr_ma20;

    // Buy signal: MA5 crosses above MA20
    if golden_cross {
        // Cancel any existing buy order
        if pending_buy_order_id != -1 {
            orders.submit_cancel(pending_buy_order_id);
            pending_buy_order_id = -1;
        }

        // Use market order to buy a fixed amount (e.g., 1000 shares)
        let buy_amount = 1000;
        if market.ask_price_0 > 0 {
            orders.submit_market_buy(buy_amount);
        } else {
            // Fallback limit order if no ask price
            let bid_price = market.bid_price_0;
            if bid_price > 0 {
                orders.submit_limit_buy(bid_price, buy_amount);
                pending_buy_order_id = my_orders.pending_id(my_orders.pending_count() - 1);
                pending_buy_order_placed_tick = current_tick;
            }
        }
    }

    // Sell signal: MA5 crosses below MA20 - sell all inventory at market
    if death_cross && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        // Also cancel any pending buy order
        if pending_buy_order_id != -1 {
            orders.submit_cancel(pending_buy_order_id);
            pending_buy_order_id = -1;
        }
    }

    // Update previous values for next tick
    prev_ma5 = curr_ma5;
    prev_ma20 = curr_ma20;
}