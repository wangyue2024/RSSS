let initialized = false;
let buy_order_id = 0;
let buy_placed_tick = 0;
let sell_order_id = 0;
let sell_placed_tick = 0;
const ORDER_AMOUNT = 10000;

fn is_order_pending(id) {
    let cnt = my_orders.pending_count();
    let i = 0;
    while i < cnt {
        if my_orders.pending_id(i) == id {
            return true;
        }
        i += 1;
    }
    return false;
}

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let buy_condition = market.buy_volume > 3 * market.sell_volume;
    let sell_condition = market.sell_volume > 3 * market.buy_volume;
    
    if buy_order_id != 0 && !is_order_pending(buy_order_id) {
        buy_order_id = 0;
    }
    if sell_order_id != 0 && !is_order_pending(sell_order_id) {
        sell_order_id = 0;
    }
    
    if buy_order_id != 0 {
        if current_tick - buy_placed_tick >= 3 {
            orders.submit_cancel(buy_order_id);
            buy_order_id = 0;
        }
    }
    
    if sell_order_id != 0 {
        if current_tick - sell_placed_tick >= 3 {
            orders.submit_cancel(sell_order_id);
            sell_order_id = 0;
        }
    }
    
    if buy_condition && buy_order_id == 0 {
        if market.ask_price_0 > 0 {
            buy_order_id = orders.submit_limit_buy(market.ask_price_0, ORDER_AMOUNT);
            buy_placed_tick = current_tick;
        }
    }
    
    if sell_condition && sell_order_id == 0 {
        if market.bid_price_0 > 0 {
            sell_order_id = orders.submit_limit_sell(market.bid_price_0, ORDER_AMOUNT);
            sell_placed_tick = current_tick;
        }
    }
}