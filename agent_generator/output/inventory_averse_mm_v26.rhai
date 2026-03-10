let initialized = false;
let price_history = [];
let last_fill_price = 0;
let last_fill_side = 0;
let last_trade_profit = 0;
let lot_size = 100;
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size = 100;
        last_fill_price = market.price;
        last_fill_side = 0;
        last_trade_profit = 0;
        fomo_triggered = false;
    }

    if !market.trading_enabled { return; }

    // Cancel all pending orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    // Update price history for FOMO detection
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }

    // Martingale sizing based on last trade loss
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let last_fill = fill_cnt - 1;
        last_fill_price = my_orders.fill_price(last_fill);
        last_fill_side = my_orders.fill_side(last_fill);
        
        if last_fill_side == 0 {
            last_trade_profit = market.price - last_fill_price;
        } else {
            last_trade_profit = last_fill_price - market.price;
        }
        
        if last_trade_profit < 0 {
            lot_size = lot_size * 2;
            if lot_size > 10000 {
                lot_size = 10000;
            }
        } else {
            lot_size = 100;
        }
    }

    // FOMO condition: price jumped >2% in last 5 ticks
    if price_history.len() >= 2 {
        let old_price = price_history[0];
        let jump_pct = (market.price - old_price) * 10000 / old_price;
        if jump_pct > 200 && !fomo_triggered {
            fomo_triggered = true;
            let buy_amount = clamp_val(account.cash / market.price, 1, 10000);
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }
    
    fomo_triggered = false;

    // Inventory-averse quoting
    let inventory = account.stock;
    let base_spread = 50000;
    let skew_factor = 200;

    let bid_offset = base_spread;
    let ask_offset = base_spread;

    if inventory > 1000 {
        let skew = (inventory - 1000) * skew_factor / 1000;
        bid_offset = bid_offset + skew;
        ask_offset = ask_offset - skew;
    } else if inventory <= 0 {
        let skew = (0 - inventory) * skew_factor / 1000;
        bid_offset = bid_offset - skew;
        ask_offset = ask_offset + skew;
    }

    if bid_offset < 1000 { bid_offset = 1000; }
    if ask_offset < 1000 { ask_offset = 1000; }

    let mid_price = market.price;
    let bid_price = mid_price - bid_offset;
    let ask_price = mid_price + ask_offset;

    // Off-by-One Pumper
    bid_price = bid_price + 1;

    // Place orders
    if bid_price > 0 && lot_size > 0 {
        orders.submit_limit_buy(bid_price, lot_size);
    }
    if ask_price > 0 && lot_size > 0 {
        orders.submit_limit_sell(ask_price, lot_size);
    }
}