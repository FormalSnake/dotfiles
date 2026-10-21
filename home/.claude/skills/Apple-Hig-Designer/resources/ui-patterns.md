# Apple HIG UI Pattern Examples

This document provides complete, production-ready code examples for common UI patterns following Apple Human Interface Guidelines.

---

## Table of Contents

1. [Complete Login Page](#complete-login-page)
2. [Dashboard Layout](#dashboard-layout)
3. [Product Card Grid](#product-card-grid)
4. [Settings Page](#settings-page)
5. [Profile Page](#profile-page)
6. [Search Interface](#search-interface)
7. [Pricing Table](#pricing-table)
8. [Chat Interface](#chat-interface)

---

## Complete Login Page

A fully functional login page with Apple-quality design.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Sign In</title>
  <link rel="stylesheet" href="design-tokens.css">
  <style>
    .auth-container {
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: var(--space-4);
      background: linear-gradient(180deg, var(--bg-primary) 0%, var(--bg-secondary) 100%);
    }

    .auth-card {
      width: 100%;
      max-width: 400px;
      background: var(--bg-tertiary);
      border-radius: var(--radius-2xl);
      padding: var(--space-8);
      box-shadow: var(--shadow-xl);
    }

    .auth-logo {
      width: 64px;
      height: 64px;
      margin: 0 auto var(--space-6);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 32px;
      background: linear-gradient(135deg, var(--system-blue), var(--system-purple));
      border-radius: var(--radius-xl);
      color: white;
    }

    .auth-title {
      font-size: var(--text-title1);
      font-weight: var(--font-weight-bold);
      text-align: center;
      margin-bottom: var(--space-2);
      color: var(--label-primary);
    }

    .auth-subtitle {
      font-size: var(--text-subhead);
      text-align: center;
      color: var(--label-secondary);
      margin-bottom: var(--space-8);
    }

    .form-group {
      margin-bottom: var(--space-4);
    }

    .form-label {
      display: block;
      font-size: var(--text-footnote);
      font-weight: var(--font-weight-semibold);
      color: var(--label-primary);
      margin-bottom: var(--space-2);
    }

    .form-input {
      width: 100%;
      min-height: var(--touch-target-min);
      padding: var(--space-3) var(--space-4);
      font-size: var(--text-body);
      color: var(--label-primary);
      background: var(--bg-secondary);
      border: 1px solid transparent;
      border-radius: var(--radius-md);
      outline: none;
      transition: border-color var(--duration-fast) var(--ease-out),
                  box-shadow var(--duration-fast) var(--ease-out);
    }

    .form-input:focus {
      border-color: var(--system-blue);
      box-shadow: var(--shadow-focus);
    }

    .form-input::placeholder {
      color: var(--label-tertiary);
    }

    .form-options {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: var(--space-6);
    }

    .checkbox-wrapper {
      display: flex;
      align-items: center;
      gap: var(--space-2);
      cursor: pointer;
    }

    .checkbox {
      width: 20px;
      height: 20px;
      border: 2px solid var(--system-gray3);
      border-radius: 6px;
      cursor: pointer;
      transition: all var(--duration-fast) var(--ease-out);
    }

    .checkbox:checked {
      background: var(--system-blue);
      border-color: var(--system-blue);
    }

    .checkbox-label {
      font-size: var(--text-footnote);
      color: var(--label-primary);
    }

    .link {
      font-size: var(--text-footnote);
      color: var(--system-blue);
      text-decoration: none;
    }

    .link:hover {
      text-decoration: underline;
    }

    .btn-primary {
      width: 100%;
      min-height: var(--touch-target-min);
      padding: var(--space-3) var(--space-6);
      font-size: var(--text-body);
      font-weight: var(--font-weight-semibold);
      color: white;
      background: var(--system-blue);
      border: none;
      border-radius: var(--radius-full);
      cursor: pointer;
      transition: opacity var(--duration-fast) var(--ease-out),
                  transform var(--duration-instant) var(--ease-out);
    }

    .btn-primary:hover {
      opacity: 0.9;
    }

    .btn-primary:active {
      transform: scale(0.98);
    }

    .divider {
      display: flex;
      align-items: center;
      margin: var(--space-6) 0;
      color: var(--label-tertiary);
      font-size: var(--text-footnote);
    }

    .divider::before,
    .divider::after {
      content: '';
      flex: 1;
      height: 1px;
      background: var(--separator);
    }

    .divider span {
      padding: 0 var(--space-3);
    }

    .social-buttons {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: var(--space-3);
    }

    .btn-social {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: var(--space-2);
      min-height: var(--touch-target-min);
      font-size: var(--text-subhead);
      font-weight: var(--font-weight-medium);
      color: var(--label-primary);
      background: var(--bg-secondary);
      border: 1px solid var(--separator);
      border-radius: var(--radius-md);
      cursor: pointer;
      transition: background var(--duration-fast) var(--ease-out);
    }

    .btn-social:hover {
      background: var(--system-gray6);
    }

    .auth-footer {
      text-align: center;
      margin-top: var(--space-6);
      font-size: var(--text-footnote);
      color: var(--label-secondary);
    }
  </style>
</head>
<body>
  <div class="auth-container">
    <div class="auth-card">
      <div class="auth-logo">
        <span>􀣺</span>
      </div>

      <h1 class="auth-title">Welcome back</h1>
      <p class="auth-subtitle">Sign in to continue to your account</p>

      <form>
        <div class="form-group">
          <label for="email" class="form-label">Email</label>
          <input
            type="email"
            id="email"
            class="form-input"
            placeholder="Enter your email"
            autocomplete="email"
            required
          >
        </div>

        <div class="form-group">
          <label for="password" class="form-label">Password</label>
          <input
            type="password"
            id="password"
            class="form-input"
            placeholder="Enter your password"
            autocomplete="current-password"
            required
          >
        </div>

        <div class="form-options">
          <label class="checkbox-wrapper">
            <input type="checkbox" class="checkbox" name="remember">
            <span class="checkbox-label">Remember me</span>
          </label>
          <a href="/forgot-password" class="link">Forgot password?</a>
        </div>

        <button type="submit" class="btn-primary">Sign In</button>
      </form>

      <div class="divider">
        <span>or continue with</span>
      </div>

      <div class="social-buttons">
        <button type="button" class="btn-social">
          <span>􀣺</span>
          Apple
        </button>
        <button type="button" class="btn-social">
          <span>G</span>
          Google
        </button>
      </div>

      <p class="auth-footer">
        Don't have an account? <a href="/signup" class="link">Sign up</a>
      </p>
    </div>
  </div>
</body>
</html>
```

---

## Dashboard Layout

A modern dashboard with sidebar navigation.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Dashboard</title>
  <link rel="stylesheet" href="design-tokens.css">
  <style>
    .dashboard {
      display: flex;
      min-height: 100vh;
    }

    /* Sidebar */
    .sidebar {
      width: 260px;
      background: var(--bg-secondary);
      border-right: 1px solid var(--separator);
      display: flex;
      flex-direction: column;
      padding: var(--space-4);
    }

    .sidebar-logo {
      display: flex;
      align-items: center;
      gap: var(--space-3);
      padding: var(--space-3);
      margin-bottom: var(--space-6);
    }

    .sidebar-logo-icon {
      width: 36px;
      height: 36px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 20px;
      background: linear-gradient(135deg, var(--system-blue), var(--system-indigo));
      border-radius: var(--radius-md);
      color: white;
    }

    .sidebar-logo-text {
      font-size: var(--text-headline);
      font-weight: var(--font-weight-semibold);
      color: var(--label-primary);
    }

    .sidebar-nav {
      flex: 1;
    }

    .nav-section {
      margin-bottom: var(--space-6);
    }

    .nav-section-title {
      font-size: var(--text-caption1);
      font-weight: var(--font-weight-semibold);
      color: var(--label-tertiary);
      text-transform: uppercase;
      letter-spacing: 0.05em;
      padding: 0 var(--space-3);
      margin-bottom: var(--space-2);
    }

    .nav-item {
      display: flex;
      align-items: center;
      gap: var(--space-3);
      padding: var(--space-3);
      font-size: var(--text-subhead);
      color: var(--label-secondary);
      text-decoration: none;
      border-radius: var(--radius-md);
      transition: all var(--duration-fast) var(--ease-out);
      margin-bottom: var(--space-1);
    }

    .nav-item:hover {
      background: var(--fill-tertiary);
      color: var(--label-primary);
    }

    .nav-item.active {
      background: var(--system-blue);
      color: white;
    }

    .nav-item-icon {
      font-size: 18px;
    }

    .sidebar-footer {
      padding: var(--space-3);
      border-top: 1px solid var(--separator);
    }

    .user-profile {
      display: flex;
      align-items: center;
      gap: var(--space-3);
    }

    .user-avatar {
      width: 36px;
      height: 36px;
      border-radius: 50%;
      background: var(--system-gray5);
    }

    .user-info {
      flex: 1;
    }

    .user-name {
      font-size: var(--text-footnote);
      font-weight: var(--font-weight-semibold);
      color: var(--label-primary);
    }

    .user-email {
      font-size: var(--text-caption1);
      color: var(--label-secondary);
    }

    /* Main Content */
    .main-content {
      flex: 1;
      display: flex;
      flex-direction: column;
      background: var(--bg-primary);
    }

    .topbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: var(--space-4) var(--space-6);
      border-bottom: 1px solid var(--separator);
      background: var(--bg-tertiary);
    }

    .topbar-title {
      font-size: var(--text-title2);
      font-weight: var(--font-weight-bold);
      color: var(--label-primary);
    }

    .topbar-actions {
      display: flex;
      align-items: center;
      gap: var(--space-3);
    }

    .search-input {
      width: 280px;
      min-height: 36px;
      padding: var(--space-2) var(--space-4);
      font-size: var(--text-footnote);
      color: var(--label-primary);
      background: var(--bg-secondary);
      border: none;
      border-radius: var(--radius-full);
      outline: none;
    }

    .search-input:focus {
      box-shadow: var(--shadow-focus);
    }

    .icon-button {
      width: 36px;
      height: 36px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 18px;
      color: var(--label-secondary);
      background: transparent;
      border: none;
      border-radius: 50%;
      cursor: pointer;
      transition: background var(--duration-fast) var(--ease-out);
    }

    .icon-button:hover {
      background: var(--fill-secondary);
    }

    .content-area {
      flex: 1;
      padding: var(--space-6);
      overflow-y: auto;
    }

    /* Stats Grid */
    .stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
      gap: var(--space-4);
      margin-bottom: var(--space-6);
    }

    .stat-card {
      background: var(--bg-tertiary);
      border-radius: var(--radius-xl);
      padding: var(--space-5);
    }

    .stat-icon {
      width: 44px;
      height: 44px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 22px;
      border-radius: var(--radius-lg);
      margin-bottom: var(--space-4);
    }

    .stat-value {
      font-size: var(--text-title1);
      font-weight: var(--font-weight-bold);
      color: var(--label-primary);
      margin-bottom: var(--space-1);
    }

    .stat-label {
      font-size: var(--text-footnote);
      color: var(--label-secondary);
    }

    .stat-change {
      display: inline-flex;
      align-items: center;
      gap: var(--space-1);
      font-size: var(--text-caption1);
      font-weight: var(--font-weight-medium);
      margin-top: var(--space-2);
    }

    .stat-change.positive {
      color: var(--system-green);
    }

    .stat-change.negative {
      color: var(--system-red);
    }

    /* Recent Activity */
    .section-title {
      font-size: var(--text-title3);
      font-weight: var(--font-weight-semibold);
      color: var(--label-primary);
      margin-bottom: var(--space-4);
    }

    .activity-list {
      background: var(--bg-tertiary);
      border-radius: var(--radius-xl);
      overflow: hidden;
    }

    .activity-item {
      display: flex;
      align-items: center;
      gap: var(--space-4);
      padding: var(--space-4);
      border-bottom: 1px solid var(--separator);
    }

    .activity-item:last-child {
      border-bottom: none;
    }

    .activity-avatar {
      width: 40px;
      height: 40px;
      border-radius: 50%;
      background: var(--system-gray5);
    }

    .activity-content {
      flex: 1;
    }

    .activity-title {
      font-size: var(--text-subhead);
      color: var(--label-primary);
      margin-bottom: var(--space-1);
    }

    .activity-time {
      font-size: var(--text-caption1);
      color: var(--label-tertiary);
    }
  </style>
</head>
<body>
  <div class="dashboard">
    <!-- Sidebar -->
    <aside class="sidebar">
      <div class="sidebar-logo">
        <div class="sidebar-logo-icon">
          <span>􀣺</span>
        </div>
        <span class="sidebar-logo-text">Dashboard</span>
      </div>

      <nav class="sidebar-nav">
        <div class="nav-section">
          <div class="nav-section-title">Menu</div>
          <a href="#" class="nav-item active">
            <span class="nav-item-icon">􀎟</span>
            Overview
          </a>
          <a href="#" class="nav-item">
            <span class="nav-item-icon">􀐾</span>
            Analytics
          </a>
          <a href="#" class="nav-item">
            <span class="nav-item-icon">􀈕</span>
            Messages
          </a>
          <a href="#" class="nav-item">
            <span class="nav-item-icon">􀉩</span>
            Users
          </a>
        </div>

        <div class="nav-section">
          <div class="nav-section-title">Settings</div>
          <a href="#" class="nav-item">
            <span class="nav-item-icon">􀍟</span>
            Preferences
          </a>
          <a href="#" class="nav-item">
            <span class="nav-item-icon">􀌆</span>
            Help
          </a>
        </div>
      </nav>

      <div class="sidebar-footer">
        <div class="user-profile">
          <img src="avatar.jpg" alt="" class="user-avatar">
          <div class="user-info">
            <div class="user-name">John Doe</div>
            <div class="user-email">john@example.com</div>
          </div>
        </div>
      </div>
    </aside>

    <!-- Main Content -->
    <main class="main-content">
      <header class="topbar">
        <h1 class="topbar-title">Overview</h1>
        <div class="topbar-actions">
          <input type="search" class="search-input" placeholder="Search...">
          <button class="icon-button" aria-label="Notifications">
            <span>􀋚</span>
          </button>
          <button class="icon-button" aria-label="Settings">
            <span>􀍟</span>
          </button>
        </div>
      </header>

      <div class="content-area">
        <!-- Stats Grid -->
        <div class="stats-grid">
          <div class="stat-card">
            <div class="stat-icon" style="background: rgba(0, 122, 255, 0.12); color: var(--system-blue);">
              <span>􀆿</span>
            </div>
            <div class="stat-value">$24,560</div>
            <div class="stat-label">Total Revenue</div>
            <div class="stat-change positive">
              <span>↑</span> 12.5% vs last month
            </div>
          </div>

          <div class="stat-card">
            <div class="stat-icon" style="background: rgba(52, 199, 89, 0.12); color: var(--system-green);">
              <span>􀉩</span>
            </div>
            <div class="stat-value">1,234</div>
            <div class="stat-label">Total Users</div>
            <div class="stat-change positive">
              <span>↑</span> 8.2% vs last month
            </div>
          </div>

          <div class="stat-card">
            <div class="stat-icon" style="background: rgba(255, 149, 0, 0.12); color: var(--system-orange);">
              <span>􀐾</span>
            </div>
            <div class="stat-value">89.2%</div>
            <div class="stat-label">Conversion Rate</div>
            <div class="stat-change negative">
              <span>↓</span> 2.1% vs last month
            </div>
          </div>

          <div class="stat-card">
            <div class="stat-icon" style="background: rgba(175, 82, 222, 0.12); color: var(--system-purple);">
              <span>􀈕</span>
            </div>
            <div class="stat-value">456</div>
            <div class="stat-label">Active Sessions</div>
            <div class="stat-change positive">
              <span>↑</span> 24.7% vs last month
            </div>
          </div>
        </div>

        <!-- Recent Activity -->
        <h2 class="section-title">Recent Activity</h2>
        <div class="activity-list">
          <div class="activity-item">
            <img src="avatar1.jpg" alt="" class="activity-avatar">
            <div class="activity-content">
              <div class="activity-title">Sarah Johnson completed a purchase</div>
              <div class="activity-time">2 minutes ago</div>
            </div>
          </div>
          <div class="activity-item">
            <img src="avatar2.jpg" alt="" class="activity-avatar">
            <div class="activity-content">
              <div class="activity-title">Mike Chen signed up for a new account</div>
              <div class="activity-time">15 minutes ago</div>
            </div>
          </div>
          <div class="activity-item">
            <img src="avatar3.jpg" alt="" class="activity-avatar">
            <div class="activity-content">
              <div class="activity-title">Emily Davis updated their profile</div>
              <div class="activity-time">1 hour ago</div>
            </div>
          </div>
        </div>
      </div>
    </main>
  </div>
</body>
</html>
```

---

## Product Card Grid

E-commerce style product cards with hover effects.

```html
<div class="products-section">
  <header class="section-header">
    <h2 class="section-title">Featured Products</h2>
    <a href="/products" class="view-all">View All →</a>
  </header>

  <div class="products-grid">
    <article class="product-card">
      <div class="product-image">
        <img src="product1.jpg" alt="Product Name">
        <button class="wishlist-btn" aria-label="Add to wishlist">
          <span>􀊵</span>
        </button>
      </div>
      <div class="product-info">
        <span class="product-category">Electronics</span>
        <h3 class="product-name">Wireless Headphones Pro</h3>
        <div class="product-rating">
          <span class="stars">★★★★★</span>
          <span class="rating-count">(128)</span>
        </div>
        <div class="product-footer">
          <span class="product-price">$299.00</span>
          <button class="add-to-cart">Add to Cart</button>
        </div>
      </div>
    </article>

    <!-- More product cards... -->
  </div>
</div>

<style>
.products-section {
  padding: var(--space-8) var(--space-4);
  max-width: 1200px;
  margin: 0 auto;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: var(--space-6);
}

.section-title {
  font-size: var(--text-title2);
  font-weight: var(--font-weight-bold);
  color: var(--label-primary);
}

.view-all {
  font-size: var(--text-subhead);
  color: var(--system-blue);
  text-decoration: none;
}

.view-all:hover {
  text-decoration: underline;
}

.products-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: var(--space-4);
}

.product-card {
  background: var(--bg-tertiary);
  border-radius: var(--radius-xl);
  overflow: hidden;
  transition: transform var(--duration-normal) var(--ease-out),
              box-shadow var(--duration-normal) var(--ease-out);
}

.product-card:hover {
  transform: translateY(-4px);
  box-shadow: var(--shadow-xl);
}

.product-image {
  position: relative;
  aspect-ratio: 1;
  background: var(--bg-secondary);
  overflow: hidden;
}

.product-image img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform var(--duration-slow) var(--ease-out);
}

.product-card:hover .product-image img {
  transform: scale(1.05);
}

.wishlist-btn {
  position: absolute;
  top: var(--space-3);
  right: var(--space-3);
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
  background: rgba(255, 255, 255, 0.9);
  backdrop-filter: blur(10px);
  border: none;
  border-radius: 50%;
  cursor: pointer;
  opacity: 0;
  transition: opacity var(--duration-fast) var(--ease-out);
}

.product-card:hover .wishlist-btn {
  opacity: 1;
}

.wishlist-btn:hover {
  color: var(--system-red);
}

.product-info {
  padding: var(--space-4);
}

.product-category {
  font-size: var(--text-caption1);
  color: var(--system-blue);
  font-weight: var(--font-weight-medium);
}

.product-name {
  font-size: var(--text-body);
  font-weight: var(--font-weight-semibold);
  color: var(--label-primary);
  margin: var(--space-1) 0 var(--space-2);
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.product-rating {
  display: flex;
  align-items: center;
  gap: var(--space-1);
  margin-bottom: var(--space-3);
}

.stars {
  color: var(--system-yellow);
  font-size: var(--text-caption1);
}

.rating-count {
  font-size: var(--text-caption1);
  color: var(--label-tertiary);
}

.product-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.product-price {
  font-size: var(--text-headline);
  font-weight: var(--font-weight-bold);
  color: var(--label-primary);
}

.add-to-cart {
  padding: var(--space-2) var(--space-4);
  font-size: var(--text-footnote);
  font-weight: var(--font-weight-semibold);
  color: white;
  background: var(--system-blue);
  border: none;
  border-radius: var(--radius-full);
  cursor: pointer;
  transition: opacity var(--duration-fast) var(--ease-out);
}

.add-to-cart:hover {
  opacity: 0.9;
}
</style>
```

---

## Pricing Table

Clean pricing comparison cards.

```html
<section class="pricing-section">
  <header class="pricing-header">
    <h2 class="pricing-title">Simple, transparent pricing</h2>
    <p class="pricing-subtitle">Choose the plan that's right for you</p>

    <div class="billing-toggle">
      <span class="billing-option active">Monthly</span>
      <label class="toggle-switch">
        <input type="checkbox" id="billing-toggle">
        <span class="toggle-slider"></span>
      </label>
      <span class="billing-option">Yearly</span>
      <span class="save-badge">Save 20%</span>
    </div>
  </header>

  <div class="pricing-grid">
    <!-- Free Plan -->
    <div class="pricing-card">
      <div class="plan-header">
        <h3 class="plan-name">Free</h3>
        <p class="plan-description">Perfect for getting started</p>
      </div>
      <div class="plan-price">
        <span class="price-amount">$0</span>
        <span class="price-period">/month</span>
      </div>
      <ul class="plan-features">
        <li class="feature-item">
          <span class="feature-icon">✓</span>
          Up to 5 projects
        </li>
        <li class="feature-item">
          <span class="feature-icon">✓</span>
          Basic analytics
        </li>
        <li class="feature-item">
          <span class="feature-icon">✓</span>
          Community support
        </li>
        <li class="feature-item disabled">
          <span class="feature-icon">✕</span>
          Advanced features
        </li>
      </ul>
      <button class="plan-button secondary">Get Started</button>
    </div>

    <!-- Pro Plan (Featured) -->
    <div class="pricing-card featured">
      <div class="featured-badge">Most Popular</div>
      <div class="plan-header">
        <h3 class="plan-name">Pro</h3>
        <p class="plan-description">Best for professionals</p>
      </div>
      <div class="plan-price">
        <span class="price-amount">$29</span>
        <span class="price-period">/month</span>
      </div>
      <ul class="plan-features">
        <li class="feature-item">
          <span class="feature-icon">✓</span>
          Unlimited projects
        </li>
        <li class="feature-item">
          <span class="feature-icon">✓</span>
          Advanced analytics
        </li>
        <li class="feature-item">
          <span class="feature-icon">✓</span>
          Priority support
        </li>
        <li class="feature-item">
          <span class="feature-icon">✓</span>
          Custom integrations
        </li>
      </ul>
      <button class="plan-button primary">Start Free Trial</button>
    </div>

    <!-- Enterprise Plan -->
    <div class="pricing-card">
      <div class="plan-header">
        <h3 class="plan-name">Enterprise</h3>
        <p class="plan-description">For large organizations</p>
      </div>
      <div class="plan-price">
        <span class="price-amount">$99</span>
        <span class="price-period">/month</span>
      </div>
      <ul class="plan-features">
        <li class="feature-item">
          <span class="feature-icon">✓</span>
          Everything in Pro
        </li>
        <li class="feature-item">
          <span class="feature-icon">✓</span>
          Dedicated support
        </li>
        <li class="feature-item">
          <span class="feature-icon">✓</span>
          SLA guarantee
        </li>
        <li class="feature-item">
          <span class="feature-icon">✓</span>
          Custom contracts
        </li>
      </ul>
      <button class="plan-button secondary">Contact Sales</button>
    </div>
  </div>
</section>

<style>
.pricing-section {
  padding: var(--space-16) var(--space-4);
  max-width: 1100px;
  margin: 0 auto;
}

.pricing-header {
  text-align: center;
  margin-bottom: var(--space-12);
}

.pricing-title {
  font-size: var(--text-display-sm);
  font-weight: var(--font-weight-bold);
  color: var(--label-primary);
  margin-bottom: var(--space-2);
}

.pricing-subtitle {
  font-size: var(--text-title3);
  color: var(--label-secondary);
  margin-bottom: var(--space-6);
}

.billing-toggle {
  display: inline-flex;
  align-items: center;
  gap: var(--space-3);
  padding: var(--space-2) var(--space-4);
  background: var(--bg-secondary);
  border-radius: var(--radius-full);
}

.billing-option {
  font-size: var(--text-subhead);
  color: var(--label-secondary);
  transition: color var(--duration-fast) var(--ease-out);
}

.billing-option.active {
  color: var(--label-primary);
  font-weight: var(--font-weight-semibold);
}

.toggle-switch {
  position: relative;
  width: 44px;
  height: 24px;
}

.toggle-switch input {
  opacity: 0;
  width: 0;
  height: 0;
}

.toggle-slider {
  position: absolute;
  inset: 0;
  background: var(--system-gray4);
  border-radius: 24px;
  cursor: pointer;
  transition: background var(--duration-fast) var(--ease-out);
}

.toggle-slider::before {
  content: '';
  position: absolute;
  width: 20px;
  height: 20px;
  left: 2px;
  top: 2px;
  background: white;
  border-radius: 50%;
  transition: transform var(--duration-fast) var(--ease-out);
}

.toggle-switch input:checked + .toggle-slider {
  background: var(--system-green);
}

.toggle-switch input:checked + .toggle-slider::before {
  transform: translateX(20px);
}

.save-badge {
  font-size: var(--text-caption1);
  font-weight: var(--font-weight-semibold);
  color: var(--system-green);
  background: rgba(52, 199, 89, 0.12);
  padding: var(--space-1) var(--space-2);
  border-radius: var(--radius-sm);
}

.pricing-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: var(--space-4);
  align-items: start;
}

.pricing-card {
  position: relative;
  background: var(--bg-tertiary);
  border-radius: var(--radius-2xl);
  padding: var(--space-8);
  border: 1px solid var(--separator);
}

.pricing-card.featured {
  border-color: var(--system-blue);
  box-shadow: 0 0 0 1px var(--system-blue);
}

.featured-badge {
  position: absolute;
  top: 0;
  left: 50%;
  transform: translate(-50%, -50%);
  font-size: var(--text-caption1);
  font-weight: var(--font-weight-semibold);
  color: white;
  background: var(--system-blue);
  padding: var(--space-1) var(--space-3);
  border-radius: var(--radius-full);
}

.plan-header {
  margin-bottom: var(--space-4);
}

.plan-name {
  font-size: var(--text-title2);
  font-weight: var(--font-weight-bold);
  color: var(--label-primary);
  margin-bottom: var(--space-1);
}

.plan-description {
  font-size: var(--text-subhead);
  color: var(--label-secondary);
}

.plan-price {
  margin-bottom: var(--space-6);
}

.price-amount {
  font-size: 48px;
  font-weight: var(--font-weight-bold);
  color: var(--label-primary);
}

.price-period {
  font-size: var(--text-body);
  color: var(--label-secondary);
}

.plan-features {
  list-style: none;
  margin-bottom: var(--space-8);
}

.feature-item {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  font-size: var(--text-subhead);
  color: var(--label-primary);
  padding: var(--space-2) 0;
}

.feature-item.disabled {
  color: var(--label-tertiary);
}

.feature-icon {
  width: 20px;
  font-weight: var(--font-weight-bold);
  color: var(--system-green);
}

.feature-item.disabled .feature-icon {
  color: var(--label-tertiary);
}

.plan-button {
  width: 100%;
  min-height: var(--touch-target-min);
  font-size: var(--text-body);
  font-weight: var(--font-weight-semibold);
  border: none;
  border-radius: var(--radius-full);
  cursor: pointer;
  transition: all var(--duration-fast) var(--ease-out);
}

.plan-button.primary {
  color: white;
  background: var(--system-blue);
}

.plan-button.primary:hover {
  opacity: 0.9;
}

.plan-button.secondary {
  color: var(--system-blue);
  background: rgba(0, 122, 255, 0.1);
}

.plan-button.secondary:hover {
  background: rgba(0, 122, 255, 0.15);
}
</style>
```

---

*These examples demonstrate Apple-quality UI patterns. Combine and customize them to create cohesive, professional interfaces.*
