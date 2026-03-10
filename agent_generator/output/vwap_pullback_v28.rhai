let initialized = false;
let base_lot = 1000;
let current_lot = base_lot;
let threshold = 5000;
let morning_ticks = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        morning_ticks = market.total_ticks / 5;
    }
    
    if !market.trading_enabled { return; }
    if market.tick >= morning_ticks { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let vwap = market.vwap;
    let price = market.price;
    let stock = account.stock;
    let avg_cost = account.avg_cost;
    
    if stock == 0 {
        if price < vwap - threshold {
            orders.submit_limit_buy(price, current_lot);
        }
    } else {
        if price > avg_cost && price >= vwap {
            orders.submit_limit_sell(price, stock);
            current_lot = base_lot;
        } else if price < avg_cost {
            current_lot = base_lot * 2;
        }
    }
}