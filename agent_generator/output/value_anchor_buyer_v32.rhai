let initialized = false;
let fair_value = 0;
let base_lot_size = 1000;
let current_lot_size = 1000;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let in_loss = (account.stock > 0) && (market.price < account.avg_cost);
    if in_loss {
        current_lot_size = base_lot_size * 2;
    } else {
        current_lot_size = base_lot_size;
    }
    
    let buy_threshold_95 = fair_value * 95 / 100;
    let buy_threshold_90 = fair_value * 90 / 100;
    
    if market.price < buy_threshold_95 {
        let lot = 0;
        if market.price < buy_threshold_90 {
            lot = current_lot_size * 2;
        } else {
            lot = current_lot_size;
        }
        
        let raw_price = market.price;
        let rounded = (raw_price + 500_000) / 1_000_000 * 1_000_000;
        let bid_price = rounded + 1;
        
        if lot > 0 && account.cash > bid_price * lot {
            orders.submit_limit_buy(bid_price, lot);
        }
    }
}