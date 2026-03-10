let target_position = 50_000;
let slice_size = 500;
let frequency_ticks = 10;
let tick_counter = 0;
let last_order_id = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    let current_position = account.stock;
    if current_position >= target_position {
        return;
    }
    
    tick_counter += 1;
    if tick_counter < frequency_ticks {
        return;
    }
    
    tick_counter = 0;
    
    if last_order_id != 0 {
        orders.submit_cancel(last_order_id);
        last_order_id = 0;
    }
    
    let best_ask = market.ask_price_0;
    if best_ask > 0 {
        let limit_price = best_ask + 1;
        last_order_id = orders.submit_limit_buy(limit_price, slice_size);
    }
}