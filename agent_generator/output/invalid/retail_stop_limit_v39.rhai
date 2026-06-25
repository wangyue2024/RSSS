let initialized = false;
let position_entered = false;
let entry_price = 0;
let delayed_prices = [];
let last_trade_loss = false;
let base_lot = 100;
let current_lot = base_lot;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(50, 200);
        current_lot = base_lot;
    }
    
    if !market.trading_enabled { return; }
    
    delayed_prices.push(market.price);
    if delayed_prices.len() > 5 {
        delayed_prices.remove(0);
    }
    
    if !position_entered && delayed_prices.len() == 5 && rng.rand_bool(1) {
        let buy_price = delayed_prices[0];
        let buy_amount = current_lot;
        
        orders.submit_limit_buy(buy_price, buy_amount);
        entry_price = buy_price;
        position_entered = true;
        
        let take_profit_price = entry_price * 105 / 100;
        let stop_loss_price = entry_price * 98 / 100;
        
        if take_profit_price > entry_price {
            orders.submit_limit_sell(take_profit_price, buy_amount);
        }
        
        if stop_loss_price > entry_price {
            orders.submit_market_sell(buy_amount);
        }
    }
    
    if position_entered {
        let last_trade_check = account.realized_pnl < 0 || market.price < entry_price;
        if last_trade_check {
            last_trade_loss = true;
            current_lot = base_lot * 2;
        } else {
            last_trade_loss = false;
            current_lot = base_lot;
        }
        
        if account.stock == 0 {
            position_entered = false;
            entry_price = 0;
            
            let count = my_orders.pending_count();
            let i = 0;
            while i < count {
                let oid = my_orders.pending_id(i);
                orders.submit_cancel(oid);
                i += 1;
            }
        }
    }
}