let price_history = [];
let initialized = false;
let base_spread = 1000;
let max_inventory = 1000;
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        price_history.push(market.price);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }
    
    if price_history.len() >= 5 {
        let old_price = price_history[price_history.len() - 5];
        let price_change = (market.price - old_price) * 100 / old_price;
        if price_change > 2 || price_change < -2 {
            fomo_triggered = true;
            let pending_cnt = my_orders.pending_count();
            let i = 0;
            while i < pending_cnt {
                orders.submit_cancel(my_orders.pending_id(i));
                i += 1;
            }
            let buy_amount = account.cash / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }
    
    fomo_triggered = false;
    
    let current_tick = market.tick;
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            orders.submit_cancel(my_orders.pending_id(i));
        }
        i += 1;
    }
    
    let inventory = account.stock;
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    
    let buy_distance = base_spread;
    let sell_distance = base_spread;
    
    if inventory > max_inventory {
        buy_distance = base_spread * 150 / 100;
        sell_distance = base_spread * 50 / 100;
    } else if inventory <= 0 {
        buy_distance = base_spread * 50 / 100;
        sell_distance = base_spread * 150 / 100;
    }
    
    let buy_price = mid_price - buy_distance;
    let sell_price = mid_price + sell_distance;
    
    if buy_price > 0 {
        let cash_available = account.cash;
        let max_buy = cash_available / buy_price;
        let buy_amount = 10;
        if buy_amount > max_buy { buy_amount = max_buy; }
        if buy_amount > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }
    
    if sell_price > 0 {
        let stock_available = account.stock;
        let sell_amount = 10;
        if sell_amount > stock_available { sell_amount = stock_available; }
        if sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}