let initialized = false;
let lot_size = 0;
let aggressive_factor = 0;
let tick_counter = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    tick_counter += 1;
    
    if !initialized {
        initialized = true;
        aggressive_factor = rng.rand_int(80, 100);
        
        let initial_cash_shares = (account.cash * 50 / 100) / market.price;
        if initial_cash_shares < 100 {
            lot_size = rng.rand_int(50, 100);
        } else {
            lot_size = rng.rand_int(initial_cash_shares * 30 / 100, initial_cash_shares * 50 / 100);
        }
        
        if lot_size < 10 {
            lot_size = 10;
        }
    }
    
    if tick_counter % 50 != 0 {
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let history_len = market.history_len();
    if history_len >= 5 {
        let current_price = market.price;
        let price_5_ago = market.history_price(4);
        
        if price_5_ago != 0 && price_5_ago < 1_000_000_000_000_000 {
            let price_change_percent = (current_price - price_5_ago) * 10000 / price_5_ago;
            if price_change_percent > 200 {
                let fomo_buy_amount = lot_size * aggressive_factor / 100;
                if fomo_buy_amount > 0 {
                    orders.submit_market_buy(fomo_buy_amount);
                }
                return;
            }
        }
    }
    
    let mid_price = 0;
    if market.bid_price_0 > 0 && market.ask_price_0 > 0 {
        mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    } else {
        mid_price = market.price;
    }
    
    if mid_price == 0 { return; }
    
    let base_spread = mid_price * 5 / 1000;
    let inventory = account.stock;
    
    let bid_distance = base_spread;
    let ask_distance = base_spread;
    
    if inventory > 1000 {
        bid_distance = base_spread * 150 / 100;
        ask_distance = base_spread * 50 / 100;
    } else if inventory <= 0 {
        bid_distance = base_spread * 50 / 100;
        ask_distance = base_spread * 150 / 100;
    }
    
    let bid_price = mid_price - bid_distance;
    let ask_price = mid_price + ask_distance;
    
    if bid_price <= 0 { bid_price = 1; }
    if ask_price <= 0 { ask_price = bid_price + 1_000; }
    
    let max_buy_amount = account.cash / bid_price;
    let buy_amount = lot_size;
    if max_buy_amount < buy_amount {
        buy_amount = max_buy_amount;
    }
    
    let sell_amount = lot_size;
    if account.stock < sell_amount {
        sell_amount = account.stock;
    }
    
    if buy_amount > 0 {
        orders.submit_limit_buy(bid_price, buy_amount);
    }
    
    if sell_amount > 0 {
        orders.submit_limit_sell(ask_price, sell_amount);
    }
}