let initialized = false;
let target_total_shares = 100_000;
let shares_acquired = 0;
let horizon_ticks = 1000;
let remaining_ticks_in_horizon = 0;
let volume_lookback = 20;
let avg_cost_anchor = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        remaining_ticks_in_horizon = horizon_ticks;
        avg_cost_anchor = account.avg_cost;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let fill_cnt = my_orders.fill_count();
    i = 0;
    while i < fill_cnt {
        let fill_side = my_orders.fill_side(i);
        let fill_amt = my_orders.fill_amount(i);
        if fill_side == 0 {
            shares_acquired += fill_amt;
        } else if fill_side == 1 {
            shares_acquired -= fill_amt;
        }
        i += 1;
    }

    let shares_left_to_buy = target_total_shares - shares_acquired;
    if shares_left_to_buy > 0 && remaining_ticks_in_horizon > 0 {
        let hist_len = market.history_len();
        let lookback = if hist_len < volume_lookback { hist_len } else { volume_lookback };
        let recent_volumes = [];
        let idx = 0;
        while idx < lookback {
            recent_volumes.push(market.history_volume(idx));
            idx += 1;
        }

        let avg_recent_volume = if recent_volumes.len() > 0 { arr_mean(recent_volumes) } else { market.volume };
        let volume_ratio = if avg_recent_volume > 0 { market.volume * 100 / avg_recent_volume } else { 100 };
        let volume_ratio = clamp_val(volume_ratio, 50, 200);

        let base_slice = shares_left_to_buy / remaining_ticks_in_horizon;
        let dynamic_slice = base_slice * volume_ratio / 100;
        let slice_size = clamp_val(dynamic_slice, 1, shares_left_to_buy);

        let vwap = market.vwap;
        let best_bid = market.bid_price_0;
        let best_ask = market.ask_price_0;

        let buy_price = if best_bid > 0 && best_bid < vwap {
            best_bid
        } else if vwap > 0 {
            vwap - 1
        } else {
            market.price - 1
        };

        if buy_price > 0 && slice_size > 0 && market.volume > 0 {
            orders.submit_limit_buy(buy_price, slice_size);
        }

        remaining_ticks_in_horizon -= 1;
    } else if remaining_ticks_in_horizon <= 0 {
        remaining_ticks_in_horizon = horizon_ticks;
    }

    if account.stock > 0 {
        let current_price = market.price;
        let cost_basis = if avg_cost_anchor == 0 { account.avg_cost } else { avg_cost_anchor };
        if current_price > cost_basis {
            let sell_size = account.stock / 10;
            if sell_size > 0 {
                let sell_price = if market.ask_price_0 > 0 { market.ask_price_0 } else { current_price + 1 };
                orders.submit_limit_sell(sell_price, sell_size);
            }
        }
    }
}