let initialized = false;
let base_lot_size = 100;
let current_lot_size = 100;
let last_trade_was_loss = false;
let fomo_price_history = [];
let fomo_window = 5;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(50, 200);
        current_lot_size = base_lot_size;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    fomo_price_history.push(market.price);
    if fomo_price_history.len() > fomo_window {
        fomo_price_history.remove(0);
    }
    
    let fomo_triggered = false;
    if fomo_price_history.len() == fomo_window {
        let oldest_price = fomo_price_history[0];
        if oldest_price > 0 {
            let price_change_pct = (market.price - oldest_price) * 10000 / oldest_price;
            if price_change_pct > 200 {
                fomo_triggered = true;
                let buy_amount = current_lot_size;
                if account.cash < market.price * buy_amount {
                    buy_amount = account.cash / market.price;
                }
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount);
                    return;
                }
            }
        }
    }
    
    if fomo_triggered { return; }
    
    if account.stock > 0 {
        let current_price = market.price;
        let cost_basis = account.avg_cost;
        if cost_basis > 0 {
            let profit_pct = (current_price - cost_basis) * 10000 / cost_basis;
            if profit_pct >= 0 {
                let exit_condition = current_price >= market.ma_20;
                if exit_condition {
                    orders.submit_market_sell(account.stock);
                    last_trade_was_loss = false;
                    current_lot_size = base_lot_size;
                }
            } else {
                let stop_condition = current_price <= cost_basis * 9800 / 10000;
                if stop_condition {
                    orders.submit_market_sell(account.stock);
                    last_trade_was_loss = true;
                    current_lot_size = current_lot_size * 2;
                }
            }
        }
    } else {
        if last_trade_was_loss {
            current_lot_size = current_lot_size * 2;
            if current_lot_size > 1000 { current_lot_size = 1000; }
        }
        
        let atr = market.atr_14;
        let ma = market.ma_20;
        let price = market.price;
        
        if atr > 0 && ma > 0 {
            let deviation = abs_val(price - ma);
            let threshold = (atr * 3) / 2;
            
            if deviation > threshold {
                if price < ma {
                    let buy_amount = current_lot_size;
                    if account.cash < market.price * buy_amount {
                        buy_amount = account.cash / market.price;
                    }
                    if buy_amount > 0 {
                        orders.submit_market_buy(buy_amount);
                    }
                }
            }
        }
    }
}