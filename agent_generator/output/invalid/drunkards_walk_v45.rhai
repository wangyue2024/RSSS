let initialized = false;
let personality = 0;
let lot_size = 0;
let price_offset_range = 0;
let std_dev_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        
        personality = rng.rand_int(0, 1);
        
        if personality == 0 {
            let max_trade_value = account.total_equity * 5 / 100;
            let price = market.price;
            if price > 0 {
                lot_size = max_trade_value / price;
                if lot_size < 1 { lot_size = 1; }
            } else {
                lot_size = 100;
            }
            price_offset_range = 50;
            std_dev_threshold = market.price * 50 / 10000;
        } else {
            let max_trade_value = account.cash * 50 / 100;
            let price = market.price;
            if price > 0 {
                lot_size = max_trade_value / price;
                if lot_size < 100 { lot_size = 100; }
            } else {
                lot_size = 10000;
            }
            price_offset_range = 500;
            std_dev_threshold = 0;
        }
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if personality == 0 && market.std_dev > std_dev_threshold {
        return;
    }
    
    let random_val = rng.rand_int(0, 99);
    
    if random_val < 5 {
        let offset = rng.rand_int(0, price_offset_range);
        let price = market.price - offset * market.price / 10000;
        if price < 1 { price = 1; }
        
        let qty = rng.rand_int(1, lot_size);
        if qty > 0 {
            orders.submit_limit_buy(price, qty);
        }
    } else if random_val > 95 {
        let offset = rng.rand_int(0, price_offset_range);
        let price = market.price + offset * market.price / 10000;
        
        let max_qty = account.stock;
        if max_qty > 0 {
            let qty = rng.rand_int(1, lot_size);
            if qty > max_qty { qty = max_qty; }
            if qty > 0 {
                orders.submit_limit_sell(price, qty);
            }
        }
    }
}