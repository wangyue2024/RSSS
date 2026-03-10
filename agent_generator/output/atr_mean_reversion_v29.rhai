let initialized = false;
let lot_size = 0;
let price_history = [];
let ma_history = [];
let atr_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        let r = rng.rand_int(30, 50);
        lot_size = r * 10000;
    }
    
    if !market.trading_enabled {
        return;
    }
    
    price_history.push(market.price);
    ma_history.push(market.ma_20);
    atr_history.push(market.atr_14);
    
    if price_history.len() > 6 {
        price_history.remove(0);
        ma_history.remove(0);
        atr_history.remove(0);
    }
    
    if market.tick % 50 != 0 {
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if price_history.len() < 6 {
        return;
    }
    
    let old_price = price_history[0];
    let old_ma = ma_history[0];
    let old_atr = atr_history[0];
    
    if old_atr == 0 {
        return;
    }
    
    let deviation = abs_val(old_price - old_ma);
    let threshold = old_atr * 15 / 10;
    
    if deviation > threshold {
        let trade_amount = lot_size;
        if old_price > old_ma {
            let max_sell = account.stock * 50 / 100;
            let sell_qty = trade_amount;
            if sell_qty > max_sell {
                sell_qty = max_sell;
            }
            if sell_qty > 0 {
                orders.submit_limit_sell(old_price, sell_qty);
            }
        } else {
            let max_buy_cash = account.cash * 50 / 100;
            let max_buy_qty = max_buy_cash / old_price;
            let buy_qty = trade_amount;
            if buy_qty > max_buy_qty {
                buy_qty = max_buy_qty;
            }
            if buy_qty > 0 {
                orders.submit_limit_buy(old_price, buy_qty);
            }
        }
    }
}