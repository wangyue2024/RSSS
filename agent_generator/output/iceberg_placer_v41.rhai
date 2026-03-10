// Global variables persist across ticks
let initialized = false;
let iceberg_total = 0;
let sold_so_far = 0;
let visible_amount = 0;
let current_order_id = -1;
let order_placed_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        // Initialize with RNG for variability
        iceberg_total = rng.rand_int(50_000, 200_000);
        visible_amount = rng.rand_int(100, 500);
    }
    
    if !market.trading_enabled { return; }
    
    // Process any fills from last tick
    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        let fill_id = my_orders.fill_id(i);
        if fill_id == current_order_id {
            let fill_amt = my_orders.fill_amount(i);
            sold_so_far += fill_amt;
            // Order was (at least partially) filled, reset tracking
            current_order_id = -1;
        }
        i += 1;
    }
    
    // Cancel any other pending orders (safety)
    let pending_cnt = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt {
        let oid = my_orders.pending_id(j);
        if oid != current_order_id {
            orders.submit_cancel(oid);
        }
        j += 1;
    }
    
    // Impatient cancellation: if order pending > 3 ticks, cancel
    if current_order_id != -1 {
        if market.tick - order_placed_tick > 3 {
            orders.submit_cancel(current_order_id);
            current_order_id = -1;
        }
    }
    
    // Place new visible order if needed
    if current_order_id == -1 && sold_so_far < iceberg_total {
        let remaining = iceberg_total - sold_so_far;
        let order_amt = visible_amount;
        if order_amt > remaining {
            order_amt = remaining;
        }
        
        if order_amt > 0 {
            // Place at best ask price
            let ask_price = market.ask_price_0;
            if ask_price > 0 {
                orders.submit_limit_sell(ask_price, order_amt);
                // Track this order
                current_order_id = -1;
                // Find the order we just placed
                let k = 0;
                let pending_now = my_orders.pending_count();
                while k < pending_now {
                    let oid = my_orders.pending_id(k);
                    let oprice = my_orders.pending_price(k);
                    let oamt = my_orders.pending_amount(k);
                    if oprice == ask_price && oamt == order_amt {
                        current_order_id = oid;
                        order_placed_tick = market.tick;
                        break;
                    }
                    k += 1;
                }
            }
        }
    }
}