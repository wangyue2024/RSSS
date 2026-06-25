let initialized = false;
let price_buffer = [];
let state = 0;
let sell_tick = 0;
let buy_price_target = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        price_buffer = [];
    }
    
    if !market.trading_enabled { return; }
    
    price_buffer.push(market.price);
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if price_buffer.len() < 5 { return; }
    let delayed_price = price_buffer[0];
    
    if state == 0 {
        let threshold_price = delayed_price * 99 / 100;
        let cluster_volume = 0;
        
        if market.bid_price_0 <= delayed_price && market.bid_price_0 >= threshold_price {
            cluster_volume += market.bid_vol_0;
        }
        if market.bid_price_1 <= delayed_price && market.bid_price_1 >= threshold_price {
            cluster_volume += market.bid_vol_1;
        }
        if market.bid_price_2 <= delayed_price && market.bid_price_2 >= threshold_price {
            cluster_volume += market.bid_vol_2;
        }
        if market.bid_price_3 <= delayed_price && market.bid_price_3 >= threshold_price {
            cluster_volume += market.bid_vol_3;
        }
        if market.bid_price_4 <= delayed_price && market.bid_price_4 >= threshold_price {
            cluster_volume += market.bid_vol_4;
        }
        
        if cluster_volume > 1000 && account.stock > 0 {
            let sell_amt = account.stock;
            if sell_amt > 0 {
                orders.submit_market_sell(sell_amt);
                state = 1;
                sell_tick = market.tick;
                buy_price_target = delayed_price * 98 / 100;
            }
        }
    } else if state == 1 {
        if market.price <= buy_price_target && account.cash > 0 {
            let buy_amt = account.cash / market.price;
            if buy_amt > 0 {
                orders.submit_limit_buy(buy_price_target, buy_amt);
                state = 0;
            }
        } else if market.tick - sell_tick > 20 {
            state = 0;
        }
    }
}