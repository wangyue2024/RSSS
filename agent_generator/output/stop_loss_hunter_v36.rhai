let data_ready = false;
let old_price = 0;
let old_tick = 0;
let lookback_ticks = 5;
let action_interval = 50;
let last_action_tick = -100;
let cluster_threshold = 5000;
let order_count_threshold = 3;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !data_ready {
        old_price = market.price;
        old_tick = market.tick;
        data_ready = true;
        return;
    }

    let current_tick = market.tick;
    if current_tick == old_tick { return; }

    old_price = market.price;
    old_tick = current_tick;

    if (current_tick - last_action_tick) < action_interval { return; }

    let cancel_count = my_orders.pending_count();
    let c = 0;
    while c < cancel_count {
        let oid = my_orders.pending_id(c);
        orders.submit_cancel(oid);
        c += 1;
    }

    let current_price = market.price;
    let support_level = current_price * 99 / 100;

    let cluster_volume = 0;
    let cluster_orders = 0;

    let bid_price_0 = market.bid_price_0;
    let bid_price_1 = market.bid_price_1;
    let bid_price_2 = market.bid_price_2;
    let bid_price_3 = market.bid_price_3;
    let bid_price_4 = market.bid_price_4;

    let bid_vol_0 = market.bid_vol_0;
    let bid_vol_1 = market.bid_vol_1;
    let bid_vol_2 = market.bid_vol_2;
    let bid_vol_3 = market.bid_vol_3;
    let bid_vol_4 = market.bid_vol_4;

    if bid_price_0 > 0 && bid_price_0 <= support_level {
        cluster_volume += bid_vol_0;
        cluster_orders += 1;
    }
    if bid_price_1 > 0 && bid_price_1 <= support_level {
        cluster_volume += bid_vol_1;
        cluster_orders += 1;
    }
    if bid_price_2 > 0 && bid_price_2 <= support_level {
        cluster_volume += bid_vol_2;
        cluster_orders += 1;
    }
    if bid_price_3 > 0 && bid_price_3 <= support_level {
        cluster_volume += bid_vol_3;
        cluster_orders += 1;
    }
    if bid_price_4 > 0 && bid_price_4 <= support_level {
        cluster_volume += bid_vol_4;
        cluster_orders += 1;
    }

    if cluster_volume > cluster_threshold && cluster_orders >= order_count_threshold {
        let sell_amount = account.stock * 40 / 100;
        if sell_amount > 0 {
            orders.submit_market_sell(sell_amount);
            last_action_tick = current_tick;
            
            let buy_back_price = support_level * 97 / 100;
            let buy_back_amount = sell_amount;
            if account.cash >= buy_back_price * buy_back_amount / 1_000_000 {
                orders.submit_limit_buy(buy_back_price, buy_back_amount);
            }
        }
    }
}