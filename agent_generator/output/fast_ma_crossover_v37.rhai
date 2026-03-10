let initialized = false;
let prev_ma5 = 0;
let prev_ma20 = 0;
let trade_size = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        trade_size = rng.rand_int(50, 200);
    }
    
    if !market.trading_enabled { return; }
    
    let current_ma5 = market.ma_5;
    let current_ma20 = market.ma_20;
    
    let crossover_up = (prev_ma5 <= prev_ma20) && (current_ma5 > current_ma20);
    let crossover_down = (prev_ma5 >= prev_ma20) && (current_ma5 < current_ma20);
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if crossover_up && account.stock == 0 {
        let base_price = market.ask_price_0;
        if base_price == 0 {
            base_price = market.price;
        }
        
        let rounded_price = ((base_price + 500_000) / 1_000_000) * 1_000_000;
        let buy_price = rounded_price + 1;
        
        let available_cash = account.cash;
        let max_shares = available_cash / buy_price;
        let buy_amount = if trade_size < max_shares { trade_size } else { max_shares };
        
        if buy_amount > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }
    
    if crossover_down && account.stock > 0 {
        let base_price = market.bid_price_0;
        if base_price == 0 {
            base_price = market.price;
        }
        
        let rounded_price = ((base_price + 500_000) / 1_000_000) * 1_000_000;
        let sell_price = rounded_price;
        
        orders.submit_limit_sell(sell_price, account.stock);
    }
    
    prev_ma5 = current_ma5;
    prev_ma20 = current_ma20;
}