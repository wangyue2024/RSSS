let initialized = false;
let last_prices = [];
let baseline_spread = 0;
let max_position = 0;
let lot_size = 0;
let fomo_threshold = 0;

fn on_tick() {
    if !initialized {
        baseline_spread = rng.rand_int(5000, 30000);
        max_position = rng.rand_int(5000, 25000);
        lot_size = rng.rand_int(100, 500);
        fomo_threshold = 20000;
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    last_prices.push(market.price);
    if last_prices.len() > 10 {
        last_prices.remove(0);
    }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if last_prices.len() == 10 {
        let oldest = last_prices[0];
        let change = (market.price - oldest) * 10000 / oldest;
        if change > fomo_threshold && change < 50000 {
            let buy_amount = (account.cash * 50) / (100 * market.price);
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }
    
    let inventory = account.stock;
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    
    let inventory_skew = 0;
    if inventory > 1000 {
        inventory_skew = (inventory * baseline_spread) / (max_position * 2);
    } else if inventory < 0 {
        inventory_skew = -((abs_val(inventory) * baseline_spread) / (max_position * 2));
    }
    
    let bid_spread = baseline_spread + inventory_skew;
    let ask_spread = baseline_spread - inventory_skew;
    
    let bid_price = mid_price - bid_spread;
    let ask_price = mid_price + ask_spread;
    
    let available_cash = account.cash;
    let available_stock = account.stock;
    
    let buy_amount = clamp_val(lot_size, 1, (available_cash * 50) / (100 * bid_price));
    let sell_amount = clamp_val(lot_size, 1, available_stock);
    
    if buy_amount > 0 && bid_price > 0 {
        orders.submit_limit_buy(bid_price + 1, buy_amount);
    }
    
    if sell_amount > 0 && ask_price > 0 {
        orders.submit_limit_sell(ask_price, sell_amount);
    }
}