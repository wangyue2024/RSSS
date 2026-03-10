let initialized = false;
let max_inventory = 1000;
let lot_size = 0;
let std_dev_threshold_pct = 5;

fn on_tick() {
    if !initialized {
        let capital = account.total_equity;
        let max_lot_capital = (capital * 5) / 100;
        let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
        if mid_price > 0 {
            lot_size = (max_lot_capital / mid_price).max(1);
        } else {
            lot_size = 100;
        }
        initialized = true;
    }

    if !market.trading_enabled {
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let std_dev_threshold = (mid_price * std_dev_threshold_pct) / 100;
    if market.std_dev > std_dev_threshold {
        return;
    }

    let inventory = account.stock;
    let base_spread = (mid_price * 2) / 100;
    let half_spread = base_spread / 2;

    let bid_distance = 0;
    let ask_distance = 0;

    if inventory > max_inventory {
        bid_distance = (half_spread * 150) / 100;
        ask_distance = (half_spread * 50) / 100;
    } else if inventory <= 0 {
        bid_distance = (half_spread * 50) / 100;
        ask_distance = (half_spread * 150) / 100;
    } else {
        let inventory_ratio = (inventory * 100) / max_inventory;
        let bid_adj = 100 + inventory_ratio;
        let ask_adj = 100 - inventory_ratio;
        bid_distance = (half_spread * bid_adj) / 100;
        ask_distance = (half_spread * ask_adj) / 100;
    }

    let bid_price = mid_price - bid_distance;
    let ask_price = mid_price + ask_distance;

    if bid_price > 0 && bid_price < market.ask_price_0 && lot_size > 0 {
        orders.submit_limit_buy(bid_price, lot_size);
    }
    if ask_price > 0 && ask_price > market.bid_price_0 && lot_size > 0 {
        orders.submit_limit_sell(ask_price, lot_size);
    }
}