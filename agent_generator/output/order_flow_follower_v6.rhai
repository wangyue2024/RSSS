let active = false;
let trade_amount = 100;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    // Morning person: only first 20% of session
    if market.tick * 5 < market.total_ticks {
        if !active {
            active = true;
        }
        
        // Cancel any existing orders
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        // Order flow logic: buy if buy_volume > 3 * sell_volume
        if market.buy_volume > 3 * market.sell_volume {
            let bid_price = market.bid_price_0 + 1; // Off-by-one pumper
            if bid_price > 0 {
                // Ensure we have enough cash
                let cost = bid_price * trade_amount;
                if cost <= account.cash {
                    orders.submit_limit_buy(bid_price, trade_amount);
                }
            }
        }
    } else if active {
        // Session ended our active period, cancel all orders
        active = false;
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
    }
}