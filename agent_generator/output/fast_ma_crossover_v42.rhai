let initialized = false;
let prev_relation = 0; // 0 = unknown, 1 = ma5 > ma20, -1 = ma5 < ma20
const MILLION = 1_000_000;
const HALF_MILLION = 500_000;

fn on_tick() {
    if !initialized {
        initialized = true;
        // Determine initial relation
        if market.ma_5 > market.ma_20 {
            prev_relation = 1;
        } else if market.ma_5 < market.ma_20 {
            prev_relation = -1;
        } else {
            prev_relation = 0;
        }
    }

    if !market.trading_enabled { return; }

    // Cancel all pending orders at every tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    // Determine current MA relation
    let curr_relation = 0;
    if market.ma_5 > market.ma_20 {
        curr_relation = 1;
    } else if market.ma_5 < market.ma_20 {
        curr_relation = -1;
    }

    // Check for crossovers
    // Buy signal: MA5 crosses above MA20 (prev <= 0, curr == 1)
    if curr_relation == 1 && prev_relation <= 0 {
        // Round market price to nearest million, then add 1 micro
        let rounded_price = ((market.price + HALF_MILLION) / MILLION) * MILLION;
        let bid_price = rounded_price + 1;
        // Use all cash to buy
        let max_shares = account.cash / bid_price;
        if max_shares > 0 {
            orders.submit_limit_buy(bid_price, max_shares);
        }
    }

    // Sell signal: MA5 crosses below MA20 (prev >= 0, curr == -1)
    if curr_relation == -1 && prev_relation >= 0 {
        // Round market price to nearest million, then add 1 micro (for sell, we still add 1 to be aggressive)
        let rounded_price = ((market.price + HALF_MILLION) / MILLION) * MILLION;
        let ask_price = rounded_price + 1;
        // Sell all inventory
        if account.stock > 0 {
            orders.submit_limit_sell(ask_price, account.stock);
        }
    }

    prev_relation = curr_relation;
}