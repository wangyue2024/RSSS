// Global variables persist across ticks
let entered = false;
let entry_cost = 0;
let tp_order_placed = false;
let tp_order_id = 0;

fn on_tick() {
    // Only trade when market is open
    if !market.trading_enabled {
        return;
    }

    // Cancel any pending orders that aren't our take-profit order
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        if oid != tp_order_id {
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    // Random entry - 1% chance per tick if we haven't entered yet
    if !entered && rng.rand_bool(1) {
        // Buy 5-10 shares at market price
        let amount = rng.rand_int(5, 10);
        orders.submit_market_buy(amount);
        
        // Set entry cost from account average cost after purchase
        entry_cost = account.avg_cost;
        entered = true;
        tp_order_placed = false;
    }

    // If we have a position, manage our orders
    if entered && account.stock > 0 {
        // Calculate take-profit price (5% above cost, rounded to nearest dollar)
        let raw_tp = entry_cost * 105 / 100;
        let rounded_tp = ((raw_tp + 500_000) / 1_000_000) * 1_000_000;
        
        // Calculate stop-loss price (2% below cost)
        let stop_price = entry_cost * 98 / 100;

        // Place take-profit limit order if not already placed
        if !tp_order_placed {
            let result = orders.submit_limit_sell(rounded_tp, account.stock);
            if result >= 0 {
                tp_order_id = result;
                tp_order_placed = true;
            }
        }

        // Check stop-loss condition - if price drops below stop_price, market sell
        if market.price <= stop_price {
            if tp_order_placed {
                orders.submit_cancel(tp_order_id);
            }
            orders.submit_market_sell(account.stock);
            entered = false;
            tp_order_placed = false;
        }
    }
    
    // Reset if we have no stock
    if account.stock == 0 {
        entered = false;
        tp_order_placed = false;
    }
}