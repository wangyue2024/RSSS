let initialized = false;
let buy_threshold_percent = 200;
let position_size = 100;
let pending_buy_id = -1;

fn on_tick() {
    if !initialized {
        initialized = true;
        buy_threshold_percent = rng.rand_int(150, 300);
        position_size = rng.rand_int(80, 120);
    }
    
    if !market.trading_enabled { return; }
    
    let vwap = market.vwap;
    let price = market.price;
    let stock = account.stock;
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    pending_buy_id = -1;
    
    if stock == 0 {
        let threshold_price = vwap * (10000 - buy_threshold_percent) / 10000;
        
        if price <= threshold_price {
            let raw_price = threshold_price;
            let rounded_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
            let buy_price = rounded_price;
            
            if account.cash >= buy_price * position_size {
                pending_buy_id = orders.submit_limit_buy(buy_price, position_size);
            }
        }
    } else {
        let raw_sell_price = vwap;
        let rounded_sell_price = ((raw_sell_price + 500_000) / 1_000_000) * 1_000_000;
        let sell_price = rounded_sell_price;
        
        if sell_price * stock <= account.cash + sell_price * stock {
            orders.submit_limit_sell(sell_price, stock);
        }
    }
}