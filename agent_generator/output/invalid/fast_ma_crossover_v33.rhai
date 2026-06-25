let initialized = false;
let prev_ma5 = 0;
let prev_ma20 = 0;
let fomo_price_window = [];
let fomo_window_size = 10;

fn on_tick() {
    if !initialized {
        initialized = true;
        prev_ma5 = market.ma_5;
        prev_ma20 = market.ma_20;
    }

    if !market.trading_enabled { return; }

    // Cancel all pending orders at start of tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    // Update FOMO price window
    fomo_price_window.push(market.price);
    if fomo_price_window.len() > fomo_window_size {
        fomo_price_window.remove(0);
    }

    // FOMO check: price jumped >2% in short window
    let fomo_triggered = false;
    if fomo_price_window.len() == fomo_window_size {
        let old_price = fomo_price_window[0];
        if old_price > 0 {
            let change = (market.price - old_price) * 10000 / old_price;
            if change > 200 { // 2% = 200 basis points
                fomo_triggered = true;
                // Market buy with 50% of available cash
                let buy_amount = account.cash * 5000 / 10000 / market.price;
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount);
                }
            }
        }
    }

    // Only proceed with MA strategy if FOMO not triggered
    if !fomo_triggered {
        let ma5_crossed_above = prev_ma5 <= prev_ma20 && market.ma_5 > market.ma_20;
        let ma5_crossed_below = prev_ma5 >= prev_ma20 && market.ma_5 < market.ma_20;

        if ma5_crossed_above {
            // Buy with 50% of cash
            let buy_amount = account.cash * 5000 / 10000 / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }

        if ma5_crossed_below && account.stock > 0 {
            // Stubborn holder quirk: only sell if price > avg_cost
            if market.price > account.avg_cost {
                orders.submit_market_sell(account.stock);
            }
        }
    }

    // Update MA history for next tick
    prev_ma5 = market.ma_5;
    prev_ma20 = market.ma_20;
}