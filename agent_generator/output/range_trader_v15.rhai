let initialized = false;
let min_spread = 200000;
let base_amount = 500;
let max_amount = 2000;

fn on_tick() {
    if !initialized {
        initialized = true;
        min_spread = rng.rand_int(150000, 300000);
        base_amount = rng.rand_int(300, 700);
        max_amount = rng.rand_int(1500, 3000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    let spread = market.high_20 - market.low_20;
    if spread <= 0 { return; }
    
    let range_ratio = min_spread * 100 / spread;
    let position_size = base_amount * range_ratio / 100;
    let amount = clamp_val(position_size, base_amount, max_amount);
    
    let buy_price = market.low_20 + spread * 5 / 100;
    let sell_price = market.high_20 - spread * 5 / 100;
    
    if buy_price > 0 && account.cash > buy_price * amount {
        orders.submit_limit_buy(buy_price, amount);
    }
    
    if account.stock >= amount && account.avg_cost > 0 && sell_price > account.avg_cost {
        orders.submit_limit_sell(sell_price, amount);
    }
}