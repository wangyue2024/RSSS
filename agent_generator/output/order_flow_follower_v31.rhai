let initialized = false;
let order_amount = 100;
let patience_ticks = 3;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel orders that have been pending for more than patience_ticks
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick > patience_ticks {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Check order flow condition
    let buy_vol = market.buy_volume;
    let sell_vol = market.sell_volume;
    
    // 3x condition using integer math
    if buy_vol > 3 * sell_vol && sell_vol > 0 {
        // Join the buy crowd - use market price for limit order
        let target_price = market.price;
        if account.cash >= target_price * order_amount {
            orders.submit_limit_buy(target_price, order_amount);
        }
    } else if sell_vol > 3 * buy_vol && buy_vol > 0 {
        // Join the sell crowd - use market price for limit order
        let target_price = market.price;
        if account.stock >= order_amount {
            orders.submit_limit_sell(target_price, order_amount);
        }
    }
}