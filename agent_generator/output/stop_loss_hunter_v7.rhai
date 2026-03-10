let initialized = false;
let risk_seeking = false;
let lot_size = 0;
let support_level = 0;
let resistance_level = 0;
let last_action_tick = -1000;
let cooldown_ticks = 5;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_seeking = rng.rand_bool(30);
        if risk_seeking {
            lot_size = account.total_equity * 50 / 100;
        } else {
            lot_size = account.total_equity * 5 / 100;
        }
        if lot_size < 1_000_000 {
            lot_size = 1_000_000;
        }
    }
    
    if !market.trading_enabled { return; }
    if market.tick - last_action_tick < cooldown_ticks { return; }
    
    let current_price = market.price;
    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    if risk_seeking {
        let available_cash = account.cash;
        let sell_amount = lot_size / current_price;
        if sell_amount > 0 && market.tick % 3 == 0 {
            let cluster_detected = false;
            let bid_vol_total = market.bid_vol_0 + market.bid_vol_1 + market.bid_vol_2;
            if bid_vol_total > 10000 && market.price - market.bid_price_0 < current_price * 50 / 10000 {
                cluster_detected = true;
            }
            
            if cluster_detected {
                let aggressive_sell = sell_amount * 120 / 100;
                if aggressive_sell * current_price < available_cash {
                    orders.submit_market_sell(aggressive_sell);
                    let buy_back_price = market.bid_price_0 * 95 / 100;
                    orders.submit_limit_buy(buy_back_price + 1, aggressive_sell);
                    last_action_tick = market.tick;
                }
            }
        }
    } else {
        if market.std_dev > current_price * 200 / 10000 {
            return;
        }
        
        let available_stock = account.stock;
        let sell_amount = lot_size / current_price;
        if sell_amount > available_stock {
            sell_amount = available_stock;
        }
        
        let ma_diff = abs_val(market.ma_5 - market.ma_20);
        if ma_diff < current_price * 50 / 10000 && sell_amount > 0 {
            let weak_bid = market.bid_price_0;
            let bid_depth = market.bid_vol_0 + market.bid_vol_1;
            if bid_depth > 5000 && current_price - weak_bid < current_price * 30 / 10000 {
                let push_amount = sell_amount * 80 / 100;
                if push_amount > 0 {
                    orders.submit_market_sell(push_amount);
                    let target_buy = weak_bid * 98 / 100;
                    orders.submit_limit_buy(target_buy + 1, push_amount);
                    last_action_tick = market.tick;
                }
            }
        }
    }
}