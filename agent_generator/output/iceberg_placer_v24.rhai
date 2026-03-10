let initialized = false;
let total_sell_target = 0;
let visible_amount = 0;
let remaining_to_sell = 0;
let last_order_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        total_sell_target = account.stock;
        visible_amount = 100;
        remaining_to_sell = total_sell_target;
    }
    
    if !market.trading_enabled { return; }
    
    let fill_count = my_orders.fill_count();
    if fill_count > 0 {
        for i in 0..fill_count {
            if my_orders.fill_side(i) == 1 {
                let filled_qty = my_orders.fill_amount(i);
                remaining_to_sell = remaining_to_sell - filled_qty;
            }
        }
    }
    
    let pending_count = my_orders.pending_count();
    for i in 0..pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
    }
    
    if remaining_to_sell > 0 {
        if market.ask_price_0 > 0 {
            let raw_price = market.ask_price_0;
            let round_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
            last_order_price = round_price;
            
            let order_qty = if visible_amount < remaining_to_sell {
                visible_amount
            } else {
                remaining_to_sell
            };
            
            if order_qty > 0 {
                orders.submit_limit_sell(round_price, order_qty);
            }
        }
    }
}