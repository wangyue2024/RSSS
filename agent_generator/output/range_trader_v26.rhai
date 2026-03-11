let initialized = false;
let base_lot = 100;
let current_lot = base_lot;
let last_realized = 0;
let loss_flag = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_realized = account.realized_pnl;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.high_20 <= market.low_20 { return; }

    let spread = market.high_20 - market.low_20;
    let spread_threshold = 500_000;
    let spread_mult = if spread < spread_threshold { 2 } else { 1 };

    let loss_detected = account.realized_pnl < last_realized;
    if loss_detected && !loss_flag {
        loss_flag = true;
        current_lot = current_lot * 2;
        if current_lot > 10_000 { current_lot = 10_000; }
    }
    if !loss_detected && loss_flag {
        loss_flag = false;
        current_lot = base_lot;
    }
    last_realized = account.realized_pnl;

    let lot = current_lot * spread_mult;

    let buy_target_raw = market.low_20 + 50_000;
    let sell_target_raw = market.high_20 - 50_000;

    let round_buy = ((buy_target_raw + 500_000) / 1_000_000) * 1_000_000;
    let round_sell = ((sell_target_raw + 500_000) / 1_000_000) * 1_000_000;

    let min_price = market.bid_price_0 + 10_000;
    let max_price = market.ask_price_0 - 10_000;

    if round_buy >= min_price && round_buy < round_sell && round_buy > 0 {
        orders.submit_limit_buy(round_buy, lot);
    }
    if round_sell <= max_price && round_sell > round_buy && round_sell > 0 {
        orders.submit_limit_sell(round_sell, lot);
    }
}