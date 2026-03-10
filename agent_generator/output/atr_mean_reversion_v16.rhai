let initialized = false;
let martingale_multiplier = 1;
let last_trade_profit = true;
let base_lot_size = 0;
let position_direction = 0;
let entry_avg_cost = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(20000, 50000);
        position_direction = 0;
        entry_avg_cost = 0;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let atr = market.atr_14;
    let ma20 = market.ma_20;
    let current_price = market.price;
    let deviation = abs_val(current_price - ma20);
    
    let threshold = atr * 150 / 100;
    
    let signal = 0;
    if current_price > ma20 && deviation > threshold {
        signal = -1;
    } else if current_price < ma20 && deviation > threshold {
        signal = 1;
    }
    
    if position_direction != 0 {
        let is_loss = false;
        if position_direction == 1 {
            is_loss = current_price < entry_avg_cost;
        } else {
            is_loss = current_price > entry_avg_cost;
        }
        
        if !last_trade_profit {
            martingale_multiplier = martingale_multiplier * 2;
        } else {
            martingale_multiplier = 1;
        }
        
        if signal != 0 && signal != position_direction {
            let close_amount = abs_val(account.stock);
            if close_amount > 0 {
                if position_direction == 1 {
                    orders.submit_market_sell(close_amount);
                } else {
                    orders.submit_market_buy(close_amount);
                }
                position_direction = 0;
                entry_avg_cost = 0;
                last_trade_profit = !is_loss;
            }
        }
    }
    
    if signal != 0 && position_direction == 0 {
        let available_cash = account.cash;
        let stock_value = account.stock * current_price;
        let total = available_cash + stock_value;
        
        let risk_amount = total * 50 / 100;
        let shares = risk_amount / current_price;
        
        let trade_size = shares * martingale_multiplier / 100;
        if trade_size < 1 {
            trade_size = 1;
        }
        
        if signal == 1 {
            orders.submit_market_buy(trade_size);
            position_direction = 1;
            entry_avg_cost = current_price;
        } else {
            orders.submit_market_sell(trade_size);
            position_direction = -1;
            entry_avg_cost = current_price;
        }
    }
}