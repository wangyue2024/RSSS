let initialized = false;
let state = 0;
let base_lot_size = 0;
let current_lot_size = 0;
let stop_loss_price = 0;
let sold_price = 0;
let sold_amount = 0;
let last_pnl = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(5, 20);
        current_lot_size = base_lot_size;
        state = 0;
    }
    
    if !market.trading_enabled { return; }
    
    if state == 0 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        let cluster_detected = false;
        let cluster_price = 0;
        let cumulative_bid = market.bid_vol_0 + market.bid_vol_1 + market.bid_vol_2;
        
        if cumulative_bid > 5000 {
            let avg_bid = (market.bid_price_0 * market.bid_vol_0 + 
                          market.bid_price_1 * market.bid_vol_1 + 
                          market.bid_price_2 * market.bid_vol_2) / cumulative_bid;
            
            if avg_bid < market.price && (market.price - avg_bid) < market.price * 2 / 100 {
                cluster_detected = true;
                cluster_price = avg_bid;
            }
        }
        
        if cluster_detected && account.stock >= current_lot_size {
            orders.submit_market_sell(current_lot_size);
            sold_price = market.price;
            sold_amount = current_lot_size;
            stop_loss_price = sold_price * 102 / 100;
            last_pnl = account.realized_pnl;
            state = 1;
        }
    }
    
    if state == 1 {
        if market.price > stop_loss_price {
            let cover_amount = sold_amount - account.stock;
            if cover_amount > 0 {
                orders.submit_market_buy(cover_amount);
            }
            
            if account.realized_pnl < last_pnl {
                current_lot_size = current_lot_size * 2;
                if current_lot_size > 100 { current_lot_size = 100; }
            } else {
                current_lot_size = base_lot_size;
            }
            
            state = 0;
            return;
        }
        
        let rebound_threshold = cluster_price * 98 / 100;
        if market.price <= rebound_threshold && account.stock < sold_amount {
            let buy_back = sold_amount - account.stock;
            if buy_back > 0 {
                orders.submit_limit_buy(rebound_threshold, buy_back);
            }
        }
        
        let pending_buys = 0;
        let pcount = my_orders.pending_count();
        let j = 0;
        while j < pcount {
            if my_orders.pending_side(j) == "buy" {
                pending_buys += 1;
            }
            j += 1;
        }
        
        if account.stock >= sold_amount && pending_buys == 0 {
            if account.realized_pnl < last_pnl {
                current_lot_size = current_lot_size * 2;
                if current_lot_size > 100 { current_lot_size = 100; }
            } else {
                current_lot_size = base_lot_size;
            }
            state = 0;
        }
    }
}