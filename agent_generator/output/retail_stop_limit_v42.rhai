let entered = false;
let avg_cost = 0;
let lot_size = 100;
let take_profit_order_id = 0;
let stop_loss_triggered = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    // Cancel any pending orders if we have no position
    if !entered && !stop_loss_triggered {
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
    }
    
    // Check FOMO condition - price jumped >2% in last 5 ticks
    let fomo = false;
    if market.history_len() >= 5 {
        let price_5_ago = market.history_price(market.history_len() - 5);
        let change = (market.price - price_5_ago) * 100 / price_5_ago;
        if change > 2 && !entered {
            fomo = true;
        }
    }
    
    // FOMO entry
    if fomo && !entered {
        orders.submit_market_buy(lot_size);
        entered = true;
        avg_cost = account.avg_cost;
        take_profit_order_id = 0;
        stop_loss_triggered = false;
    }
    
    // Random entry (1% chance per tick)
    if !entered && !stop_loss_triggered && rng.rand_bool(1) {
        orders.submit_market_buy(lot_size);
        entered = true;
        avg_cost = account.avg_cost;
        take_profit_order_id = 0;
        stop_loss_triggered = false;
    }
    
    // If we have a position, manage exits
    if entered {
        // Check if take profit order needs to be placed
        if take_profit_order_id == 0 {
            // Calculate take profit price (5% above cost)
            let tp_price_raw = avg_cost * 105 / 100;
            // Round to nearest integer dollar
            let tp_price = ((tp_price_raw + 500_000) / 1_000_000) * 1_000_000;
            
            // Place take profit limit order
            take_profit_order_id = orders.submit_limit_sell(tp_price, lot_size);
        }
        
        // Check stop loss condition (2% below cost)
        let stop_loss_price = avg_cost * 98 / 100;
        if market.price <= stop_loss_price {
            orders.submit_market_sell(lot_size);
            
            // Cancel take profit order if still pending
            if take_profit_order_id != 0 {
                orders.submit_cancel(take_profit_order_id);
                take_profit_order_id = 0;
            }
            
            // Check if last trade was a loss for martingale
            if market.price < avg_cost {
                lot_size = lot_size * 2;
            }
            
            entered = false;
            avg_cost = 0;
            stop_loss_triggered = true;
        }
        
        // Check if take profit was filled
        let fill_count = my_orders.fill_count();
        let i = 0;
        while i < fill_count {
            let fill_id = my_orders.fill_id(i);
            let fill_side = my_orders.fill_side(i);
            if fill_side == 1 && take_profit_order_id != 0 { // 1 = sell
                // Check if this fill corresponds to our take profit order
                // (simplified check - in real scenario we'd need better tracking)
                entered = false;
                avg_cost = 0;
                take_profit_order_id = 0;
                stop_loss_triggered = false;
                break;
            }
            i += 1;
        }
    }
    
    // Reset stop_loss_triggered after a tick if we have no position
    if !entered && stop_loss_triggered {
        stop_loss_triggered = false;
    }
}