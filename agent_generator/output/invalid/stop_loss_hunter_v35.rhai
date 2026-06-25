let initialized = false;
let lot_size_percent = 0;
let stop_loss_threshold = 0;
let attack_mode = false;
let attack_entry_price = 0;
let attack_position = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size_percent = rng.rand_int(3000, 5000);
        stop_loss_threshold = -rng.rand_int(500_000, 2_000_000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        attack_mode = false;
        return;
    }
    
    if attack_mode {
        if attack_position > 0 {
            if market.price <= attack_entry_price * 95 / 100 {
                orders.submit_market_buy(attack_position);
                attack_mode = false;
                attack_position = 0;
            }
        }
        return;
    }
    
    let current_price = market.price;
    let cluster_zone_lower = current_price * 98 / 100;
    let cluster_zone_upper = current_price * 997 / 1000;
    
    let cluster_volume = 0;
    
    if market.bid_price_0 > 0 && market.bid_price_0 >= cluster_zone_lower && market.bid_price_0 <= cluster_zone_upper {
        cluster_volume += market.bid_vol_0;
    }
    if market.bid_price_1 > 0 && market.bid_price_1 >= cluster_zone_lower && market.bid_price_1 <= cluster_zone_upper {
        cluster_volume += market.bid_vol_1;
    }
    if market.bid_price_2 > 0 && market.bid_price_2 >= cluster_zone_lower && market.bid_price_2 <= cluster_zone_upper {
        cluster_volume += market.bid_vol_2;
    }
    if market.bid_price_3 > 0 && market.bid_price_3 >= cluster_zone_lower && market.bid_price_3 <= cluster_zone_upper {
        cluster_volume += market.bid_vol_3;
    }
    if market.bid_price_4 > 0 && market.bid_price_4 >= cluster_zone_lower && market.bid_price_4 <= cluster_zone_upper {
        cluster_volume += market.bid_vol_4;
    }
    
    let min_cluster_volume = 5000;
    
    if cluster_volume >= min_cluster_volume && rng.rand_bool(70) {
        let sell_amount = account.cash * lot_size_percent / (10000 * current_price);
        if sell_amount > 0 {
            let actual_sell = if sell_amount > account.stock { account.stock } else { sell_amount };
            if actual_sell > 0 {
                orders.submit_market_sell(actual_sell);
                attack_mode = true;
                attack_entry_price = current_price;
                attack_position = actual_sell;
            }
        }
    }
}