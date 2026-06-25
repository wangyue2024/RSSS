let initialized = false;
let fair_value = 0;
let base_lot = 100;
let current_lot = 100;
let last_trade_loss = false;
let last_order_id = 0;

fn on_tick() {
    if !initialized {
        fair_value = 100_000_000 + rng.rand_int(-500_000, 500_000);
        current_lot = base_lot;
        last_trade_loss = false;
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let latest_fill = my_orders.fill_id(0);
        if latest_fill != last_order_id {
            last_order_id = latest_fill;
            let filled_price = my_orders.fill_price(0);
            let filled_side = my_orders.fill_side(0);
            if filled_side == 1 {
                let trade_pnl = (filled_price - account.avg_cost) * my_orders.fill_amount(0);
                last_trade_loss = trade_pnl < 0;
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
    
    let price = market.price;
    let threshold1 = fair_value * 105 / 100;
    let threshold2 = fair_value * 110 / 100;
    let to_sell = 0;
    
    if price > threshold2 && account.stock > 0 {
        to_sell = current_lot * 3;
        if to_sell > account.stock {
            to_sell = account.stock;
        }
    } else if price > threshold1 && account.stock > 0 {
        to_sell = current_lot;
        if to_sell > account.stock {
            to_sell = account.stock;
        }
    }
    
    if to_sell > 0 {
        orders.submit_limit_sell(price, to_sell);
    }
}