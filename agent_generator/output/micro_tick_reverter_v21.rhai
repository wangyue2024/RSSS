let initialized = false;
let price_memory = [];
let tick_memory = [];
let stop_loss_threshold = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        stop_loss_threshold = -rng.rand_int(1000, 5000);
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    price_memory.push(market.price);
    tick_memory.push(market.tick);
    
    if price_memory.len() > 5 {
        price_memory.remove(0);
        tick_memory.remove(0);
    }
    
    if price_memory.len() == 5 {
        let old_price = price_memory[0];
        let new_price = price_memory[1];
        
        if new_price < old_price && account.cash > 1000000 {
            let buy_price = new_price - 1000;
            let buy_amount = 100;
            orders.submit_limit_buy(buy_price, buy_amount);
        } else if new_price > old_price && account.stock > 0 {
            let sell_price = new_price + 1000;
            let sell_amount = 100;
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}