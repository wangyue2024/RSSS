let initialized = false;
let target_position = 50_000;
let slice_size = 0;
let ticks_between_slices = 10;
let tick_counter = 0;
let panic_threshold = 0;
let delayed_price_buffer = [];
let accumulated_position = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        
        slice_size = rng.rand_int(20000, 40000);
        if slice_size > target_position {
            slice_size = target_position;
        }
        
        panic_threshold = -rng.rand_int(500_000, 5_000_000);
        
        accumulated_position = account.stock;
    }
    
    if !market.trading_enabled { return; }
    
    delayed_price_buffer.push(market.price);
    if delayed_price_buffer.len() > 5 {
        delayed_price_buffer.remove(0);
    }
    
    if delayed_price_buffer.len() < 5 {
        return;
    }
    
    let current_price = delayed_price_buffer[0];
    
    if account.unrealized_pnl < panic_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    if accumulated_position >= target_position {
        return;
    }
    
    tick_counter += 1;
    if tick_counter >= ticks_between_slices {
        let remaining = target_position - accumulated_position;
        let buy_amount = slice_size;
        
        if buy_amount > remaining {
            buy_amount = remaining;
        }
        
        let max_buy_by_cash = account.cash / current_price;
        if buy_amount > max_buy_by_cash {
            buy_amount = max_buy_by_cash;
        }
        
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
            accumulated_position += buy_amount;
        }
        
        tick_counter = 0;
    }
}