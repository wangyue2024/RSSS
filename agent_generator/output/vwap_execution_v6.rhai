let price_buffer = [];
let volume_buffer = [];
let delayed_ready = false;
let target_position = 10000;
let current_lot = 100;
let base_lot = 100;
let last_trade_profit = true;
let last_avg_cost = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    price_buffer.push(market.price);
    volume_buffer.push(market.volume);
    
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
        volume_buffer.remove(0);
        delayed_ready = true;
    }
    
    if !delayed_ready { return; }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let delayed_price = price_buffer[0];
    let delayed_volume = volume_buffer[0];
    
    let volume_factor = if delayed_volume > 5000 { 2 } else { 1 };
    let current_size = current_lot * volume_factor;
    
    if account.stock >= target_position { return; }
    
    if account.stock > 0 {
        let cost_basis = account.avg_cost;
        let unrealized_gain = (delayed_price - cost_basis) * account.stock;
        last_trade_profit = unrealized_gain > 0;
        last_avg_cost = cost_basis;
    }
    
    if !last_trade_profit && account.stock > 0 {
        current_lot = base_lot * 2;
    } else {
        current_lot = base_lot;
    }
    
    let rounded_price = (delayed_price + 500_000) / 1_000_000 * 1_000_000;
    let amount_to_buy = if current_size > target_position - account.stock {
        target_position - account.stock
    } else {
        current_size
    };
    
    if amount_to_buy > 0 {
        orders.submit_limit_buy(rounded_price, amount_to_buy);
    }
}