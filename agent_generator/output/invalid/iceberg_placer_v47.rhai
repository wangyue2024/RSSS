let initialized = false;
let target_sell_amount = 10000;
let iceberg_lot_size = 100;
let sold_amount = 0;
let current_order_id = -1;
let last_trade_loss = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        iceberg_lot_size = rng.rand_int(80, 120);
    }
    
    if !market.trading_enabled { return; }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        for i in 0..fill_cnt {
            let fill_side = my_orders.fill_side(i);
            if fill_side == 1 {
                sold_amount += my_orders.fill_amount(i);
                
                let fill_price = my_orders.fill_price(i);
                if fill_price < account.avg_cost {
                    last_trade_loss = true;
                } else {
                    last_trade_loss = false;
                }
            }
        }
    }
    
    let pending_cnt = my_orders.pending_count();
    let found_current = false;
    for i in 0..pending_cnt {
        let oid = my_orders.pending_id(i);
        if oid == current_order_id {
            found_current = true;
            break;
        }
    }
    
    if !found_current && sold_amount < target_sell_amount {
        if last_trade_loss {
            iceberg_lot_size = iceberg_lot_size * 2;
        }
        
        let remaining = target_sell_amount - sold_amount;
        let order_amount = iceberg_lot_size;
        if order_amount > remaining {
            order_amount = remaining;
        }
        
        if order_amount > 0 && market.ask_price_0 > 0 {
            current_order_id = orders.submit_limit_sell(market.ask_price_0, order_amount);
        }
    }
}