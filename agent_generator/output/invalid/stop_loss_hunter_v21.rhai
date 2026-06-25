let initialized = false;
let panic_threshold = 0;
let cluster_threshold = 5000;
let hunting_mode = false;
let hunting_buy_order_id = -1;
let hunting_start_tick = 0;
let hunting_duration = 5;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = rng.rand_int(50000, 200000);
        cluster_threshold = rng.rand_int(3000, 8000);
        hunting_duration = rng.rand_int(3, 8);
    }

    if !market.trading_enabled { return; }

    // Panic check - only sell if price > avg_cost (no selling at loss)
    if account.unrealized_pnl < -panic_threshold && market.price > account.avg_cost {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        hunting_mode = false;
        hunting_buy_order_id = -1;
        
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }

    // Check hunting order status
    if hunting_mode {
        let found = false;
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            if my_orders.pending_id(i) == hunting_buy_order_id {
                found = true;
                let age = market.tick - my_orders.pending_placed_tick(i);
                if age > hunting_duration {
                    orders.submit_cancel(hunting_buy_order_id);
                    hunting_mode = false;
                    hunting_buy_order_id = -1;
                }
                break;
            }
            i += 1;
        }
        if !found {
            hunting_mode = false;
            hunting_buy_order_id = -1;
        }
    }

    // Cancel all orders except hunting order
    let pending_count = my_orders.pending_count();
    let to_cancel = [];
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        if !(hunting_mode && oid == hunting_buy_order_id) {
            to_cancel.push(oid);
        }
        i += 1;
    }
    
    i = 0;
    while i < to_cancel.len() {
        orders.submit_cancel(to_cancel[i]);
        i += 1;
    }

    // If in hunting mode, don't initiate new actions
    if hunting_mode {
        return;
    }

    // Check for stop-loss clusters (only if we can sell at profit)
    if account.stock > 0 && market.price > account.avg_cost {
        let upper_bound = market.price * 995 / 1000;
        let lower_bound = market.price * 985 / 1000;
        
        let cluster_volume = 0;
        
        if market.bid_price_0 >= lower_bound && market.bid_price_0 <= upper_bound {
            cluster_volume += market.bid_vol_0;
        }
        if market.bid_price_1 >= lower_bound && market.bid_price_1 <= upper_bound {
            cluster_volume += market.bid_vol_1;
        }
        if market.bid_price_2 >= lower_bound && market.bid_price_2 <= upper_bound {
            cluster_volume += market.bid_vol_2;
        }
        if market.bid_price_3 >= lower_bound && market.bid_price_3 <= upper_bound {
            cluster_volume += market.bid_vol_3;
        }
        if market.bid_price_4 >= lower_bound && market.bid_price_4 <= upper_bound {
            cluster_volume += market.bid_vol_4;
        }
        
        if cluster_volume > cluster_threshold {
            let sell_amount = account.stock;
            orders.submit_market_sell(sell_amount);
            
            let buy_price = market.price * 998 / 1000;
            hunting_buy_order_id = orders.submit_limit_buy(buy_price, sell_amount);
            hunting_mode = true;
            hunting_start_tick = market.tick;
        }
    }
}