let initialized = false;
let vwap_threshold_percent = 0;
let buy_amount = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        vwap_threshold_percent = rng.rand_int(80, 150);
        buy_amount = rng.rand_int(50, 200);
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let vwap = market.vwap;
    let price = market.price;
    
    if account.stock == 0 {
        let threshold = vwap - (vwap * vwap_threshold_percent / 10000);
        
        if price < threshold {
            let raw_price = price;
            let rounded_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
            
            if rounded_price > 0 {
                orders.submit_limit_buy(rounded_price, buy_amount);
            }
        }
    } else {
        if price > account.avg_cost {
            let raw_price = price;
            let rounded_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
            
            if rounded_price > 0 && rounded_price > account.avg_cost {
                orders.submit_limit_sell(rounded_price, account.stock);
            }
        }
    }
}