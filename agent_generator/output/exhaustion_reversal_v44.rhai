let initialized = false;
let panic_threshold = 0;
let volume_history = [];
let exhaustion_detected = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = rng.rand_int(-30_000, -10_000);
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < panic_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        if account.stock < 0 {
            orders.submit_market_buy(-account.stock);
        }
        return;
    }

    volume_history.push(market.volume);
    if volume_history.len() > 10 {
        volume_history.remove(0);
    }

    let vol_avg = 0;
    if volume_history.len() > 0 {
        let sum = 0;
        let j = 0;
        while j < volume_history.len() {
            sum += volume_history[j];
            j += 1;
        }
        vol_avg = sum / volume_history.len();
    }

    let low_volume_cond = false;
    if vol_avg > 0 {
        low_volume_cond = market.volume * 100 / vol_avg < 15;
    }

    if market.price > market.ma_60 && low_volume_cond {
        exhaustion_detected = true;
    } else {
        exhaustion_detected = false;
    }

    if exhaustion_detected && market.bid_price_0 > 0 {
        let sell_amount = 100;
        if account.stock >= sell_amount {
            orders.submit_limit_sell(market.bid_price_0, sell_amount);
        } else if account.stock > 0 {
            orders.submit_limit_sell(market.bid_price_0, account.stock);
        } else {
            orders.submit_limit_sell(market.bid_price_0, sell_amount);
        }
    }
}