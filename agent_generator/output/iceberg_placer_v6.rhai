let total_to_sell = 100000;
let order_size = 100;
let remaining_to_sell = 0;
let last_evaluation_tick = -50;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if market.tick - last_evaluation_tick < 50 { return; }
    last_evaluation_tick = market.tick;
    
    let fill_count = my_orders.fill_count();
    if fill_count > 0 {
        for i in 0..fill_count {
            if my_orders.fill_side(i) == 1 {
                let fill_amount = my_orders.fill_amount(i);
                if remaining_to_sell >= fill_amount {
                    remaining_to_sell -= fill_amount;
                } else {
                    remaining_to_sell = 0;
                }
            }
        }
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if remaining_to_sell <= 0 {
        remaining_to_sell = total_to_sell;
    }
    
    if remaining_to_sell > 0 {
        let ask_price = market.ask_price_0;
        if ask_price > 0 && account.stock >= order_size {
            let size_to_place = if order_size <= remaining_to_sell { order_size } else { remaining_to_sell };
            orders.submit_limit_sell(ask_price, size_to_place);
        }
    }
}