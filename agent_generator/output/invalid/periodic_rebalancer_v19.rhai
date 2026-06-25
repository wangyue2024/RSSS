let initialized = false;
let last_rebalance_tick = 0;
let base_lot_size = 100;
let current_lot_size = base_lot_size;
let last_trade_was_loss = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_rebalance_tick = market.tick;
        if rng.rand_bool(50) {
            current_lot_size = base_lot_size * 2;
        }
    }
    
    if !market.trading_enabled { return; }

    let current_tick = market.tick;
    
    if account.unrealized_pnl < 0 {
        current_lot_size = base_lot_size * 2;
        last_trade_was_loss = true;
    } else {
        current_lot_size = base_lot_size;
        last_trade_was_loss = false;
    }

    let fomo_triggered = false;
    if market.history_len() >= 3 {
        let price_now = market.price;
        let price_3_ticks_ago = market.history_price(2);
        let percent_change = (price_now - price_3_ticks_ago) * 10000 / price_3_ticks_ago;
        if percent_change > 200 {
            fomo_triggered = true;
        }
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if fomo_triggered {
        if account.cash > market.price {
            let buy_amount = current_lot_size;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
        return;
    }

    if current_tick - last_rebalance_tick >= 10 {
        last_rebalance_tick = current_tick;
        
        let stock_value = account.stock * market.price;
        let total_eq = account.total_equity;
        if total_eq == 0 { return; }
        
        let stock_ratio = stock_value * 10000 / total_eq;
        
        if stock_ratio > 5500 {
            let target_stock_value = total_eq * 5000 / 10000;
            let sell_value = stock_value - target_stock_value;
            let sell_amount = sell_value / market.price;
            
            if sell_amount > 0 {
                let price = market.bid_price_0 - micros(0, 1);
                if price > 0 {
                    orders.submit_limit_sell(price, sell_amount);
                }
            }
        } else if stock_ratio < 4500 {
            let target_stock_value = total_eq * 5000 / 10000;
            let buy_value = target_stock_value - stock_value;
            let buy_amount = buy_value / market.price;
            
            if buy_amount > 0 && account.cash > buy_amount * market.price {
                let price = market.ask_price_0 + micros(0, 1);
                if price > 0 {
                    orders.submit_limit_buy(price, buy_amount);
                }
            }
        }
    }
}