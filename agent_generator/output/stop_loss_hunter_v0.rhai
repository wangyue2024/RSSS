let initialized = false;
let max_risk_shares = 0;
let cluster_threshold = 0;
let support_zone_width = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        
        let max_risk_capital = account.total_equity * 5 / 100;
        max_risk_shares = max_risk_capital / market.price;
        if max_risk_shares < 1 { max_risk_shares = 1; }
        
        cluster_threshold = rng.rand_int(50_000, 200_000);
        support_zone_width = market.price * 1 / 100;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    if market.std_dev > market.price * 3 / 100 {
        return;
    }
    
    let cluster_volume = 0;
    let cluster_price = 0;
    let current_price = market.price;
    
    let bid_prices = [market.bid_price_0, market.bid_price_1, market.bid_price_2, market.bid_price_3, market.bid_price_4];
    let bid_volumes = [market.bid_vol_0, market.bid_vol_1, market.bid_vol_2, market.bid_vol_3, market.bid_vol_4];
    
    let j = 0;
    while j < 5 {
        let price = bid_prices[j];
        let volume = bid_volumes[j];
        
        if price > 0 && price < current_price && volume > cluster_threshold {
            cluster_volume = volume;
            cluster_price = price;
            break;
        }
        j += 1;
    }
    
    if cluster_volume > 0 && cluster_price > 0 {
        if market.price > account.avg_cost && account.stock > 0 {
            let sell_amount = if max_risk_shares < account.stock { max_risk_shares } else { account.stock };
            if sell_amount > 0 {
                orders.submit_market_sell(sell_amount);
                
                let target_buy_price = cluster_price - support_zone_width;
                if target_buy_price > 0 {
                    let buy_amount = if max_risk_shares < 1000 { max_risk_shares } else { 1000 };
                    let bid_price = target_buy_price + 1;
                    orders.submit_limit_buy(bid_price, buy_amount);
                }
            }
        }
    } else {
        if account.stock > 0 && market.price > account.avg_cost {
            let sell_price = market.price + 1;
            let sell_amount = if max_risk_shares < account.stock { max_risk_shares } else { account.stock };
            orders.submit_limit_sell(sell_price, sell_amount);
        }
        
        if account.cash > market.price * 10 {
            let buy_price = market.price - support_zone_width + 1;
            if buy_price > 0 {
                let buy_amount = if max_risk_shares < 1000 { max_risk_shares } else { 1000 };
                orders.submit_limit_buy(buy_price, buy_amount);
            }
        }
    }
}