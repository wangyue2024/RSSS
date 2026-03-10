let initialized = false;
let target_position = 50_000;
let base_lot_size = 500;
let current_lot_size = 500;
let last_trade_loss = false;
let last_action_tick = -50;

fn on_tick() {
    if !market.trading_enabled {
        return;
    }
    
    if !initialized {
        initialized = true;
    }
    
    let current_tick = market.tick;
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        if market.price < account.avg_cost {
            last_trade_loss = true;
        } else {
            last_trade_loss = false;
        }
    }
    
    if last_trade_loss {
        current_lot_size = base_lot_size * 2;
    } else {
        current_lot_size = base_lot_size;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if current_tick - last_action_tick >= 50 {
        last_action_tick = current_tick;
        
        if account.stock < target_position && my_orders.pending_count() == 0 {
            let remaining = target_position - account.stock;
            let amount = remaining;
            if remaining > current_lot_size {
                amount = current_lot_size;
            }
            
            if amount > 0 {
                orders.submit_market_buy(amount);
            }
        }
    }
}