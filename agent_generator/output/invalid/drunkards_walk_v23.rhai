// Global variables
let initialized = false;

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

    // Generate random action
    let r = rng.rand_int(0, 99);

    // 5% chance to buy randomly
    if r < 5 {
        // Random quantity 1-100 shares
        let qty = rng.rand_int(1, 100);
        // Random price offset +/- 50 cents (500,000 micros)
        let offset = rng.rand_int(-500_000, 500_000);
        let price = market.price + offset;
        // Ensure price is positive
        if price > 0 {
            orders.submit_limit_buy(price, qty);
        }
    }
    // 4% chance to sell randomly (96,97,98,99 -> 4 numbers = 4%)
    else if r > 95 {
        // Diamond hands: only sell if price > average cost AND we have stock
        if market.price > account.avg_cost && account.stock > 0 {
            // Random quantity up to what we hold, minimum 1
            let max_qty = account.stock;
            if max_qty > 0 {
                let qty = rng.rand_int(1, max_qty);
                // Random price offset +0 to +100 cents (favor profit)
                let offset = rng.rand_int(0, 1_000_000);
                let price = market.price + offset;
                orders.submit_limit_sell(price, qty);
            }
        }
    }
}