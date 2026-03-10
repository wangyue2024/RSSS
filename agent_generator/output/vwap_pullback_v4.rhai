let initialized = false;
let threshold_percent = 0;
let trade_amount = 0;
let buy_threshold_micros = 0;
let last_vwap = 0;

fn on_tick() {
    if !initialized {
        threshold_percent = rng.rand_int(50, 200);
        trade_amount = rng.rand_int(5, 20);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    let vwap = market.vwap;
    last_vwap = vwap;
    
    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.stock == 0 && vwap > 0 {
        buy_threshold_micros = vwap * (10000 - threshold_percent) / 10000;
        
        if current_price < buy_threshold_micros {
            let bid_price = buy_threshold_micros + 1;
            let max_affordable = account.cash / bid_price;
            let amount_to_buy = max_affordable.min(trade_amount);
            
            if amount_to_buy > 0 {
                orders.submit_limit_buy(bid_price, amount_to_buy);
            }
        }
    }
    
    if account.stock > 0 && current_price >= vwap && vwap > 0 {
        let amount_to_sell = account.stock.min(trade_amount);
        orders.submit_limit_sell(vwap, amount_to_sell);
    }
}