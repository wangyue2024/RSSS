let initialized = false;
let iceberg_total = 0;
let remaining_to_sell = 0;
let lot_size = 0;
let pending_sell_id = -1;
let placed_tick = 0;
let last_fill_tick = 0;
let last_was_loss = false;
let base_lot = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        iceberg_total = 10000;
        remaining_to_sell = iceberg_total;
        base_lot = 100;
        lot_size = base_lot;
        last_fill_tick = market.tick;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        for i in 0..fill_cnt {
            let fill_side = my_orders.fill_side(i);
            let fill_amount = my_orders.fill_amount(i);
            let fill_price = my_orders.fill_price(i);
            
            if fill_side == 1 {
                remaining_to_sell -= fill_amount;
                last_fill_tick = current_tick;
                
                let was_loss = fill_price < account.avg_cost;
                if was_loss {
                    last_was_loss = true;
                    lot_size = lot_size * 2;
                } else {
                    last_was_loss = false;
                    lot_size = base_lot;
                }
                
                break;
            }
        }
    }
    
    if pending_sell_id != -1 {
        let found = false;
        let pending_cnt = my_orders.pending_count();
        for i in 0..pending_cnt {
            if my_orders.pending_id(i) == pending_sell_id {
                found = true;
                if current_tick - placed_tick > 3 {
                    orders.submit_cancel(pending_sell_id);
                    pending_sell_id = -1;
                }
                break;
            }
        }
        if !found {
            pending_sell_id = -1;
        }
    }
    
    if pending_sell_id == -1 && remaining_to_sell > 0 && market.ask_price_0 > 0 {
        let sell_amount = lot_size;
        if sell_amount > remaining_to_sell {
            sell_amount = remaining_to_sell;
        }
        orders.submit_limit_sell(market.ask_price_0, sell_amount);
        
        let pending_cnt = my_orders.pending_count();
        if pending_cnt > 0 {
            for i in 0..pending_cnt {
                if my_orders.pending_side(i) == 1 && my_orders.pending_price(i) == market.ask_price_0 {
                    pending_sell_id = my_orders.pending_id(i);
                    placed_tick = current_tick;
                    break;
                }
            }
        }
    }
}