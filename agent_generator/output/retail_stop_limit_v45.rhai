// Global state
let entered_position = false;
let initial_buy_tick = -1;
let take_profit_order_id = -1;
let stop_loss_triggered = false;
let fomo_triggered = false;
let take_profit_placed_tick = -1;
let random_entry_decided = false;
let entry_price = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    // Reset if position closed
    if entered_position && account.stock == 0 {
        entered_position = false;
        initial_buy_tick = -1;
        take_profit_order_id = -1;
        stop_loss_triggered = false;
        fomo_triggered = false;
        take_profit_placed_tick = -1;
        random_entry_decided = false;
        entry_price = 0;
    }
    
    // FOMO check - price jumped 2%+ in short window
    let history_len = market.history_len();
    if history_len >= 3 && !fomo_triggered && !stop_loss_triggered {
        let price_now = market.price;
        let price_prev = market.history_price(2);
        if price_prev > 0 {
            let pct_change = (price_now - price_prev) * 10000 / price_prev;
            if pct_change > 200 {  // 2% increase
                fomo_triggered = true;
                // Cancel existing orders
                let pending_cnt = my_orders.pending_count();
                let i = 0;
                while i < pending_cnt {
                    let oid = my_orders.pending_id(i);
                    orders.submit_cancel(oid);
                    i += 1;
                }
                // Market buy with 20% of cash
                let buy_amount = account.cash * 20 / (100 * 1_000_000);
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount);
                    entered_position = true;
                    entry_price = market.price;
                    initial_buy_tick = market.tick;
                }
                return;
            }
        }
    }
    
    // Random entry once
    if !random_entry_decided && !entered_position && !fomo_triggered {
        random_entry_decided = true;
        if rng.rand_bool(30) {  // 30% chance to enter
            // Market buy with 25% of cash
            let buy_amount = account.cash * 25 / (100 * 1_000_000);
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
                entered_position = true;
                entry_price = market.price;
                initial_buy_tick = market.tick;
            }
        }
    }
    
    // If in position, manage orders
    if entered_position && account.stock > 0 && !stop_loss_triggered {
        // Check stop-loss (2% below entry)
        let stop_price = entry_price * 98 / 100;
        if market.price <= stop_price {
            stop_loss_triggered = true;
            // Cancel any existing limit orders
            let pending_cnt = my_orders.pending_count();
            let i = 0;
            while i < pending_cnt {
                let oid = my_orders.pending_id(i);
                orders.submit_cancel(oid);
                i += 1;
            }
            // Market sell all
            orders.submit_market_sell(account.stock);
            return;
        }
        
        // Manage take-profit order
        let tp_active = false;
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            if my_orders.pending_id(i) == take_profit_order_id {
                tp_active = true;
                // Check if order stale (3+ ticks)
                if market.tick - take_profit_placed_tick > 3 {
                    orders.submit_cancel(take_profit_order_id);
                    tp_active = false;
                }
                break;
            }
            i += 1;
        }
        
        // Place/replace take-profit (5% above entry)
        if !tp_active {
            let tp_price = entry_price * 105 / 100;
            let tp_amount = account.stock;
            if tp_amount > 0 {
                take_profit_order_id = orders.submit_limit_sell(tp_price, tp_amount);
                take_profit_placed_tick = market.tick;
            }
        }
    }
}