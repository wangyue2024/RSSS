let initialized = false;
let target_buy_shares = 0;
let remaining_buy_shares = 0;
let max_order_age_ticks = 3;
let fomo_price_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        target_buy_shares = 1000;
        remaining_buy_shares = target_buy_shares;
    }

    if !market.trading_enabled { return; }

    // Update FOMO price history (store last 5 ticks)
    fomo_price_history.push(market.price);
    if fomo_price_history.len() > 5 {
        fomo_price_history.remove(0);
    }

    // Cancel orders older than max_order_age_ticks
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick > max_order_age_ticks {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    // Process fills to update remaining_buy_shares
    let fill_count = my_orders.fill_count();
    let j = 0;
    while j < fill_count {
        let fill_side = my_orders.fill_side(j);
        let fill_amount = my_orders.fill_amount(j);
        if fill_side == 0 {
            remaining_buy_shares -= fill_amount;
        }
        j += 1;
    }
    if remaining_buy_shares < 0 { remaining_buy_shares = 0; }

    // FOMO CHECK: price jump > 2% in last 5 ticks
    let fomo_triggered = false;
    if fomo_price_history.len() == 5 {
        let old_price = fomo_price_history[0];
        let price_change_pct = (market.price - old_price) * 100 / old_price;
        if price_change_pct > 2 {
            fomo_triggered = true;
            if remaining_buy_shares > 0 {
                orders.submit_market_buy(remaining_buy_shares);
                remaining_buy_shares = 0;
            }
        }
    }

    // If FOMO triggered, skip normal VWAP logic
    if fomo_triggered { return; }

    // VWAP DYNAMIC SLICING: base order size on recent volume
    let slice_amount = 0;
    if remaining_buy_shares > 0 {
        // Use last 5 ticks volume average as reference
        let recent_vol_total = 0;
        let history_len = market.history_len();
        let lookback_ticks = if history_len < 5 { history_len } else { 5 };
        let k = 0;
        while k < lookback_ticks {
            recent_vol_total += market.history_volume(k);
            k += 1;
        }
        let avg_recent_vol = if lookback_ticks > 0 { recent_vol_total / lookback_ticks } else { 1 };

        // Determine slice size: higher volume -> larger slice (10-50% of remaining)
        let volume_ratio = avg_recent_vol * 100 / (if market.volume > 0 { market.volume } else { 1 });
        let base_slice_pct = clamp_val(volume_ratio, 10, 50);
        slice_amount = remaining_buy_shares * base_slice_pct / 100;
        if slice_amount < 1 { slice_amount = 1; }
        if slice_amount > remaining_buy_shares { slice_amount = remaining_buy_shares; }

        // Place limit buy slightly below current price (at best bid)
        let buy_price = if market.bid_price_0 > 0 { market.bid_price_0 } else { market.price * 99 / 100 };
        orders.submit_limit_buy(buy_price, slice_amount);
    }

    // DIAMOND HANDS SELL: only sell above average cost
    if account.stock > 0 && market.price > account.avg_cost {
        let sell_amount = account.stock / 10;
        if sell_amount < 1 { sell_amount = 1; }
        let sell_price = if market.ask_price_0 > 0 { market.ask_price_0 } else { market.price * 101 / 100 };
        orders.submit_limit_sell(sell_price, sell_amount);
    }
}