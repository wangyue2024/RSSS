let initialized = false;
let lot_size = 0;
let panic_threshold = 0;
let price_history = [];
let last_processed_tick = -1;

fn on_tick() {
    if !initialized {
        panic_threshold = rng.rand_int(-50000, -10000);
        let max_lot = account.total_equity * 5 / 100;
        lot_size = rng.rand_int(1, max_lot);
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

    if market.total_ticks <= 5 { return; }

    price_history.push(market.price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }

    if market.tick <= last_processed_tick + 5 { return; }
    last_processed_tick = market.tick;

    let delayed_price = price_history[0];
    let current_price = market.price;

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let std_dev_threshold = current_price * 5 / 100;
    if market.std_dev > std_dev_threshold { return; }

    let cluster_range_low = delayed_price * 98 / 100;
    let cluster_range_high = delayed_price * 99 / 100;
    
    let cluster_volume = 0;
    let levels = 5;
    let j = 0;
    while j < levels {
        let bid_price = 0;
        let bid_vol = 0;
        
        if j == 0 { bid_price = market.bid_price_0; bid_vol = market.bid_vol_0; }
        if j == 1 { bid_price = market.bid_price_1; bid_vol = market.bid_vol_1; }
        if j == 2 { bid_price = market.bid_price_2; bid_vol = market.bid_vol_2; }
        if j == 3 { bid_price = market.bid_price_3; bid_vol = market.bid_vol_3; }
        if j == 4 { bid_price = market.bid_price_4; bid_vol = market.bid_vol_4; }
        
        if bid_price >= cluster_range_low && bid_price <= cluster_range_high {
            cluster_volume += bid_vol;
        }
        j += 1;
    }

    let min_cluster_size = lot_size * 5;
    if cluster_volume > min_cluster_size && account.stock >= lot_size {
        orders.submit_market_sell(lot_size);
        let buy_back_price = delayed_price * 97 / 100;
        orders.submit_limit_buy(buy_back_price, lot_size);
    }
}