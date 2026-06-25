let initialized = false;
let cluster_threshold = 20_000;
let push_size = 5_000;
let profit_target = 50_000;
let max_position = 50_000;
let order_lifetime = 3;
let last_push_tick = 0;
let push_cooldown = 50;

fn on_tick() {
    if !initialized {
        initialized = true;
        cluster_threshold = rng.rand_int(15_000, 25_000);
        push_size = rng.rand_int(3_000, 7_000);
        profit_target = rng.rand_int(40_000, 60_000);
        push_cooldown = rng.rand_int(40, 60);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed = my_orders.pending_placed_tick(i);
        if (current_tick - placed) > order_lifetime {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if (current_tick - last_push_tick) < push_cooldown {
        return;
    }
    
    let total_sell_pressure = market.ask_vol_0 + market.ask_vol_1 + market.ask_vol_2;
    let total_bid_support = market.bid_vol_0 + market.bid_vol_1 + market.bid_vol_2;
    
    let spread = market.ask_price_0 - market.bid_price_0;
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    
    let is_cluster_below = total_bid_support > cluster_threshold && spread < 1000;
    let weak_market = total_sell_pressure < 3_000 && market.rsi_14 > 45;
    
    if is_cluster_below && weak_market && account.stock < max_position {
        let sell_amt = if push_size > account.stock { account.stock } else { push_size };
        if sell_amt > 0 {
            orders.submit_market_sell(sell_amt);
            last_push_tick = current_tick;
            
            let buy_back_price = market.bid_price_0 - profit_target;
            if buy_back_price > 0 {
                let buy_amt = sell_amt + (sell_amt / 10);
                orders.submit_limit_buy(buy_back_price, buy_amt);
            }
        }
    }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let net_buy = 0;
        let j = 0;
        while j < fill_cnt {
            let side = my_orders.fill_side(j);
            let amt = my_orders.fill_amount(j);
            if side == 0 {
                net_buy += amt;
            } else {
                net_buy -= amt;
            }
            j += 1;
        }
        
        if net_buy > 0 && account.cash > 1_000_000 {
            let adj_price = market.ask_price_0 + 500;
            let adj_amt = net_buy / 2;
            if adj_amt > 0 {
                orders.submit_limit_sell(adj_price, adj_amt);
            }
        }
    }
}