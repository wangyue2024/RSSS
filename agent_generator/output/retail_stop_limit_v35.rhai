let initialized = false;
let panic_threshold = 0;
let price_history = [];
let entered = false;
let entry_price = 0;
let tp_order_id = 0;
let sl_order_id = 0;
let delayed_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(10_000, 50_000);
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if price_history.len() == 5 {
        delayed_price = price_history[0];
    } else {
        delayed_price = market.price;
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if !entered && account.stock == 0 {
        if rng.rand_bool(1) {
            let buy_amount = account.cash / delayed_price;
            if buy_amount > 0 {
                orders.submit_limit_buy(delayed_price, buy_amount);
                entered = true;
                entry_price = delayed_price;
            }
        }
    }
    
    if entered && account.stock > 0 {
        let tp_price = entry_price * 105 / 100;
        let sl_price = entry_price * 98 / 100;
        
        if account.unrealized_pnl < panic_threshold {
            orders.submit_market_sell(account.stock);
            entered = false;
        } else if delayed_price <= sl_price {
            orders.submit_market_sell(account.stock);
            entered = false;
        } else {
            orders.submit_limit_sell(tp_price, account.stock);
        }
    }
}