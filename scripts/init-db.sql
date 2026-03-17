-- ShopWorthy PostgreSQL schema
-- Shared between shopworthy-inventory and shopworthy-admin

CREATE TABLE IF NOT EXISTS inventory (
    id SERIAL PRIMARY KEY,
    product_id INTEGER UNIQUE NOT NULL,
    product_name TEXT NOT NULL,
    sku TEXT UNIQUE,
    stock_count INTEGER DEFAULT 0,
    reorder_threshold INTEGER DEFAULT 10,
    warehouse_location TEXT,
    last_updated TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS suppliers (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    contact_email TEXT,
    webhook_url TEXT,               -- SSRF vector: user-supplied URL
    api_key TEXT                    -- stored in plaintext
);

CREATE TABLE IF NOT EXISTS admin_sessions (
    id SERIAL PRIMARY KEY,
    session_token TEXT,
    username TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Seed inventory data matching products in shopworthy-api SQLite DB
INSERT INTO inventory (product_id, product_name, sku, stock_count, reorder_threshold, warehouse_location) VALUES
(1, 'Wireless Headphones Pro', 'ELEC-WHP-001', 47, 10, 'A1-B3'),
(2, 'Running Shoes X3', 'FOOT-RSX-002', 120, 20, 'B2-C4'),
(3, 'Organic Coffee Blend', 'FOOD-OCB-003', 200, 50, 'C3-D1'),
(4, 'Yoga Mat Premium', 'SPRT-YMP-004', 85, 15, 'D4-E2'),
(5, 'Smart Water Bottle', 'SPRT-SWB-005', 60, 10, 'E1-F3'),
(6, 'Mechanical Keyboard', 'ELEC-MKB-006', 30, 5, 'F2-G4'),
(7, 'Stainless Steel Pan Set', 'KTCH-SSP-007', 45, 10, 'G3-H1'),
(8, 'Bamboo Desk Organizer', 'OFFC-BDO-008', 90, 15, 'H4-I2'),
(9, 'Protein Powder Vanilla', 'FOOD-PPV-009', 150, 30, 'I1-J3'),
(10, 'USB-C Hub 7-in-1', 'ELEC-UCH-010', 75, 10, 'J2-K4')
ON CONFLICT (product_id) DO NOTHING;

-- Seed supplier data
INSERT INTO suppliers (name, contact_email, webhook_url, api_key) VALUES
('TechSource Global', 'orders@techsource.example.com', 'https://webhooks.techsource.example.com/restock', 'ts-api-key-abc123'),
('FoodFresh Co', 'supply@foodfresh.example.com', 'https://api.foodfresh.example.com/notify', 'ff-api-key-xyz789')
ON CONFLICT DO NOTHING;
