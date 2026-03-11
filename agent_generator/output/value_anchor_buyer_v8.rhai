let initialized = false;
let fair_value = 0;
let lot_size = 0;
let price_history = [];

fn on_tick() {
    if !initialized {
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        let max_position = account.total_equity * 5 / 100;
        lot_size = max_position / fair_value;
        if lot_size < 1 { lot_size = 1; }
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let price_risk = fair_value * 5 / 100;
    if market.std_dev > price_risk {
        return;
    }
    
    price_history.push(market.price);
    if price_history.len() > 6 {
        price_history.remove(0);
    }
    
    let fomo_trigger = false;
    if price_history.len() >= 6 {
        let old_price = price_history[0];
        let change = (market.price - old_price) * 100 / old_price;
        if change.abs_val() > 2 {
            fomo_trigger = true;
        }
    }
    
    if fomo_trigger {
        let buy_amount = lot_size * 3;
        if account.cash > market.price * buy_amount {
            orders.submit_market_buy(buy_amount);
        }
        return;
    }
    
    let threshold_95 = fair_value * 95 / 100;
    let threshold_90 = fair_value * 90 / 100;
    let bid_price = market.price;
    
    if bid_price < threshold_90 && account.cash > bid_price * lot_size * 3 {
        let my_bid_price = bid_price + 1;
        orders.submit_limit_buy(my_bid_price, lot_size * 3);
    } else if bid_price < threshold_95 && account.cash > bid_price * lot_size {
        let my_bid_price = bid_price + 1;
        orders.submit_limit_buy(my_bid_price, lot_size);
    }
}