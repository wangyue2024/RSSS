let ma5_history = [];
let ma20_history = [];
let last_ma5 = 0;
let last_ma20 = 0;
let current_ma5 = 0;
let current_ma20 = 0;
let delayed_ma5 = 0;
let delayed_ma20 = 0;
let last_signal = 0;
let initialized = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        ma5_history.clear();
        ma20_history.clear();
        last_signal = 0;
    }
    
    current_ma5 = market.ma_5;
    current_ma20 = market.ma_20;
    
    ma5_history.push(current_ma5);
    ma20_history.push(current_ma20);
    
    if ma5_history.len() > 5 {
        ma5_history.remove(0);
        ma20_history.remove(0);
    }
    
    if ma5_history.len() == 5 {
        delayed_ma5 = ma5_history[0];
        delayed_ma20 = ma20_history[0];
        
        let new_signal = 0;
        if delayed_ma5 > delayed_ma20 {
            new_signal = 1;
        } else {
            new_signal = -1;
        }
        
        if new_signal == 1 && last_signal != 1 {
            let count = my_orders.pending_count();
            let i = 0;
            while i < count {
                let oid = my_orders.pending_id(i);
                orders.submit_cancel(oid);
                i += 1;
            }
            
            if account.stock == 0 {
                let available_cash = account.cash;
                let price_estimate = market.ask_price_0;
                if price_estimate > 0 {
                    let max_shares = available_cash / price_estimate;
                    if max_shares > 0 {
                        orders.submit_market_buy(max_shares);
                    }
                }
            }
        } else if new_signal == -1 && last_signal != -1 {
            let count = my_orders.pending_count();
            let i = 0;
            while i < count {
                let oid = my_orders.pending_id(i);
                orders.submit_cancel(oid);
                i += 1;
            }
            
            if account.stock > 0 {
                orders.submit_market_sell(account.stock);
            }
        }
        
        last_signal = new_signal;
    }
}