let initialized = false;
let target_position = 50_000;
let slice_size = 500;
let tick_interval = 10;
let last_buy_tick = -1000;
let fomo_triggered = false;
let price_history = [];
let fomo_window = 5;

fn on_tick() {
    if !initialized {
        initialized = true;
        price_history = [];
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    price_history.push(market.price);
    if price_history.len() > fomo_window {
        price_history.remove(0);
    }
    
    let current_position = account.stock;
    let remaining_to_buy = target_position - current_position;
    
    if remaining_to_buy <= 0 {
        return;
    }
    
    if price_history.len() == fomo_window {
        let oldest_price = price_history[0];
        let current_price = price_history[price_history.len() - 1];
        if oldest_price > 0 {
            let percent_change = (current_price - oldest_price) * 10000 / oldest_price;
            if percent_change > 200 {
                fomo_triggered = true;
            }
        }
    }
    
    if fomo_triggered {
        if remaining_to_buy > 0 {
            orders.submit_market_buy(remaining_to_buy);
        }
        return;
    }
    
    let ticks_since_last = market.tick - last_buy_tick;
    if ticks_since_last >= tick_interval && remaining_to_buy > 0 {
        let buy_amount = slice_size;
        if buy_amount > remaining_to_buy {
            buy_amount = remaining_to_buy;
        }
        orders.submit_market_buy(buy_amount);
        last_buy_tick = market.tick;
    }
}