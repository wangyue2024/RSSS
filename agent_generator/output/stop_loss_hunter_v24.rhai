let initialized = false;
let attack_phase = 0;
let attack_price = 0;
let attack_size = 0;
let last_cancel_check = 0;

fn round_price(price) {
    let million = 1_000_000;
    ((price + 500_000) / million) * million
}

fn on_tick() {
    if !initialized {
        initialized = true;
        attack_phase = 0;
        attack_price = 0;
        attack_size = 0;
        last_cancel_check = 0;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    if current_tick - last_cancel_check >= 1 {
        last_cancel_check = current_tick;
        
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let placed_tick = my_orders.pending_placed_tick(i);
            if current_tick - placed_tick >= 3 {
                let oid = my_orders.pending_id(i);
                orders.submit_cancel(oid);
            }
            i += 1;
        }
    }
    
    if attack_phase == 0 {
        let total_bid_volume = 0;
        let cluster_volume = 0;
        let cluster_price = 0;
        
        let bid_prices = [market.bid_price_0, market.bid_price_1, market.bid_price_2, market.bid_price_3, market.bid_price_4];
        let bid_volumes = [market.bid_vol_0, market.bid_vol_1, market.bid_vol_2, market.bid_vol_3, market.bid_vol_4];
        
        let i = 0;
        while i < 5 {
            total_bid_volume += bid_volumes[i];
            if bid_prices[i] > 0 && bid_prices[i] % 1_000_000 == 0 {
                if bid_volumes[i] > cluster_volume {
                    cluster_volume = bid_volumes[i];
                    cluster_price = bid_prices[i];
                }
            }
            i += 1;
        }
        
        if cluster_volume > 0 && total_bid_volume > 0 {
            let cluster_ratio = cluster_volume * 100 / total_bid_volume;
            
            if cluster_ratio > 40 && cluster_price < market.price {
                let sell_size = cluster_volume * 70 / 100;
                if sell_size > 10000 {
                    sell_size = 10000;
                }
                
                if sell_size > 0 {
                    orders.submit_market_sell(sell_size);
                    attack_phase = 1;
                    attack_price = cluster_price;
                    attack_size = sell_size;
                }
            }
        }
    } else if attack_phase == 1 {
        if market.price <= attack_price - 500_000 {
            let buy_size = attack_size + attack_size * 10 / 100;
            
            if account.cash >= buy_size * market.price {
                let buy_price = round_price(market.price - 100_000);
                orders.submit_limit_buy(buy_price, buy_size);
                attack_phase = 2;
            }
        } else if current_tick - last_cancel_check > 10 {
            attack_phase = 0;
        }
    } else if attack_phase == 2 {
        if account.stock >= attack_size {
            attack_phase = 0;
            attack_price = 0;
            attack_size = 0;
        } else if current_tick - last_cancel_check > 20 {
            attack_phase = 0;
            attack_price = 0;
            attack_size = 0;
        }
    }
    
    if attack_phase == 0 && my_orders.pending_count() == 0 {
        if account.stock > 0 {
            let target_price = round_price(market.price + 200_000);
            if target_price > market.ask_price_0 {
                orders.submit_limit_sell(target_price, account.stock);
            }
        } else if account.cash > 1_000_000_000 {
            let target_price = round_price(market.price - 200_000);
            if target_price < market.bid_price_0 && target_price > 0 {
                let buy_amount = account.cash / target_price / 10;
                if buy_amount > 0 {
                    orders.submit_limit_buy(target_price, buy_amount);
                }
            }
        }
    }
}