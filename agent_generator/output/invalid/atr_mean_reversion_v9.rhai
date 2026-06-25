let initialized = false;
let round_base = 1_000_000;

fn on_tick() {
    if !initialized {
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
    
    let price = market.price;
    let ma20 = market.ma_20;
    let atr = market.atr_14;
    
    let deviation = abs_val(price - ma20);
    let threshold = (atr * 150) / 100;
    
    if deviation > threshold && atr > 0 {
        let target_price = if price > ma20 { 
            price - threshold 
        } else { 
            price + threshold 
        };
        
        let half_base = round_base / 2;
        let rounded_price = if target_price >= 0 {
            (target_price + half_base) / round_base * round_base
        } else {
            (target_price - half_base) / round_base * round_base
        };
        
        let max_possible = 1000;
        
        if price > ma20 {
            let amount_to_sell = max_possible;
            if account.stock > 0 {
                let sell_amount = if account.stock < amount_to_sell { account.stock } else { amount_to_sell };
                if sell_amount > 0 {
                    orders.submit_limit_sell(rounded_price, sell_amount);
                }
            }
        } else {
            let amount_to_buy = max_possible;
            let max_affordable = account.cash / rounded_price;
            if max_affordable > 0 {
                let buy_amount = if max_affordable < amount_to_buy { max_affordable } else { amount_to_buy };
                if buy_amount > 0 {
                    orders.submit_limit_buy(rounded_price, buy_amount);
                }
            }
        }
    }
}