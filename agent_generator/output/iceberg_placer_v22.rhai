let initialized = false;
let lot_size = 0;
let remaining_to_sell = 0;
let max_orders = 0;
let std_dev_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        
        let total_capital = account.total_equity;
        let max_lot_value = total_capital * 5 / 100;
        lot_size = max_lot_value / market.price;
        if lot_size < 1 { lot_size = 1; }
        
        let rnd_factor = rng.rand_int(1, 10);
        lot_size = lot_size * rnd_factor / 10;
        if lot_size < 1 { lot_size = 1; }
        
        remaining_to_sell = account.stock * 8 / 10;
        max_orders = 1;
        std_dev_threshold = market.price * 3 / 100;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.std_dev > std_dev_threshold { return; }
    
    let fills = my_orders.fill_count();
    let j = 0;
    while j < fills {
        let fill_side = my_orders.fill_side(j);
        if fill_side == 1 {
            let fill_amount = my_orders.fill_amount(j);
            if remaining_to_sell > fill_amount {
                remaining_to_sell -= fill_amount;
            } else {
                remaining_to_sell = 0;
            }
        }
        j += 1;
    }
    
    if remaining_to_sell <= 0 { return; }
    
    if market.ask_price_0 > 0 {
        let current_lot = lot_size;
        if current_lot > remaining_to_sell {
            current_lot = remaining_to_sell;
        }
        
        if current_lot > 0 && account.stock >= current_lot {
            orders.submit_limit_sell(market.ask_price_0, current_lot);
        }
    }
}