let fair_value = 0;
let base_lot_percent = 0;
let aggressive_multiplier = 0;
let volatility_threshold = 0;
let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        base_lot_percent = rng.rand_int(1, 5);
        aggressive_multiplier = rng.rand_int(5, 10);
        volatility_threshold = rng.rand_int(1_500_000, 3_000_000);
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.std_dev > volatility_threshold {
        return;
    }
    
    let price = market.price;
    let available_cash = account.cash;
    let total_equity = account.total_equity;
    
    if price < fair_value {
        let base_lot = total_equity * base_lot_percent / 100;
        let buy_amount = 0;
        
        if price < fair_value * 90 / 100 {
            buy_amount = available_cash * 50 / 100;
            if buy_amount > base_lot * aggressive_multiplier {
                buy_amount = base_lot * aggressive_multiplier;
            }
        } else if price < fair_value * 95 / 100 {
            buy_amount = base_lot;
        }
        
        if buy_amount > 10000 && available_cash > buy_amount {
            orders.submit_limit_buy(price, buy_amount / price);
        }
    }
    
    let avg_cost = account.avg_cost;
    let stock_held = account.stock;
    
    if price > fair_value && price > avg_cost && stock_held > 0 {
        let sell_amount = stock_held * 10 / 100;
        if sell_amount > 0 {
            orders.submit_limit_sell(price, sell_amount);
        }
    }
}