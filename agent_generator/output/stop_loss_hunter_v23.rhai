let initialized = false;
let lot_size = 100;
let last_trade_profit = 0;
let delayed_prices = [];
let cluster_detected = false;
let pending_sell_order_id = 0;
let in_sell_phase = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size = rng.rand_int(80, 120);
    }

    if !market.trading_enabled {
        return;
    }

    delayed_prices.push(market.price);
    if delayed_prices.len() > 5 {
        delayed_prices.remove(0);
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let latest_fill_price = my_orders.fill_price(0);
        let latest_fill_side = my_orders.fill_side(0);
        
        if latest_fill_side == 1 {
            last_trade_profit = (market.price - latest_fill_price) * lot_size;
        } else if latest_fill_side == 0 {
            last_trade_profit = (latest_fill_price - market.price) * lot_size;
        }
        
        if last_trade_profit < 0 {
            lot_size = lot_size * 2;
        } else {
            lot_size = 100;
        }
        
        in_sell_phase = false;
        pending_sell_order_id = 0;
    }

    if delayed_prices.len() < 5 {
        return;
    }

    let delayed_price = delayed_prices[0];
    let support_zone = delayed_price * 985 / 1000;

    let cluster_volume = 0;
    if market.bid_price_0 <= support_zone && market.bid_price_0 > 0 {
        cluster_volume += market.bid_vol_0;
    }
    if market.bid_price_1 <= support_zone && market.bid_price_1 > 0 {
        cluster_volume += market.bid_vol_1;
    }
    if market.bid_price_2 <= support_zone && market.bid_price_2 > 0 {
        cluster_volume += market.bid_vol_2;
    }
    if market.bid_price_3 <= support_zone && market.bid_price_3 > 0 {
        cluster_volume += market.bid_vol_3;
    }
    if market.bid_price_4 <= support_zone && market.bid_price_4 > 0 {
        cluster_volume += market.bid_vol_4;
    }

    cluster_detected = cluster_volume > 500 && market.price > support_zone;

    if !in_sell_phase && cluster_detected {
        orders.submit_market_sell(lot_size);
        in_sell_phase = true;
    }

    if in_sell_phase && !cluster_detected {
        let buy_price = market.bid_price_0 - 1;
        if buy_price > 0 {
            orders.submit_limit_buy(buy_price + 1, lot_size);
        }
        in_sell_phase = false;
    }
}