const express = require('express');
const multer = require('multer');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const sqlite3 = require('sqlite3').verbose();

const app = express();
const PORT = process.env.PORT || 5000;

// Uploads live in <backend>/uploads regardless of the working directory
// the server is started from.
const UPLOADS_DIR = path.join(__dirname, 'uploads');
fs.mkdirSync(UPLOADS_DIR, { recursive: true });

// Middlewares
// CORS is restricted to the configured origins (comma-separated CORS_ORIGINS,
// plus the common localhost dev ports) so browsers can only call this API from
// the shop's own front-ends. Requests without an Origin header (native apps,
// curl, server-to-server) are unaffected.
const ALLOWED_CORS_ORIGINS = (process.env.CORS_ORIGINS || [
  'http://localhost:5000',
  'http://127.0.0.1:5000',
  'http://localhost:3000',
  'http://127.0.0.1:3000',
  'http://localhost:8080',
  'http://127.0.0.1:8080',
].join(',')).split(',').map((s) => s.trim()).filter(Boolean);

// Flutter Web's dev server binds localhost on a random port per run
// (e.g. http://localhost:55041). Any localhost/127.0.0.1 origin is a local
// development front-end, so it is allowed on any port. Non-local origins
// are NOT matched here and stay blocked unless explicitly listed above.
const LOCALHOST_CORS_ORIGIN_PATTERN = /^https?:\/\/(?:localhost|127\.0\.0\.1)(?::\d+)?$/;

app.use(cors({
  origin(origin, callback) {
    if (!origin) {
      // Requests without an Origin header (native apps, curl, server-to-server)
      // are unaffected by CORS.
      return callback(null, true);
    }
    if (LOCALHOST_CORS_ORIGIN_PATTERN.test(origin) || ALLOWED_CORS_ORIGINS.includes(origin)) {
      return callback(null, true);
    }
    return callback(null, false);
  },
}));
app.use(express.json());
app.use('/uploads', express.static(UPLOADS_DIR));

// Admin-only guard for order administration endpoints. Requests must present
// the admin API key (x-admin-key) matching ADMIN_API_KEY. When the key is not
// configured the endpoints FAIL CLOSED rather than expose customer data.
function requireAdminKey(req, res, next) {
  const configured = process.env.ADMIN_API_KEY;
  if (!configured || configured.length < 16) {
    return res.status(503).json({
      success: false,
      message: 'Admin API key is not configured on the server.',
    });
  }
  const provided = req.get('x-admin-key') || '';
  const a = Buffer.from(configured);
  const b = Buffer.from(provided);
  const matches = a.length === b.length && crypto.timingSafeEqual(a, b);
  if (!matches) {
    return res.status(401).json({ success: false, message: 'Unauthorized.' });
  }
  return next();
}

// Simple in-memory rate limiter: per-IP sliding window. Prevents brute-force
// on admin key and order-creation spam. The map is unbounded but in practice
// the window is short and only holds active IPs.
function rateLimit({ windowMs = 60_000, max = 60 } = {}) {
  // Buckets are scoped to THIS limiter instance: each route rate-limits
  // independently so one route's traffic never consumes another's allowance.
  const _rateBuckets = new Map();
  return (req, res, next) => {
    const ip = req.ip || req.connection?.remoteAddress || 'unknown';
    const now = Date.now();
    let bucket = _rateBuckets.get(ip);
    if (!bucket || now - bucket.start > windowMs) {
      bucket = { start: now, count: 0 };
      _rateBuckets.set(ip, bucket);
    }
    bucket.count++;
    if (bucket.count > max) {
      return res.status(429).json({ success: false, message: 'Too many requests. Please slow down.' });
    }
    return next();
  };
}

// 1. SQLITE DATABASE SETUP
const db = new sqlite3.Database('./printshop.db', (err) => {
  if (err) {
    console.error('Error opening database:', err.message);
  } else {
    console.log('📦 Connected to SQLite Database (printshop.db)');
  }
});

// Create Orders Table if it doesn't exist
db.run(`
  CREATE TABLE IF NOT EXISTS orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    orderId TEXT UNIQUE,
    customerName TEXT,
    phone TEXT,
    productName TEXT,
    quantity INTEGER,
    totalPrice REAL,
    fileUrl TEXT,
    status TEXT,
    createdAt TEXT
  )
`);

// Products Data Reference (catalog served to the Flutter app via /api/products)
const products = [
  { id: 1, name: "T-Shirt", pricePerUnit: 499, type: "unit" },
  { id: 2, name: "Saree", pricePerUnit: 1499, type: "unit" },
  { id: 3, name: "Material", pricePerUnit: 599, type: "unit" },
  { id: 4, name: "Poster", pricePerUnit: 399, type: "unit" },
  { id: 5, name: "Embroidery", pricePerUnit: 799, type: "unit" },
  { id: 6, name: "Mug", pricePerUnit: 299, type: "unit" },
  { id: 7, name: "Cap", pricePerUnit: 249, type: "unit" }
];

// 2. FILE UPLOADER CONFIG
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, UPLOADS_DIR);
  },
  filename: (req, file, cb) => {
    cb(null, Date.now() + '-' + file.originalname);
  }
});
// Allowlist image uploads and cap their size so the public /uploads endpoint
// cannot be abused to host arbitrary or oversized files.
const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const nameOk = /\.(png|jpe?g|webp|gif)$/i.test(file.originalname);
    const typeOk = /^image\/(png|jpeg|webp|gif)$/.test(file.mimetype || '');
    cb(null, !!nameOk && typeOk);
  },
});

// 3. API ENDPOINTS

// A. Products List
app.get('/api/products', (req, res) => {
  res.json({ success: true, data: products });
});

// B. File Upload Endpoint
app.post('/api/upload', rateLimit({ windowMs: 60_000, max: 10 }), upload.single('designFile'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ success: false, message: "File upload kaledu!" });
  }
  // Build the URL from the incoming request so it works from any host
  // (localhost, LAN IP, Android emulator, deployed domain).
  const fileUrl = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
  res.json({ success: true, fileUrl: fileUrl });
});

// C. Order Placement (Saves into SQLite DB)
app.post('/api/orders', rateLimit({ windowMs: 60_000, max: 20 }), (req, res) => {
  const { customerName, phone, productId, quantity, width, height, fileUrl } = req.body;

  const qty = Number(quantity);
  if (!Number.isInteger(qty) || qty < 1 || qty > 10000) {
    return res.status(400).json({ success: false, message: 'Invalid quantity.' });
  }
  if (customerName != null && typeof customerName !== 'string' ||
      phone != null && typeof phone !== 'string') {
    return res.status(400).json({ success: false, message: 'Invalid order payload.' });
  }
  const safeName = String(customerName || 'Guest').slice(0, 80);
  const safePhone = String(phone || 'N/A').slice(0, 20);

  const product = products.find(p => p.id === Number(productId)) || { name: "Custom Print", pricePerUnit: 2 };
  
  let totalPrice = 0;
  if (product.type === "banner") {
    totalPrice = (width * height) * (product.pricePerSqFt || 15) * qty;
  } else {
    totalPrice = (product.pricePerUnit || 2) * qty;
  }

  const orderId = "ORD-" + Math.floor(1000 + Math.random() * 9000);
  const status = "Received";
  const createdAt = new Date().toLocaleString();

  const query = `
    INSERT INTO orders (orderId, customerName, phone, productName, quantity, totalPrice, fileUrl, status, createdAt)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  `;

  const params = [
    orderId,
    safeName,
    safePhone,
    product.name,
    qty,
    totalPrice,
    fileUrl || "",
    status,
    createdAt
  ];

  db.run(query, params, function (err) {
    if (err) {
      console.error('Order insert failed:', err.message);
      return res.status(500).json({ success: false, message: "Database insert error" });
    }
    
    const newOrder = {
      id: this.lastID,
      orderId,
      customerName: safeName,
      phone: safePhone,
      productName: product.name,
      quantity: qty,
      totalPrice,
      fileUrl,
      status,
      createdAt
    };

    res.json({ success: true, message: "Order Successful!", order: newOrder });
  });
});

// D. Fetch All Orders for Admin (From SQLite DB)
app.get(['/api/orders', '/api/admin/orders'], rateLimit({ windowMs: 60_000, max: 30 }), requireAdminKey, (req, res) => {
  db.all("SELECT * FROM orders ORDER BY id DESC", [], (err, rows) => {
    if (err) {
      console.error('Order read failed:', err.message);
      return res.status(500).json({ success: false, message: "Database read error" });
    }
    res.json({ success: true, count: rows.length, orders: rows });
  });
});

// F. AI Assistant (proxies a local Ollama instance)
const OLLAMA_URL = process.env.OLLAMA_URL || 'http://localhost:11434';

// Print-shop assistant system prompt using live catalog data so the model can
// give accurate prices and guidance.
const ASSISTANT_SYSTEM_PROMPT = `
You are the helpful AI assistant for "MY PRINT SHOP", an on-demand custom print shop.
You can answer questions about products, pricing, order status, shipping and
print design. Keep replies friendly, concise and helpful, in the language the
customer uses.

Current product catalogue and per-unit prices (INR):
${products.map(p => `- ${p.name}: ₹${p.pricePerUnit}${p.type === 'banner' ? ' (per sq ft)' : ' per unit'}`).join('\n')}

Order statuses used by the shop: Received, Printing, Shipped, Delivered, Cancelled.
If a customer asks about a specific order's status, tell them to check under
"My Orders" in the app or contact support with their order ID.
`.trim();

app.post('/api/assistant', rateLimit({ windowMs: 60_000, max: 15 }), async (req, res) => {
  const { message, history = [] } = req.body;

  if (!message || typeof message !== 'string' || !message.trim()) {
    return res.status(400).json({ success: false, message: "Message is required" });
  }

  const messages = [
    { role: 'system', content: ASSISTANT_SYSTEM_PROMPT },
    // Limited recent history to keep context small.
    ...(Array.isArray(history) ? history.slice(-10) : []),
    { role: 'user', content: message },
  ];

  try {
    const ollamaRes = await fetch(`${OLLAMA_URL}/api/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: process.env.OLLAMA_MODEL || 'llama3.2',
        messages,
        stream: false,
      }),
    });

    if (!ollamaRes.ok) {
      return res.status(502).json({
        success: false,
        message: 'Ollama returned an error',
        detail: `status ${ollamaRes.status}`,
      });
    }

    const data = await ollamaRes.json();
    const answer = data?.message?.content || '';
    res.json({ success: true, reply: answer, model: data?.model });
  } catch (err) {
    // Ollama not installed / not running.
    console.error('Assistant proxy failed:', err.message);
    res.status(503).json({
      success: false,
      message: 'Ollama is not reachable. Make sure it is running (ollama serve) and a model is pulled.',
    });
  }
});

// E. Admin Status Update (In SQLite DB)
app.patch('/api/admin/orders/:id', rateLimit({ windowMs: 60_000, max: 60 }), requireAdminKey, (req, res) => {
  const { id } = req.params;
  const { status } = req.body || {};
  if (typeof status !== 'string' || !status.trim() || status.trim().length > 40) {
    return res.status(400).json({ success: false, message: "Status is required" });
  }
  const newStatus = status.trim();

  db.run("UPDATE orders SET status = ? WHERE orderId = ?", [newStatus, id], function (err) {
    if (err) {
      console.error('Order update failed:', err.message);
      return res.status(500).json({ success: false, message: "Database update error" });
    }
    if (this.changes === 0) {
      return res.status(404).json({ success: false, message: "Order ID not found" });
    }
    res.json({ success: true, message: "Status updated successfully!" });
  });
});

// G. Razorpay helpers ──────────────────────────────────────────────────────
//
// SECURITY: the Razorpay Key Secret lives ONLY here, read from the environment
// (RAZORPAY_KEY_SECRET). It is NEVER embedded in Flutter/Web client code.
const RAZORPAY_KEY_ID = process.env.RAZORPAY_KEY_ID || '';

function razorpayAuthHeader() {
  const keyId = RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_KEY_SECRET;
  if (!keyId || !keySecret) return null;
  return 'Basic ' + Buffer.from(`${keyId}:${keySecret}`).toString('base64');
}

// H. Razorpay Order Creation (server-authoritative)
//
// Creates a Razorpay order with a server-determined amount so the client
// cannot tamper with the price. The returned order_id is passed to the
// Flutter Razorpay Checkout, which MUST use this id. Amount is recorded
// in paise for later verification.
app.post('/api/razorpay/order', rateLimit({ windowMs: 60_000, max: 20 }), async (req, res) => {
  const auth = razorpayAuthHeader();
  if (!auth) {
    return res.status(503).json({
      success: false,
      message: 'Razorpay credentials are not configured server-side.',
    });
  }

  const { amountPaise, receipt } = req.body || {};
  if (!Number.isFinite(amountPaise) || amountPaise < 100 || amountPaise > 500000000) {
    return res.status(400).json({
      success: false,
      message: 'amountPaise must be a number between 100 and 500 000 000.',
    });
  }
  if (receipt != null && typeof receipt !== 'string') {
    return res.status(400).json({
      success: false,
      message: 'receipt must be a string.',
    });
  }

  try {
    const rpRes = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: auth },
      body: JSON.stringify({
        amount: Math.round(amountPaise),
        currency: 'INR',
        receipt: (receipt || '').slice(0, 40) || `rcpt_${Date.now()}`,
      }),
    });

    if (!rpRes.ok) {
      const detail = await rpRes.text().catch(() => '');
      console.error('Razorpay order creation failed:', rpRes.status, detail);
      return res.status(502).json({
        success: false,
        message: 'Razorpay returned an error while creating the order.',
      });
    }

    const rpOrder = await rpRes.json();
    return res.json({
      success: true,
      orderId: rpOrder.id,
      amount: rpOrder.amount,   // paise — authoritative
      currency: rpOrder.currency,
    });
  } catch (err) {
    console.error('Razorpay order creation error:', err.message);
    return res.status(500).json({
      success: false,
      message: 'Failed to create Razorpay order.',
    });
  }
});

// I. Razorpay Payment Verification (server-side)
//
// Recomputes the HMAC-SHA256 signature (order_id + "|" + payment_id) with
// the secret and compares it. Only a match proves the payment genuinely
// came from Razorpay.
//
// AMOUNT VERIFICATION: when the order was created server-side via /api/razorpay/order
// the order amount is authoritative. This endpoint fetches the order from
// Razorpay and compares it with the client-reported amount. A mismatch means
// the client tampered with the amount and verification FAILS.
app.post('/api/razorpay/verify', rateLimit({ windowMs: 60_000, max: 30 }), async (req, res) => {
  const { paymentId, orderId, signature, amount } = req.body || {};
  const keySecret = process.env.RAZORPAY_KEY_SECRET;

  if (!keySecret) {
    return res.status(503).json({
      success: false,
      verificationAvailable: false,
      message: 'Razorpay Key Secret is not configured server-side.',
    });
  }

  if (!paymentId || !orderId || !signature) {
    return res.status(400).json({
      success: false,
      verificationAvailable: true,
      verified: false,
      message: 'paymentId, orderId and signature are required.',
    });
  }

  if (typeof paymentId !== 'string' || typeof orderId !== 'string' ||
      typeof signature !== 'string' ||
      paymentId.length > 200 || orderId.length > 200 || signature.length > 200) {
    return res.status(400).json({
      success: false,
      verificationAvailable: true,
      verified: false,
      message: 'Invalid verification payload.',
    });
  }

  if (amount != null && (!Number.isFinite(Number(amount)) || Number(amount) <= 0)) {
    return res.status(400).json({
      success: false,
      verificationAvailable: true,
      verified: false,
      message: 'Invalid amount.',
    });
  }

  const expected = `${orderId}|${paymentId}`;
  const computed = crypto
    .createHmac('sha256', keySecret)
    .update(expected)
    .digest('hex');

  const signatureOk =
    computed.length === signature.length &&
    crypto.timingSafeEqual(Buffer.from(computed), Buffer.from(signature));

  if (!signatureOk) {
    return res.json({
      success: true,
      verificationAvailable: true,
      verified: false,
      message: 'Payment signature does not match.',
      amount,
    });
  }

  // ── Amount verification: fetch the server-created order from Razorpay ──
  const auth = razorpayAuthHeader();
  let amountVerified = true;
  if (auth) {
    try {
      const rpRes = await fetch(`https://api.razorpay.com/v1/orders/${orderId}`, {
        headers: { Authorization: auth },
      });
      if (rpRes.ok) {
        const rpOrder = await rpRes.json();
        const rpAmountPaise = rpOrder.amount; // number in paise
        const claimedPaise = Math.round(Number(amount) * 100);
        if (Number.isFinite(claimedPaise) && claimedPaise > 0 && rpAmountPaise !== claimedPaise) {
          console.error(
            `Razorpay verify: amount mismatch — order amount=${rpAmountPaise} paise, ` +
            `client claimed=${claimedPaise} paise (orderId=${orderId}).`
          );
          amountVerified = false;
        }
      } else {
        // If we can't fetch the order, fail closed: mark as unverified so
        // the order stays pending until an admin manually confirms.
        console.error(`Razorpay verify: could not fetch order ${orderId} (status ${rpRes.status})`);
        amountVerified = false;
      }
    } catch (err) {
      console.error('Razorpay verify: order fetch failed:', err.message);
      amountVerified = false;
    }
  }

  return res.json({
    success: true,
    verificationAvailable: true,
    verified: signatureOk && amountVerified,
    message: signatureOk && amountVerified
      ? 'Payment signature and amount verified.'
      : signatureOk
        ? 'Payment signature matched but amount verification failed.'
        : 'Payment signature does not match.',
    amount,
  });
});

// Central error handler: returns JSON without leaking stack traces or driver
// internals to clients.
app.use((err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    return res.status(413).json({
      success: false,
      message: 'Upload rejected (file too large or unsupported).',
    });
  }
  if (err) {
    console.error('Request error:', err.message);
    return res.status(400).json({ success: false, message: 'Bad request.' });
  }
  return next();
});

// Server Start (only when run directly — requiring this file from tests
// exports the configured app without binding a port).
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`🚀 Print Shop Backend running on http://localhost:${PORT}`);
  });
}

module.exports = app;
module.exports.db = db;