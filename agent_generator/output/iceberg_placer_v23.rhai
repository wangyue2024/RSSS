let initialized = false;
let total_to_sell = 0;
let tip_size = 0;
let remaining = 0;
let last_5_prices = [];
let last_5_asks = [];
let current_tip_id = -1;

fn on_tick() {
    if !initialized {
        initialized = true;
        total_to_sell = 10000;
        tip_size = 100;
        remaining = total_to_sell;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel current tip if exists
    if current_tip_id != -1 {
        orders.submit_cancel(current_tip_id);
        current_tip_id = -1;
    }
    
    // Update delayed data buffers
    last_5_prices.push(market.price);
    if last_5_prices.len() > 5 {
        last_5_prices.remove(0);
    }
    
    last_5_asks.push(market.ask_price_0);
    if last_5_asks.len() > 5 {
        last_5_asks.remove(0);
    }
    
    // Need at least 5 ticks of history
    if last_5_prices.len() < 5 { return; }
    
    // Check for recent fills (delayed reaction)
    let fill_cnt = my_orders.fill_count();
    let filled_this_tick = false;
    for i in 0..fill_cnt {
        let fill_tick = my_orders.fill_tick(i);
        if market.tick - fill_tick >= 5 {
            filled_this_tick = true;
            break;
        }
    }
    
    // Replenish if had a fill
    if filled_this_tick && remaining > 0 {
        // Use delayed ask price from 5 ticks ago
        let delayed_ask = last_5_asks[0];
        if delayed_ask > 0 && remaining > 0 {
            let sell_amount = tip_size;
            if sell_amount > remaining {
                sell_amount = remaining;
            }
            let order_id = orders.submit_limit_sell(delayed_ask, sell_amount);
            if order_id != -1 {
                current_tip_id = order_id;
                remaining -= sell_amount;
            }
        }
    }
    
    // Place initial tip if no order exists
    if current_tip_id == -1 && remaining > 0 {
        let delayed_ask = last_5_asks[0];
        if delayed_ask > 0 {
            let sell_amount = tip_size;
            if sell_amount > remaining {
                sell_amount = remaining;
            }
            let order_id = orders.submit_limit_sell(delayed_ask, sell_amount);
            if order_id != -1 {
                current_tip_id = order_id;
                remaining -= sell_amount;
            }
        }
    }
}