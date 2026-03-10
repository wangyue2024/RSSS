let initialized = false;
let price_buffer = [];
let risk_averse_threshold = 0;
let base_spread = 0;
let lot_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_averse_threshold = market.price * 50 / 1000;
        base_spread = market.price * 10 / 1000;
        let five_percent_capital = account.total_equity * 5 / 100;
        let max_lot_value = five_percent_capital;
        let max_shares = max_lot_value / market.price;
        if max_shares > 0 {
            lot_size = rng.rand_int(1, max_shares);
        } else {
            lot_size = 1;
        }
    }
    
    if !market.trading_enabled {
        return;
    }
    
    price_buffer.push(market.price);
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
    }
    
    if price_buffer.len() < 5 {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let delayed_price = price_buffer[0];
    
    if market.std_dev > risk_averse_threshold {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let buy_price = delayed_price - base_spread;
    let sell_price = delayed_price + base_spread;
    
    if buy_price > 0 && account.cash >= buy_price * lot_size {
        orders.submit_limit_buy(buy_price, lot_size);
    }
    
    if account.stock >= lot_size {
        orders.submit_limit_sell(sell_price, lot_size);
    }
}