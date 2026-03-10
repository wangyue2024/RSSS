let initialized = false;
let entered_trade = false;
let lot_size = 0;
let take_profit_price = 0;
let stop_loss_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        
        let max_lot_value = account.total_equity * 5 / 100;
        let shares_possible = max_lot_value / market.price;
        if shares_possible > 0 {
            lot_size = rng.rand_int(1, shares_possible);
        } else {
            lot_size = 0;
        }
    }
    
    if !market.trading_enabled { return; }
    
    let price_2_percent = market.price * 2 / 100;
    
    if !entered_trade {
        let threshold = market.price * 2 / 100;
        if market.std_dev < threshold && lot_size > 0 {
            if rng.rand_bool(10) {
                orders.submit_market_buy(lot_size);
                entered_trade = true;
                take_profit_price = account.avg_cost * 105 / 100;
                stop_loss_price = account.avg_cost * 98 / 100;
            }
        }
    } else {
        if account.stock >= lot_size {
            if market.price >= take_profit_price {
                orders.submit_limit_sell(take_profit_price, account.stock);
            } else if market.price <= stop_loss_price {
                orders.submit_market_sell(account.stock);
            }
        }
        
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
    }
}