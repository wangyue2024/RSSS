let initialized = false;
let lot_size = 0;
let stop_loss_panic = 0;
let std_dev_limit = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let pct_cap = rng.rand_int(1, 5);
        lot_size = (account.total_equity * pct_cap) / (100 * market.price);
        if lot_size < 1 { lot_size = 1; }
        stop_loss_panic = -rng.rand_int(50000, 200000);
        std_dev_limit = rng.rand_int(150000, 400000);
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < stop_loss_panic {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    if market.std_dev > std_dev_limit {
        return;
    }

    let history_len = market.history_len();
    if history_len < 10 { return; }

    let recent_vol_avg = 0;
    let vol_sum = 0;
    let j = 0;
    while j < 5 && j < history_len {
        vol_sum += market.history_volume(j);
        j += 1;
    }
    if j > 0 { recent_vol_avg = vol_sum / j; }

    let exhaustion_condition = market.price > market.ma_60 && market.volume * 10 < recent_vol_avg && recent_vol_avg > 0;

    if exhaustion_condition && account.stock == 0 {
        let round_price = ((market.price + 500000) / 1000000) * 1000000;
        let sell_amount = lot_size;
        if sell_amount > 0 {
            orders.submit_limit_sell(round_price, sell_amount);
        }
    }
}