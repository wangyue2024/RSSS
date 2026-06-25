let initialized = false;
let stop_loss_offset = 300000;
let position_size = 100;
let in_position = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.stock > 0 {
        in_position = true;
        
        if market.price > account.avg_cost {
            let stop_price = account.avg_cost - stop_loss_offset;
            if market.price <= stop_price {
                orders.submit_market_sell(account.stock);
                in_position = false;
            } else {
                let target_price = account.avg_cost + stop_loss_offset * 3;
                if market.price >= target_price {
                    orders.submit_market_sell(account.stock);
                    in_position = false;
                }
            }
        }
    } else {
        in_position = false;
        
        if market.price > market.high_20 {
            let max_affordable = account.cash / market.price;
            let buy_qty = if position_size < max_affordable { position_size } else { max_affordable };
            if buy_qty > 0 {
                orders.submit_market_buy(buy_qty);
            }
        }
    }
}