let initialized = false;
let delayed_price = 0;
let last_ticks = 0;
let trade_lot_size = 100;
let base_lot_size = 100;
let last_trade_price = 0;
let price_history = [];
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(80, 120);
        trade_lot_size = base_lot_size;
    }
    
    if !market.trading_enabled { return; }
    
    // Update price history
    price_history.push(market.price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }
    
    // Delayed reaction: use price from 5 ticks ago
    if market.history_len() >= 6 {
        delayed_price = market.history_price(5);
    } else {
        delayed_price = market.price;
    }
    
    // FOMO check (2% jump in 2 ticks)
    if price_history.len() >= 3 {
        let current = market.price;
        let two_ago = price_history[price_history.len() - 3];
        if two_ago != 0 {
            let jump_pct = (current - two_ago).abs() * 10000 / two_ago;
            if jump_pct > 200 {
                fomo_triggered = true;
                let count = my_orders.pending_count();
                let i = 0;
                while i < count {
                    let oid = my_orders.pending_id(i);
                    orders.submit_cancel(oid);
                    i += 1;
                }
                orders.submit_market_buy(trade_lot_size);
                return;
            }
        }
    }
    
    fomo_triggered = false;
    
    // Martingale sizing
    if last_trade_price != 0 && account.stock > 0 && account.avg_cost != 0 {
        let current_price = delayed_price;
        let cost_basis = account.avg_cost;
        if current_price < cost_basis {
            trade_lot_size = base_lot_size * 2;
        } else {
            trade_lot_size = base_lot_size;
        }
    }
    
    // Periodic rebalancing every 10 ticks
    last_ticks += 1;
    if last_ticks >= 10 {
        last_ticks = 0;
        
        // Cancel existing orders
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        let equity = account.total_equity;
        if equity == 0 { return; }
        
        let stock_value = account.stock * delayed_price;
        let stock_pct = stock_value * 10000 / equity;  // basis points (100% = 10000)
        
        if stock_pct > 5500 {
            // Sell stock
            let target_stock_value = equity * 5000 / 10000;
            let excess_value = stock_value - target_stock_value;
            let shares_to_sell = excess_value / delayed_price;
            
            if shares_to_sell > 0 {
                let sell_amount = shares_to_sell;
                if sell_amount > trade_lot_size {
                    sell_amount = trade_lot_size;
                }
                let sell_price = delayed_price * 9995 / 10000;  // Slightly below
                orders.submit_limit_sell(sell_price, sell_amount);
                last_trade_price = sell_price;
            }
        } else if stock_pct < 4500 {
            // Buy stock
            let target_stock_value = equity * 5000 / 10000;
            let deficit_value = target_stock_value - stock_value;
            let shares_to_buy = deficit_value / delayed_price;
            
            if shares_to_buy > 0 {
                let buy_amount = shares_to_buy;
                if buy_amount > trade_lot_size {
                    buy_amount = trade_lot_size;
                }
                let buy_price = delayed_price * 10005 / 10000;  // Slightly above
                orders.submit_limit_buy(buy_price, buy_amount);
                last_trade_price = buy_price;
            }
        }
    }
}