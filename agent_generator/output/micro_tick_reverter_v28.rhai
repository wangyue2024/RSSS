let initialized = false;
let base_lot = 100;
let current_lot = base_lot;
let last_trade_loss = false;
let last_decision_price = 0;
let has_last_price = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        base_lot = 100;
        current_lot = base_lot;
        last_trade_loss = false;
    }
    
    let total_ticks = market.total_ticks;
    let current_tick = market.tick;
    
    if current_tick >= total_ticks / 5 { return; }
    if current_tick % 50 != 0 { return; }
    
    let cancel_count = my_orders.pending_count();
    let c = 0;
    while c < cancel_count {
        let oid = my_orders.pending_id(c);
        orders.submit_cancel(oid);
        c += 1;
    }
    
    let position = account.stock;
    if position > 0 {
        orders.submit_market_sell(position);
    } else if position < 0 {
        orders.submit_market_buy(-position);
    }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let last_fill_side = my_orders.fill_side(0);
        let last_fill_price = my_orders.fill_price(0);
        let avg_cost = account.avg_cost;
        
        if position != 0 {
            if last_fill_side == 0 {
                last_trade_loss = last_fill_price < avg_cost;
            } else {
                last_trade_loss = last_fill_price > avg_cost;
            }
        }
    }
    
    if last_trade_loss {
        current_lot = current_lot * 2;
        if current_lot > 10000 {
            current_lot = 10000;
        }
    } else {
        current_lot = base_lot;
    }
    
    let current_price = market.price;
    
    if has_last_price {
        let price_diff = current_price - last_decision_price;
        if price_diff < 0 {
            let buy_price = current_price - micros(0, 100);
            if buy_price > 0 {
                orders.submit_limit_buy(buy_price, current_lot);
            }
        } else if price_diff > 0 {
            let sell_price = current_price + micros(0, 100);
            orders.submit_limit_sell(sell_price, current_lot);
        }
    }
    
    last_decision_price = current_price;
    has_last_price = true;
}