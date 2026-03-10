let initialized = false;
let panic_threshold = 0;
let price_history = [];
let volume_history = [];
let ma_60_history = [];
let high_20_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = rng.rand_int(-500000, -100000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    price_history.push(market.price);
    volume_history.push(market.volume);
    ma_60_history.push(market.ma_60);
    high_20_history.push(market.high_20);
    
    if price_history.len() > 5 {
        price_history.remove(0);
        volume_history.remove(0);
        ma_60_history.remove(0);
        high_20_history.remove(0);
    }
    
    if price_history.len() == 5 {
        let old_price = price_history[0];
        let old_volume = volume_history[0];
        let old_ma_60 = ma_60_history[0];
        let old_high_20 = high_20_history[0];
        
        if price_history[2] > 0 && (price_history[2] - old_price) * 10000 / old_price > 200 {
            let buy_amount = (account.cash * 10 / 100) / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        } else {
            if old_high_20 > old_ma_60 && old_volume < 1000 {
                let sell_amount = 100;
                if account.stock >= sell_amount {
                    orders.submit_market_sell(sell_amount);
                }
            }
        }
    }
}