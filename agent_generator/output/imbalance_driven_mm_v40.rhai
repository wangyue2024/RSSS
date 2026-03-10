let initialized = false;
let base_lot = 0;
let lot_size = 0;
let last_equity = 0;
let last_trade_profit = true;
let fomo_triggered = false;
let fomo_cooldown = 0;
let imbalance_factor = 0;
let spread_bps = 0;
let martingale_multiplier = 1;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(100, 500);
        lot_size = base_lot;
        last_equity = account.total_equity;
        imbalance_factor = rng.rand_int(1000, 5000);
        spread_bps = rng.rand_int(50, 200);
    }

    if !market.trading_enabled { return; }

    if fomo_cooldown > 0 {
        fomo_cooldown -= 1;
    } else {
        fomo_triggered = false;
    }

    let current_price = market.price;
    let price_change_threshold = current_price * 200 / 10000;
    
    if market.history_len() >= 5 {
        let price_5_ago = market.history_price(4);
        let price_change = abs_val(current_price - price_5_ago);
        
        if price_change > price_change_threshold && !fomo_triggered {
            fomo_triggered = true;
            fomo_cooldown = 10;
            
            let count = my_orders.pending_count();
            let i = 0;
            while i < count {
                let oid = my_orders.pending_id(i);
                orders.submit_cancel(oid);
                i += 1;
            }
            
            let buy_amount = lot_size;
            if buy_amount > 0 && account.cash > current_price * buy_amount {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }

    let equity_change = account.total_equity - last_equity;
    last_equity = account.total_equity;
    
    if my_orders.fill_count() > 0 {
        if equity_change < 0 {
            last_trade_profit = false;
            martingale_multiplier *= 2;
        } else {
            last_trade_profit = true;
            martingale_multiplier = 1;
        }
        lot_size = base_lot * martingale_multiplier;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let imbalance = market.order_imbalance;
    let adjustment = imbalance * imbalance_factor / 10000;
    
    let mid_price = current_price + adjustment;
    let spread = mid_price * spread_bps / 10000;
    
    if spread < 1 {
        spread = 1;
    }
    
    let bid_price = mid_price - spread;
    let ask_price = mid_price + spread;
    
    if bid_price < 1 {
        bid_price = 1;
    }
    if ask_price < 1 {
        ask_price = 1;
    }
    
    if lot_size > 0 {
        let max_buy = account.cash / bid_price;
        let buy_amount = lot_size;
        if buy_amount > max_buy {
            buy_amount = max_buy;
        }
        if buy_amount > 0 {
            orders.submit_limit_buy(bid_price, buy_amount);
        }
        
        let sell_amount = lot_size;
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }
        if sell_amount > 0 {
            orders.submit_limit_sell(ask_price, sell_amount);
        }
    }
}