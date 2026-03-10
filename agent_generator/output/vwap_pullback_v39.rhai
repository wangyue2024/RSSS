let price_history = [];
let threshold_percent = 0;
let initialized = false;
let in_position = false;
let position_entry_price = 0;
let lot_size_factor = 0;

fn on_tick() {
    if !initialized {
        threshold_percent = rng.rand_int(500, 1500);
        lot_size_factor = rng.rand_int(40, 50);
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
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if price_history.len() < 5 { return; }
    
    let delayed_price = price_history[0];
    let vwap = market.vwap;
    
    let threshold_micros = vwap * threshold_percent / 100000;
    
    if !in_position {
        if delayed_price < vwap - threshold_micros {
            let cash_to_use = account.cash * lot_size_factor / 100;
            let buy_shares = cash_to_use / delayed_price;
            if buy_shares > 0 {
                orders.submit_market_buy(buy_shares);
                in_position = true;
                position_entry_price = delayed_price;
            }
        }
    } else {
        if delayed_price >= vwap {
            orders.submit_market_sell(account.stock);
            in_position = false;
            position_entry_price = 0;
        }
    }
}