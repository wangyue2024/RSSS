let initialized = false;
let remaining_to_sell = 0;
let iceberg_size = 0;
let price_history = [];
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        remaining_to_sell = 50000;
        iceberg_size = 100;
        price_history = [];
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    price_history.push(current_price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if price_history.len() == 5 {
        let old_price = price_history[0];
        if old_price > 0 {
            let price_jump_pct = (current_price - old_price) * 10000 / old_price;
            if price_jump_pct > 200 {
                fomo_triggered = true;
            }
        }
    }
    
    if fomo_triggered {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        orders.submit_market_buy(1000);
        return;
    }
    
    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        let fill_side = my_orders.fill_side(i);
        if fill_side == 1 {
            let fill_amount = my_orders.fill_amount(i);
            remaining_to_sell = remaining_to_sell - fill_amount;
        }
        i += 1;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if remaining_to_sell > 0 && current_price > account.avg_cost && market.ask_price_0 > 0 {
        let order_amount = iceberg_size;
        if order_amount > remaining_to_sell {
            order_amount = remaining_to_sell;
        }
        orders.submit_limit_sell(market.ask_price_0, order_amount);
    }
}