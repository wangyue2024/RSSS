let initialized = false;
let lot_size = 0;
let max_std_dev = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        
        let total_cap = account.total_equity;
        let five_percent = total_cap * 5 / 100;
        let price = market.price;
        if price > 0 {
            let max_shares = five_percent / price;
            if max_shares < 1 {
                max_shares = 1;
            }
            lot_size = rng.rand_int(1, max_shares);
        } else {
            lot_size = 10;
        }
        
        max_std_dev = rng.rand_int(50000, 200000);
    }
    
    if !market.trading_enabled {
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if market.std_dev > max_std_dev {
        return;
    }
    
    if market.bid_price_0 == 0 || market.ask_price_0 == 0 {
        return;
    }
    
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let inventory = account.stock;
    let base_spread = 10;
    
    let buy_spread = base_spread;
    let sell_spread = base_spread;
    
    if inventory > 1000 {
        buy_spread = base_spread * 3 / 2;
        sell_spread = base_spread * 1 / 2;
    } else if inventory <= 0 {
        buy_spread = base_spread * 1 / 2;
        sell_spread = base_spread * 3 / 2;
    }
    
    let buy_price = mid_price - (mid_price * buy_spread) / 10000;
    let sell_price = mid_price + (mid_price * sell_spread) / 10000;
    
    if buy_price < 1 {
        buy_price = 1;
    }
    if sell_price < 1 {
        sell_price = 1;
    }
    
    let buy_amount = 0;
    if account.cash >= buy_price {
        let max_buy = account.cash / buy_price;
        if max_buy < lot_size {
            buy_amount = max_buy;
        } else {
            buy_amount = lot_size;
        }
    }
    
    let sell_amount = 0;
    if account.stock > 0 {
        if account.stock < lot_size {
            sell_amount = account.stock;
        } else {
            sell_amount = lot_size;
        }
    }
    
    if buy_amount > 0 {
        orders.submit_limit_buy(buy_price, buy_amount);
    }
    
    if sell_amount > 0 {
        orders.submit_limit_sell(sell_price, sell_amount);
    }
}