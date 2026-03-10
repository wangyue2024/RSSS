let initialized = false;
let lot_size = 0;
let cluster_threshold = 0;
let target_drop_pct = 0;
let in_attack = false;
let attack_sell_size = 0;
let buyback_target = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        cluster_threshold = rng.rand_int(5_000, 30_000);
        target_drop_pct = rng.rand_int(50, 150);
        lot_size = rng.rand_int(25, 50);
    }

    if !market.trading_enabled { return; }
    if market.tick >= market.total_ticks / 5 { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if in_attack {
        if market.price <= buyback_target && attack_sell_size > 0 {
            let buy_amount = attack_sell_size;
            orders.submit_market_buy(buy_amount);
            in_attack = false;
            attack_sell_size = 0;
        }
        return;
    }

    let support_volume = 0;
    let depth = 0;
    while depth < 5 {
        let price = market.bid_price_0 - depth * 10_000;
        let vol = market.bid_vol_0;
        if depth == 1 { vol = market.bid_vol_1; }
        if depth == 2 { vol = market.bid_vol_2; }
        if depth == 3 { vol = market.bid_vol_3; }
        if depth == 4 { vol = market.bid_vol_4; }
        if price < market.price - 200_000 { break; }
        support_volume += vol;
        depth += 1;
    }

    if support_volume > cluster_threshold {
        let sell_value = account.cash * lot_size / 100;
        let sell_size = sell_value / market.price;
        if sell_size > 0 {
            orders.submit_market_sell(sell_size);
            in_attack = true;
            attack_sell_size = sell_size;
            buyback_target = market.price * (10000 - target_drop_pct) / 10000;
        }
    }
}