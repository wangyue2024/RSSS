let initialized = false;
let lot_size = 0;
let risk_percentage = 0;
let buy_offset_percent = 0;
let sell_offset_percent = 0;
let max_wait_ticks = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_percentage = rng.rand_int(40, 50);
        lot_size = rng.rand_int(30, 50);
        buy_offset_percent = rng.rand_int(5, 20);
        sell_offset_percent = rng.rand_int(5, 20);
        max_wait_ticks = 3;
    }

    if !market.trading_enabled { return; }

    // Cancel any orders older than max_wait_ticks
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed = my_orders.pending_placed_tick(i);
        if (market.tick - placed) >= max_wait_ticks {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    // FOMO check - price jump >2% in last 5 ticks
    let fomo_triggered = false;
    if market.history_len() >= 5 {
        let old_price = market.history_price(5);
        let current_price = market.price;
        if old_price > 0 {
            // Calculate percentage change: ((current - old) * 10000) / old
            let change_pct = (current_price - old_price) * 10000 / old_price;
            if change_pct > 200 {  // >2%
                fomo_triggered = true;
                let buy_amount = (account.cash * 5000) / (10000 * market.price);
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount);
                }
            }
        }
    }

    if !fomo_triggered {
        // Mean reversion logic
        if market.history_len() >= 1 {
            let prev_price = market.history_price(1);
            let curr_price = market.price;
            
            if curr_price < prev_price {
                // Price dropped - place limit buy
                let buy_price = curr_price - (curr_price * buy_offset_percent) / 10000;
                let cash_to_use = (account.cash * risk_percentage) / 100;
                let buy_amount = cash_to_use / market.price;
                if buy_amount > 0 && buy_price > 0 {
                    orders.submit_limit_buy(buy_price, buy_amount);
                }
            } else if curr_price > prev_price {
                // Price rose - place limit sell
                let sell_price = curr_price + (curr_price * sell_offset_percent) / 10000;
                let stock_to_sell = (account.stock * lot_size) / 100;
                if stock_to_sell > 0 && sell_price > 0 {
                    orders.submit_limit_sell(sell_price, stock_to_sell);
                }
            }
        }
    }
}