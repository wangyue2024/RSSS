let initialized = false;
let rebalance_counter = 0;
let panic_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(10_000, 100_000);
    }
    
    if !market.trading_enabled { return; }
    
    if account.unrealized_pnl < panic_threshold {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    rebalance_counter += 1;
    if rebalance_counter >= 10 {
        rebalance_counter = 0;
        
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        let equity = account.total_equity;
        if equity == 0 {
            return;
        }
        
        let stock_value = account.stock * market.price;
        let stock_pct = (stock_value * 100) / equity;
        
        if stock_pct > 55 {
            let target_stock_value = equity / 2;
            let sell_value = stock_value - target_stock_value;
            let sell_amount = sell_value / market.price;
            
            if sell_amount > 0 {
                let raw_price = market.price;
                let round_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
                if round_price < raw_price {
                    round_price = round_price + 1_000_000;
                }
                orders.submit_limit_sell(round_price, sell_amount);
            }
        } else if stock_pct < 45 {
            let target_stock_value = equity / 2;
            let buy_value = target_stock_value - stock_value;
            let buy_amount = buy_value / market.price;
            
            if buy_amount > 0 {
                let raw_price = market.price;
                let round_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
                if round_price > raw_price {
                    round_price = round_price - 1_000_000;
                }
                if round_price <= 0 {
                    round_price = 1_000_000;
                }
                orders.submit_limit_buy(round_price, buy_amount);
            }
        }
    }
}