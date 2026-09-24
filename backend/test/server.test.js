// Smoke + security tests for the Print Shop backend (node:test, no extra deps).
//
// The admin key is set BEFORE the server module is loaded so the admin-guard
// behaviour can be exercised deterministically. Run with `npm test`.
process.env.ADMIN_API_KEY = 'test-admin-key-0123456789abcdef';

const { test, before, after } = require('node:test');
const assert = require('node:assert');

const app = require('../server');
const db = app.db;

let server;
let baseUrl;

before(async () => {
  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  server.closeAllConnections();
  await new Promise((resolve) => server.close(resolve));
  await new Promise((resolve) => db.close(resolve));
});

test('GET /api/products returns the catalogue', async () => {
  const res = await fetch(`${baseUrl}/api/products`);
  assert.strictEqual(res.status, 200);
  const body = await res.json();
  assert.strictEqual(body.success, true);
  assert.ok(Array.isArray(body.data));
  assert.ok(body.data.length > 0);
});

test('admin order list is rejected without the admin key', async () => {
  const res = await fetch(`${baseUrl}/api/admin/orders`);
  assert.strictEqual(res.status, 401);
  const body = await res.json();
  assert.strictEqual(body.success, false);
});

test('admin order list is rejected with a wrong admin key', async () => {
  const res = await fetch(`${baseUrl}/api/admin/orders`, {
    headers: { 'x-admin-key': 'this-is-not-the-admin-key-123' },
  });
  assert.strictEqual(res.status, 401);
  const body = await res.json();
  assert.strictEqual(body.success, false);
});

test('admin order list works with the correct admin key', async () => {
  const res = await fetch(`${baseUrl}/api/admin/orders`, {
    headers: { 'x-admin-key': process.env.ADMIN_API_KEY },
  });
  assert.strictEqual(res.status, 200);
  const body = await res.json();
  assert.strictEqual(body.success, true);
  assert.ok(Array.isArray(body.orders));
});

test('status update is rejected without the admin key', async () => {
  const res = await fetch(`${baseUrl}/api/admin/orders/ORD-0000`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ status: 'Delivered' }),
  });
  assert.strictEqual(res.status, 401);
});

test('status update with an invalid status body is rejected', async () => {
  const res = await fetch(`${baseUrl}/api/admin/orders/ORD-0000`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'x-admin-key': process.env.ADMIN_API_KEY,
    },
    body: JSON.stringify({ status: '' }),
  });
  assert.strictEqual(res.status, 400);
});

test('razorpay verify rejects a payload missing required fields', async () => {
  const res = await fetch(`${baseUrl}/api/razorpay/verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({}),
  });
  // With no key secret configured the server fails closed (503); with one it
  // still rejects missing fields (400). Either way the payment is NOT verified.
  assert.ok(res.status === 400 || res.status === 503);
  const body = await res.json();
  if (res.status === 400) {
    assert.strictEqual(body.verified, false);
  } else {
    assert.strictEqual(body.verificationAvailable, false);
  }
});

// ── Order creation security ────────────────────────────────────────────────

test('POST /api/orders rejects invalid quantity (non-integer)', async () => {
  const res = await fetch(`${baseUrl}/api/orders`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      customerName: 'Test',
      phone: '123',
      productId: 1,
      quantity: 1.5,
    }),
  });
  assert.strictEqual(res.status, 400);
  const body = await res.json();
  assert.strictEqual(body.success, false);
});

test('POST /api/orders rejects zero quantity', async () => {
  const res = await fetch(`${baseUrl}/api/orders`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      customerName: 'Test',
      phone: '123',
      productId: 1,
      quantity: 0,
    }),
  });
  assert.strictEqual(res.status, 400);
});

test('POST /api/orders rejects excessive quantity', async () => {
  const res = await fetch(`${baseUrl}/api/orders`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      customerName: 'Test',
      phone: '123',
      productId: 1,
      quantity: 99999,
    }),
  });
  assert.strictEqual(res.status, 400);
});

test('POST /api/orders truncates oversized customer name', async () => {
  const longName = 'A'.repeat(200);
  const res = await fetch(`${baseUrl}/api/orders`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      customerName: longName,
      phone: '123',
      productId: 1,
      quantity: 1,
    }),
  });
  assert.strictEqual(res.status, 200);
  const body = await res.json();
  assert.ok(body.order);
  assert.ok(body.order.customerName.length <= 80);
});

test('POST /api/orders succeeds with valid payload', async () => {
  const res = await fetch(`${baseUrl}/api/orders`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      customerName: 'Test User',
      phone: '9999999999',
      productId: 1,
      quantity: 2,
    }),
  });
  assert.strictEqual(res.status, 200);
  const body = await res.json();
  assert.strictEqual(body.success, true);
  assert.ok(body.order);
  assert.ok(body.order.orderId.startsWith('ORD-'));
  assert.strictEqual(body.order.quantity, 2);
  assert.strictEqual(body.order.productName, 'T-Shirt');
});

// ── Razorpay verification hardening ────────────────────────────────────────

test('razorpay verify rejects oversized strings', async () => {
  const res = await fetch(`${baseUrl}/api/razorpay/verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      paymentId: 'x'.repeat(201),
      orderId: 'o',
      signature: 's',
    }),
  });
  // 503 = no key secret configured (fail-closed); 400 = validated & rejected.
  assert.ok(res.status === 400 || res.status === 503);
  const body = await res.json();
  if (res.status === 400) {
    assert.strictEqual(body.verified, false);
  }
});

test('razorpay verify rejects non-string types', async () => {
  const res = await fetch(`${baseUrl}/api/razorpay/verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      paymentId: 12345,
      orderId: 'o',
      signature: 's',
    }),
  });
  assert.ok(res.status === 400 || res.status === 503);
});

test('razorpay verify rejects invalid amount', async () => {
  const res = await fetch(`${baseUrl}/api/razorpay/verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      paymentId: 'pay_123',
      orderId: 'ord_456',
      signature: 'sig',
      amount: -100,
    }),
  });
  assert.ok(res.status === 400 || res.status === 503);
  const body = await res.json();
  if (res.status === 400) {
    assert.strictEqual(body.verified, false);
  }
});

test('razorpay verify rejects NaN amount', async () => {
  const res = await fetch(`${baseUrl}/api/razorpay/verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      paymentId: 'pay_123',
      orderId: 'ord_456',
      signature: 'sig',
      amount: 'not-a-number',
    }),
  });
  assert.ok(res.status === 400 || res.status === 503);
});

// ── Assistant endpoint hardening ───────────────────────────────────────────

test('POST /api/assistant rejects empty message', async () => {
  const res = await fetch(`${baseUrl}/api/assistant`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ message: '' }),
  });
  // 400 = validated & rejected; 429 = rate-limited.
  assert.ok(res.status === 400 || res.status === 429);
  const body = await res.json();
  assert.strictEqual(body.success, false);
});

test('POST /api/assistant rejects non-string message', async () => {
  const res = await fetch(`${baseUrl}/api/assistant`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ message: 12345 }),
  });
  assert.ok(res.status === 400 || res.status === 429);
  const body = await res.json();
  assert.strictEqual(body.success, false);
});

test('POST /api/assistant returns 503 when Ollama is not running', async () => {
  const res = await fetch(`${baseUrl}/api/assistant`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ message: 'Hello' }),
  });
  // Ollama is not running in test, so should get 503 or 429 (rate limit).
  const body = await res.json();
  if (res.status === 503) {
    assert.strictEqual(body.success, false);
  } else {
    // Rate limited or other non-200 — still not a verified response.
    assert.ok(res.status >= 400);
  }
});

// ── File upload hardening ──────────────────────────────────────────────────

test('POST /api/upload rejects non-image files', async () => {
  const boundary = '----TestBoundary' + Date.now();
  const bodyParts = [
    `--${boundary}\r\n`,
    'Content-Disposition: form-data; name="designFile"; filename="test.txt"\r\n',
    'Content-Type: text/plain\r\n\r\n',
    'not an image\r\n',
    `--${boundary}--\r\n`,
  ];
  const res = await fetch(`${baseUrl}/api/upload`, {
    method: 'POST',
    headers: { 'Content-Type': `multipart/form-data; boundary=${boundary}` },
    body: bodyParts.join(''),
  });
  // Should NOT succeed — either file-type rejection, auth failure, or config error.
  assert.ok(res.status !== 200, `Upload should reject non-image, got ${res.status}`);
});

// ── Rate limiting ──────────────────────────────────────────────────────────

test('rate limiter does not block normal requests', async () => {
  // A few requests should not be rate-limited.
  for (let i = 0; i < 3; i++) {
    const res = await fetch(`${baseUrl}/api/products`);
    assert.strictEqual(res.status, 200);
  }
});

// ── Error handling ─────────────────────────────────────────────────────────

test('unknown routes return appropriate error', async () => {
  const res = await fetch(`${baseUrl}/api/nonexistent`);
  // Express returns 404 by default for unmatched routes.
  assert.ok(res.status === 404 || res.status === 400);
});



