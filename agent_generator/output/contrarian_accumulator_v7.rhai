let initialized = false;
let oversold_threshold = 3000;
let overbought_threshold = 7000;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let rsi = market.rsi_14;
    if rsi == 0 { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if rsi < oversold_threshold {
        let base_price = if market.bid_price_0 != 0 { market.bid_price_0 } else { market.price };
        let buy_price = base_price - 5000 + 1;
        let amount = rng.rand_int(20, 100);
        
        if amount > 0 && buy_price > 0 {
            orders.submit_limit_buy(buy_price, amount);
        }
    } else if rsi > overbought_threshold {
        let base_price = if market.ask_price_0 != 0 { market.ask_price_0 } else { market.price };
        let sell_price = base_price + 5000;
        let amount = rng.rand_int(20, 100);
        
        if amount > 0 && account.stock >= amount {
            orders.submit_limit_sell(sell_price, amount);
        }
    }
}