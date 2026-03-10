let initialized = false;
let fomo_triggered = false;
let last_price = 0;
let price_history = [];
let volume_history = [];
let lookback_window = 20;
let volume_avg = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_price = market.price;
        return;
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

    // Update history arrays
    if price_history.len() >= lookback_window {
        price_history.remove(0);
        volume_history.remove(0);
    }
    price_history.push(last_price);
    volume_history.push(market.volume);

    // Calculate volume average if we have enough data
    if volume_history.len() >= 10 {
        let sum = arr_sum(volume_history);
        volume_avg = sum / volume_history.len();
    }

    // FOMO condition: price jumped >2% in one tick
    let price_change_pct = (market.price - last_price) * 100 / last_price;
    if price_change_pct > 2 && !fomo_triggered {
        let max_buy = account.cash / market.price;
        if max_buy > 0 {
            orders.submit_market_buy(max_buy);
            fomo_triggered = true;
        }
        last_price = market.price;
        return;
    }

    // Reset FOMO if price stabilizes
    if abs_val(price_change_pct) < 1 {
        fomo_triggered = false;
    }

    // Core exhaustion strategy
    let current_volume = market.volume;
    let is_exhaustion = market.price > market.ma_60 && 
                        current_volume > 0 && 
                        volume_avg > 0 && 
                        current_volume * 10 < volume_avg && 
                        market.rsi_14 > 70;

    // Stubborn holder: only sell if profitable
    if is_exhaustion && account.stock > 0 && market.price > account.avg_cost {
        // Sell half position at bid price minus 1 (to ensure fill)
        let sell_amount = account.stock / 2;
        if sell_amount > 0 {
            let target_price = market.bid_price_0 - 1;
            if target_price > 0 {
                orders.submit_limit_sell(target_price, sell_amount);
            }
        }
    }

    // Off-by-one pumper: place aggressive buy if conditions align
    if market.price < market.ma_60 && market.rsi_14 < 40 && !fomo_triggered {
        let buy_amount = (account.cash / market.price) / 4;
        if buy_amount > 0 {
            let bid_price = market.ask_price_0 - 1;
            if bid_price > 0 {
                orders.submit_limit_buy(bid_price, buy_amount);
            }
        }
    }

    last_price = market.price;
}