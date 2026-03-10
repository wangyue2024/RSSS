let initialized = false;
let lot_size = 0;
let panic_buy_triggered = false;
let panic_sell_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_capital = account.total_equity * 5 / 100;
        if market.price > 0 {
            let max_shares = max_capital / market.price;
            if max_shares > 0 {
                lot_size = rng.rand_int(1, max_shares);
            } else {
                lot_size = 1;
            }
        } else {
            lot_size = 1;
        }
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if market.history_len() >= 5 {
        let current_price = market.price;
        let price_5_ago = market.history_price(4);
        if price_5_ago > 0 {
            let price_change = abs_val(current_price - price_5_ago) * 10000 / price_5_ago;
            if price_change > 200 {
                panic_buy_triggered = true;
            }
        }
    }
    
    if panic_buy_triggered {
        if lot_size > 0 {
            orders.submit_market_buy(lot_size);
        }
        panic_buy_triggered = false;
        return;
    }
    
    if market.std_dev > 0 {
        let volatility = market.std_dev * 10000 / market.price;
        if volatility > 500 {
            return;
        }
    }
    
    let rand_val = rng.rand_int(0, 99);
    
    if rand_val < 5 {
        let buy_price_offset_pct = rng.rand_int(-100, -10);
        let buy_price = market.price + (market.price * buy_price_offset_pct) / 10000;
        if buy_price < 0 { buy_price = 1; }
        let buy_qty = rng.rand_int(1, lot_size);
        if buy_qty > 0 && account.cash >= buy_price * buy_qty {
            orders.submit_limit_buy(buy_price, buy_qty);
        }
    } else if rand_val > 95 {
        let sell_price_offset_pct = rng.rand_int(10, 100);
        let sell_price = market.price + (market.price * sell_price_offset_pct) / 10000;
        let sell_qty = rng.rand_int(1, lot_size);
        if sell_qty > 0 && account.stock >= sell_qty {
            orders.submit_limit_sell(sell_price, sell_qty);
        }
    }
}