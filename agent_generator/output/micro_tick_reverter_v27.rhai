let initialized = false;
let prev_price = 0;
let stop_loss_threshold = 0;
let order_offset = 10;
let order_amount = 10;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = rng.rand_int(50_000, 500_000);
        order_offset = rng.rand_int(1, 50);
        order_amount = rng.rand_int(1, 100);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < -stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    let current_price = market.price;
    
    if prev_price != 0 && prev_price != current_price {
        if current_price < prev_price {
            let buy_price = current_price - order_offset;
            if buy_price > 0 {
                orders.submit_limit_buy(buy_price, order_amount);
            }
        } else {
            let sell_price = current_price + order_offset;
            orders.submit_limit_sell(sell_price, order_amount);
        }
    }
    
    prev_price = current_price;
}