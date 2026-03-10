let initialized = false;
let stop_loss_threshold = 0;
let volume_lookback = 5;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = -rng.rand_int(50_000, 500_000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    if account.unrealized_pnl < stop_loss_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        } else if account.stock < 0 {
            orders.submit_market_buy(-account.stock);
        }
        return;
    }
    
    if market.volume > 0 && market.price > market.ma_60 {
        let hist_len = market.history_len();
        if hist_len >= volume_lookback {
            let vol_sum = 0;
            let j = 0;
            while j < volume_lookback {
                vol_sum += market.history_volume(hist_len - 1 - j);
                j += 1;
            }
            let avg_vol = vol_sum / volume_lookback;
            if market.volume * 10 < avg_vol {
                let round_price = ((market.price + 500_000) / 1_000_000) * 1_000_000;
                let order_qty = 100;
                if account.cash >= round_price * order_qty {
                    orders.submit_limit_sell(round_price, order_qty);
                }
            }
        }
    }
}