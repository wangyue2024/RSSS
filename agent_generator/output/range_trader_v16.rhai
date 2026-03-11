let initialized = false;
let panic_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(1000, 5000);
    }

    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.tick < market.total_ticks / 5 {
        if account.unrealized_pnl < panic_threshold && account.stock > 0 {
            orders.submit_market_sell(account.stock);
            return;
        }
        
        let spread = market.high_20 - market.low_20;
        let base_size = 100;
        let size_factor = 1000000;
        if spread > 0 {
            size_factor = 2000000 * 1000 / spread;
        }
        if size_factor > 2000000 {
            size_factor = 2000000;
        }
        let pos_size = base_size * size_factor / 1000000;
        if pos_size < 10 {
            pos_size = 10;
        }
        
        let buy_buffer = spread * 5 / 100;
        let sell_buffer = spread * 5 / 100;
        let buy_price = market.low_20 + buy_buffer;
        let sell_price = market.high_20 - sell_buffer;
        
        let max_buy = account.cash / buy_price;
        let buy_amount = pos_size;
        if buy_amount > max_buy {
            buy_amount = max_buy;
        }
        if buy_amount > 0 && buy_price > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
        
        let sell_amount = pos_size;
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }
        if sell_amount > 0 && sell_price > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}