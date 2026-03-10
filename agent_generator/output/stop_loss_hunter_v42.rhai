let initialized = false;
let panic_threshold = 0;
let hunting_cooldown = 0;
let last_attack_tick = 0;

fn on_tick() {
    if !initialized {
        panic_threshold = rng.rand_int(50_000, 200_000);
        hunting_cooldown = 0;
        last_attack_tick = 0;
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if hunting_cooldown > 0 {
        hunting_cooldown = hunting_cooldown - 1;
    }

    if account.stock > 0 && account.unrealized_pnl < -panic_threshold {
        orders.submit_market_sell(account.stock);
        return;
    }

    let bid_vol_total = market.bid_vol_0 + market.bid_vol_1 + market.bid_vol_2 + market.bid_vol_3 + market.bid_vol_4;
    let cluster_price = 0;
    let cluster_vol = 0;
    if market.bid_price_0 > 0 && market.bid_vol_0 > 5000 {
        cluster_price = market.bid_price_0;
        cluster_vol = market.bid_vol_0;
    } else if market.bid_price_1 > 0 && market.bid_vol_1 > 8000 {
        cluster_price = market.bid_price_1;
        cluster_vol = market.bid_vol_1;
    } else if market.bid_price_2 > 0 && market.bid_vol_2 > 10000 {
        cluster_price = market.bid_price_2;
        cluster_vol = market.bid_vol_2;
    }

    let cluster_detected = cluster_price > 0 && cluster_vol > 0 && market.price > cluster_price && (market.price - cluster_price) * 100 / market.price < 2;

    if cluster_detected && account.stock > 0 && hunting_cooldown == 0 && market.tick - last_attack_tick > 100 {
        let attack_vol = account.stock * 70 / 100;
        if attack_vol > 0 {
            orders.submit_market_sell(attack_vol);
            let buy_back_price = cluster_price * 97 / 100;
            if buy_back_price > 0 {
                let buy_amount = attack_vol * 110 / 100;
                orders.submit_limit_buy(buy_back_price, buy_amount);
            }
            hunting_cooldown = 25;
            last_attack_tick = market.tick;
        }
        return;
    }

    if account.stock == 0 && hunting_cooldown == 0 && market.rsi_14 < 65 && market.ma_5 > market.ma_20 {
        let cash_to_use = account.cash * 30 / 100;
        let buy_price = market.ask_price_0;
        if buy_price > 0 {
            let buy_amount = cash_to_use / buy_price;
            if buy_amount > 0 {
                orders.submit_limit_buy(buy_price, buy_amount);
            }
        }
    }
}