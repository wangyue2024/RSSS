let initialized = false;
let fair_value = 0;
let lot_size_pct = 0;
let recent_prices = [];
let recent_ticks_window = 5;

fn on_tick() {
    if !initialized {
        fair_value = 100_000_000 * (100 + rng.rand_int(-5, 5)) / 100;
        lot_size_pct = rng.rand_int(40, 50);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    recent_prices.push(market.price);
    if recent_prices.len() > recent_ticks_window {
        recent_prices.remove(0);
    }
    
    if recent_prices.len() == recent_ticks_window {
        let old_price = recent_prices[0];
        if market.price * 100 > old_price * 102 {
            let count = my_orders.pending_count();
            let i = 0;
            while i < count {
                let oid = my_orders.pending_id(i);
                orders.submit_cancel(oid);
                i += 1;
            }
            let amount = (account.cash / market.price) * 50 / 100;
            if amount > 0 {
                orders.submit_market_buy(amount);
            }
            return;
        }
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.price > fair_value && market.price > account.avg_cost {
        let stock_available = account.stock;
        if stock_available > 0 {
            let threshold1 = fair_value * 105 / 100;
            let threshold2 = fair_value * 110 / 100;
            let amount_to_sell = 0;
            if market.price > threshold2 {
                amount_to_sell = stock_available * lot_size_pct / 100;
            } else if market.price > threshold1 {
                amount_to_sell = stock_available * 20 / 100;
            }
            if amount_to_sell > 0 {
                orders.submit_limit_sell(market.price, amount_to_sell);
            }
        }
    } else if market.price <= fair_value {
        let cash_available = account.cash;
        let amount_to_buy = (cash_available / market.price) * lot_size_pct / 100;
        if amount_to_buy > 0 {
            orders.submit_limit_buy(market.price, amount_to_buy);
        }
    }
}