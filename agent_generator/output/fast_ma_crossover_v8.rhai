let initialized = false;
let prev_ma5 = 0;
let prev_ma20 = 0;
let active_order_id = -1;
let order_placed_tick = 0;

fn round_to_dollar(price) {
    let remainder = price % 1_000_000;
    if remainder >= 500_000 {
        price - remainder + 1_000_000
    } else {
        price - remainder
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
        prev_ma5 = market.ma_5;
        prev_ma20 = market.ma_20;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    let ma5 = market.ma_5;
    let ma20 = market.ma_20;
    
    let cancel_old = false;
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        if oid == active_order_id && current_tick - order_placed_tick >= 3 {
            orders.submit_cancel(oid);
            active_order_id = -1;
        }
        i += 1;
    }
    
    let golden_cross = ma5 > ma20 && prev_ma5 <= prev_ma20;
    let death_cross = ma5 < ma20 && prev_ma5 >= prev_ma20;
    
    if golden_cross && account.stock == 0 {
        let rounded_price = round_to_dollar(market.price);
        let buy_amount = account.cash / rounded_price;
        if buy_amount > 0 {
            let oid = orders.submit_limit_buy(rounded_price, buy_amount);
            active_order_id = oid;
            order_placed_tick = current_tick;
        }
    }
    
    if death_cross && account.stock > 0 && market.price > account.avg_cost {
        let rounded_price = round_to_dollar(market.price);
        if rounded_price > account.avg_cost {
            let oid = orders.submit_limit_sell(rounded_price, account.stock);
            active_order_id = oid;
            order_placed_tick = current_tick;
        }
    }
    
    prev_ma5 = ma5;
    prev_ma20 = ma20;
}