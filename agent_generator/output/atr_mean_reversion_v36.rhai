let initialized = false;
let lot_size = 0;
let high_volatility = 0;

fn round_to_dollar(price) {
    let half_dollar = 500_000;
    let remainder = price % 1_000_000;
    if remainder >= half_dollar {
        price - remainder + 1_000_000
    } else {
        price - remainder
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
        let risk_cap = account.total_equity * 5 / 100;
        lot_size = rng.rand_int(1_000_000, risk_cap);
        high_volatility = micros(0, 1000);
    }
    
    if !market.trading_enabled { return; }
    
    if market.std_dev > high_volatility {
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let deviation = abs_val(market.price - market.ma_20);
    let atr_threshold = market.atr_14 * 3 / 2;
    
    if deviation > atr_threshold {
        if market.price > market.ma_20 && account.stock > 0 {
            if market.price > account.avg_cost {
                let sell_price = round_to_dollar(market.price);
                let sell_amount = lot_size;
                if sell_amount > account.stock {
                    sell_amount = account.stock;
                }
                orders.submit_limit_sell(sell_price, sell_amount);
            }
        } else if market.price < market.ma_20 && account.cash > 0 {
            let buy_price = round_to_dollar(market.price);
            let max_buy = account.cash / buy_price;
            let buy_amount = lot_size;
            if buy_amount > max_buy {
                buy_amount = max_buy;
            }
            if buy_amount > 0 {
                orders.submit_limit_buy(buy_price, buy_amount);
            }
        }
    }
}