let initialized = false;
let base_lot = 1000;
let current_lot = base_lot;
let last_slope = 0;
let slope_buffer = [];
let price_buffer = [];
let last_trade_profit = 0;
let pending_order_ticks = {};

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(800, 1200);
        current_lot = base_lot;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    price_buffer.push(market.price);
    if price_buffer.len() > 30 {
        price_buffer.remove(0);
    }
    
    if price_buffer.len() >= 10 {
        let delayed_prices = [];
        let i = 5;
        while i < price_buffer.len() {
            delayed_prices.push(price_buffer[i]);
            i += 1;
        }
        
        if delayed_prices.len() >= 5 {
            let current_slope = arr_slope(delayed_prices);
            slope_buffer.push(current_slope);
            if slope_buffer.len() > 10 {
                slope_buffer.remove(0);
            }
            
            let accel = 0;
            if slope_buffer.len() >= 2 {
                accel = current_slope - slope_buffer[slope_buffer.len() - 2];
            }
            
            let is_loss = false;
            if account.stock > 0 {
                let current_value = account.stock * market.price;
                let cost_value = account.stock * account.avg_cost;
                if current_value < cost_value {
                    is_loss = true;
                }
            }
            
            if is_loss {
                current_lot = current_lot * 2;
                if current_lot > 10000 {
                    current_lot = 10000;
                }
            } else {
                current_lot = base_lot;
            }
            
            let pending_count = my_orders.pending_count();
            let i = 0;
            while i < pending_count {
                let oid = my_orders.pending_id(i);
                let placed_tick = my_orders.pending_placed_tick(i);
                if current_tick - placed_tick > 3 {
                    orders.submit_cancel(oid);
                }
                i += 1;
            }
            
            let has_position = account.stock > 0;
            let has_pending = my_orders.pending_count() > 0;
            
            if !has_pending {
                if !has_position && current_slope > 5000 && accel > 1000 {
                    let buy_price = market.ask_price_0 + 1000;
                    orders.submit_limit_buy(buy_price, current_lot);
                } else if has_position && current_slope < -2000 {
                    orders.submit_market_sell(account.stock);
                    last_slope = current_slope;
                }
            }
            
            last_slope = current_slope;
        }
    }
    
    let fill_count = my_orders.fill_count();
    if fill_count > 0 {
        let last_fill = fill_count - 1;
        let fill_side = my_orders.fill_side(last_fill);
        let fill_price = my_orders.fill_price(last_fill);
        
        if fill_side == 1 {
            last_trade_profit = (fill_price - account.avg_cost) * my_orders.fill_amount(last_fill);
        }
    }
}