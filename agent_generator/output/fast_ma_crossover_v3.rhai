let initialized = false;
let last_ma_5 = 0;
let last_ma_20 = 0;
let signal_state = 0; // 0=no signal, 1=buy signal active, 2=sell signal active

fn round_to_dollar(price_micros) {
    let dollar = 1_000_000;
    ((price_micros + dollar / 2) / dollar) * dollar
}

fn on_tick() {
    if !initialized {
        initialized = true;
        last_ma_5 = market.ma_5;
        last_ma_20 = market.ma_20;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let ma_5_up = market.ma_5 > market.ma_20 && last_ma_5 <= last_ma_20;
    let ma_5_down = market.ma_5 < market.ma_20 && last_ma_5 >= last_ma_20;
    
    last_ma_5 = market.ma_5;
    last_ma_20 = market.ma_20;
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if ma_5_up {
        signal_state = 1;
    } else if ma_5_down {
        signal_state = 2;
    }
    
    if signal_state == 1 && my_orders.pending_count() == 0 {
        let buy_price = round_to_dollar(market.price);
        let max_shares = account.cash / buy_price;
        if max_shares > 0 {
            orders.submit_limit_buy(buy_price, max_shares);
        }
    } else if signal_state == 2 && my_orders.pending_count() == 0 {
        if account.stock > 0 {
            let sell_price = round_to_dollar(market.price);
            orders.submit_limit_sell(sell_price, account.stock);
        }
    }
}