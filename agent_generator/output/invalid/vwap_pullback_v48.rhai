let initialized = false;
let lot_size = 0;
let buy_threshold = 0;
let sell_threshold = 0;
let max_std_dev = 0;
let last_order_tick = -999;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_capital = account.total_equity * 5 / 100;
        let price = market.price;
        if price > 0 {
            let max_shares = max_capital / price;
            lot_size = rng.rand_int(1, max_shares);
            if lot_size == 0 { lot_size = 1; }
        } else {
            lot_size = 100;
        }
        buy_threshold = rng.rand_int(100, 300);
        sell_threshold = rng.rand_int(50, 150);
        max_std_dev = rng.rand_int(100_000, 500_000);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    let price = market.price;
    let vwap = market.vwap;
    let std_dev = market.std_dev;
    let cash = account.cash;
    let stock = account.stock;
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if std_dev > max_std_dev { return; }
    
    let pending_after_cancel = my_orders.pending_count();
    if pending_after_cancel > 0 { return; }
    
    if stock == 0 && cash > price {
        let threshold_price = vwap * (10000 - buy_threshold) / 10000;
        if price < threshold_price {
            let buy_price = price + 10_000;
            if buy_price < vwap {
                let amount = lot_size;
                if amount * buy_price <= cash {
                    orders.submit_limit_buy(buy_price, amount);
                    last_order_tick = current_tick;
                }
            }
        }
    } else if stock > 0 {
        let avg_cost = account.avg_cost;
        if avg_cost == 0 { avg_cost = price; }
        let target_price = vwap;
        if price >= target_price {
            let sell_price = price - 10_000;
            if sell_price > avg_cost {
                let amount = stock;
                if amount > 0 {
                    orders.submit_limit_sell(sell_price, amount);
                    last_order_tick = current_tick;
                }
            }
        }
    }
}