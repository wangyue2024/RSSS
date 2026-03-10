let initialized = false;
let data_ready = false;
let entry_made = false;
let entry_price = 0;
let panic_threshold = 0;
let price_buffer = [];

fn round_to_dollar(price) {
    let dollar = 1_000_000;
    ((price + 500_000) / dollar) * dollar
}

fn on_tick() {
    if !initialized {
        panic_threshold = -rng.rand_int(5_000, 50_000);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    price_buffer.push(market.price);
    if price_buffer.len() > 6 {
        price_buffer.remove(0);
    }
    
    if price_buffer.len() == 6 {
        data_ready = true;
    }
    
    if !data_ready { return; }
    
    let delayed_price = price_buffer[0];
    let current_price = delayed_price;
    
    let unrealized_pnl_with_delay = (current_price - entry_price) * account.stock;
    
    if entry_made && account.stock > 0 {
        if unrealized_pnl_with_delay < panic_threshold {
            orders.submit_market_sell(account.stock);
            entry_made = false;
        } else if current_price <= entry_price * 98 / 100 {
            orders.submit_market_sell(account.stock);
            entry_made = false;
        }
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if !entry_made && account.stock == 0 && rng.rand_bool(1) {
        let buy_price = round_to_dollar(current_price);
        let amount_to_buy = account.cash / buy_price;
        if amount_to_buy > 0 {
            orders.submit_limit_buy(buy_price, amount_to_buy);
            entry_made = true;
            entry_price = buy_price;
        }
    }
    
    if entry_made && account.stock > 0 {
        let take_profit_price = round_to_dollar(entry_price * 105 / 100);
        orders.submit_limit_sell(take_profit_price, account.stock);
    }
}