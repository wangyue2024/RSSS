let initialized = false;
let lot_size = 0;
let total_sell_amount = 0;
let remaining_to_sell = 0;
let delayed_price = 0;
let price_buffer = [];

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        let equity = account.total_equity;
        let five_percent_cap = equity * 5 / 100;
        
        let max_lot_value = five_percent_cap;
        if max_lot_value <= 0 { return; }
        
        let price = market.price;
        if price == 0 { return; }
        
        lot_size = max_lot_value / price;
        if lot_size <= 0 { lot_size = 1; }
        
        total_sell_amount = account.stock * 80 / 100;
        if total_sell_amount <= 0 { total_sell_amount = lot_size * 10; }
        
        remaining_to_sell = total_sell_amount;
        initialized = true;
        
        while price_buffer.len() < 5 {
            price_buffer.push(price);
        }
    }
    
    price_buffer.push(market.price);
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
    }
    
    if price_buffer.len() < 5 { return; }
    
    delayed_price = price_buffer[0];
    
    let std_dev_threshold = market.price * 15 / 100;
    if market.std_dev > std_dev_threshold {
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let fill_count = my_orders.fill_count();
    let had_sell_fill = false;
    let j = 0;
    while j < fill_count {
        if my_orders.fill_side(j) == 1 {
            had_sell_fill = true;
            remaining_to_sell = remaining_to_sell - my_orders.fill_amount(j);
            if remaining_to_sell < 0 { remaining_to_sell = 0; }
        }
        j += 1;
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if remaining_to_sell <= 0 { return; }
    
    if had_sell_fill || pending_count == 0 {
        let order_amount = lot_size;
        if order_amount > remaining_to_sell {
            order_amount = remaining_to_sell;
        }
        
        if order_amount > 0 && delayed_price > 0 {
            orders.submit_limit_sell(delayed_price, order_amount);
        }
    }
}