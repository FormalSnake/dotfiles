# Apple HIG Design Reference Guide

This document provides comprehensive design patterns, real-world examples, and detailed specifications for creating Apple-quality interfaces.

---

## Table of Contents

1. [Page Layout Patterns](#page-layout-patterns)
2. [Navigation Patterns](#navigation-patterns)
3. [Form Design Patterns](#form-design-patterns)
4. [Data Display Patterns](#data-display-patterns)
5. [Modal & Dialog Patterns](#modal--dialog-patterns)
6. [Empty States & Error Handling](#empty-states--error-handling)
7. [Loading States](#loading-states)
8. [Responsive Design Breakpoints](#responsive-design-breakpoints)
9. [Platform-Specific Adaptations](#platform-specific-adaptations)
10. [Complete Component Examples](#complete-component-examples)

---

## Page Layout Patterns

### Hero Section (Landing Page)

```html
<section class="hero">
  <div class="hero-content">
    <h1 class="hero-title">Welcome to Innovation</h1>
    <p class="hero-subtitle">
      Experience the future of technology with our revolutionary platform.
    </p>
    <div class="hero-actions">
      <button class="btn-primary">Get Started</button>
      <button class="btn-secondary">Learn More</button>
    </div>
  </div>
</section>
```

```css
.hero {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 80vh;
  padding: var(--space-8) var(--space-4);
  text-align: center;
  background: linear-gradient(
    180deg,
    var(--bg-primary) 0%,
    var(--bg-secondary) 100%
  );
}

.hero-content {
  max-width: 680px;
}

.hero-title {
  font-family: var(--font-system);
  font-size: clamp(40px, 8vw, 80px);
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.05;
  color: var(--label-primary);
  margin-bottom: var(--space-4);
}

.hero-subtitle {
  font-size: clamp(17px, 3vw, 24px);
  font-weight: 400;
  line-height: 1.4;
  color: var(--label-secondary);
  margin-bottom: var(--space-6);
}

.hero-actions {
  display: flex;
  gap: var(--space-3);
  justify-content: center;
  flex-wrap: wrap;
}
```

### Content Section with Cards

```html
<section class="content-section">
  <header class="section-header">
    <h2 class="section-title">Features</h2>
    <p class="section-description">Everything you need to succeed.</p>
  </header>
  <div class="card-grid">
    <article class="feature-card">
      <div class="feature-icon">
        <span class="sf-symbol">􀎟</span>
      </div>
      <h3 class="feature-title">Lightning Fast</h3>
      <p class="feature-description">
        Optimized performance that keeps you moving forward.
      </p>
    </article>
    <!-- More cards... -->
  </div>
</section>
```

```css
.content-section {
  padding: var(--space-12) var(--space-4);
  max-width: 1200px;
  margin: 0 auto;
}

.section-header {
  text-align: center;
  margin-bottom: var(--space-8);
}

.section-title {
  font-size: 48px;
  font-weight: 700;
  letter-spacing: -0.01em;
  color: var(--label-primary);
  margin-bottom: var(--space-2);
}

.section-description {
  font-size: 21px;
  color: var(--label-secondary);
}

.card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: var(--space-4);
}

.feature-card {
  background: var(--bg-tertiary);
  border-radius: var(--radius-xl);
  padding: var(--space-6);
  text-align: center;
  transition: transform var(--duration-normal) var(--ease-out),
              box-shadow var(--duration-normal) var(--ease-out);
}

.feature-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.12);
}

.feature-icon {
  width: 56px;
  height: 56px;
  margin: 0 auto var(--space-4);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 28px;
  background: linear-gradient(135deg, var(--system-blue), var(--system-purple));
  border-radius: var(--radius-lg);
  color: white;
}

.feature-title {
  font-size: 21px;
  font-weight: 600;
  color: var(--label-primary);
  margin-bottom: var(--space-2);
}

.feature-description {
  font-size: 15px;
  color: var(--label-secondary);
  line-height: 1.5;
}
```

---

## Navigation Patterns

### Top Navigation Bar

```html
<nav class="navbar" role="navigation" aria-label="Main navigation">
  <div class="navbar-container">
    <a href="/" class="navbar-brand" aria-label="Home">
      <span class="brand-logo">􀣺</span>
      <span class="brand-name">AppName</span>
    </a>

    <ul class="navbar-menu">
      <li><a href="/features" class="nav-link">Features</a></li>
      <li><a href="/pricing" class="nav-link">Pricing</a></li>
      <li><a href="/about" class="nav-link">About</a></li>
    </ul>

    <div class="navbar-actions">
      <button class="btn-text">Sign In</button>
      <button class="btn-primary btn-sm">Get Started</button>
    </div>

    <button class="navbar-toggle" aria-label="Toggle menu" aria-expanded="false">
      <span class="hamburger-line"></span>
      <span class="hamburger-line"></span>
    </button>
  </div>
</nav>
```

```css
.navbar {
  position: sticky;
  top: 0;
  z-index: 100;
  background: rgba(255, 255, 255, 0.72);
  backdrop-filter: blur(20px) saturate(180%);
  -webkit-backdrop-filter: blur(20px) saturate(180%);
  border-bottom: 1px solid var(--separator);
}

@media (prefers-color-scheme: dark) {
  .navbar {
    background: rgba(29, 29, 31, 0.72);
  }
}

.navbar-container {
  display: flex;
  align-items: center;
  justify-content: space-between;
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 var(--space-4);
  height: 52px;
}

.navbar-brand {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  text-decoration: none;
  color: var(--label-primary);
  font-weight: 600;
  font-size: 17px;
}

.brand-logo {
  font-size: 24px;
}

.navbar-menu {
  display: flex;
  list-style: none;
  gap: var(--space-6);
  margin: 0;
  padding: 0;
}

.nav-link {
  font-size: 14px;
  font-weight: 400;
  color: var(--label-primary);
  text-decoration: none;
  padding: var(--space-2) 0;
  transition: color var(--duration-fast) var(--ease-out);
}

.nav-link:hover {
  color: var(--system-blue);
}

.navbar-actions {
  display: flex;
  align-items: center;
  gap: var(--space-3);
}

.btn-text {
  font-size: 14px;
  font-weight: 400;
  color: var(--system-blue);
  background: transparent;
  border: none;
  cursor: pointer;
  padding: var(--space-2) var(--space-3);
}

.btn-sm {
  font-size: 14px;
  padding: 8px 16px;
  min-height: 32px;
}

/* Mobile Navigation Toggle */
.navbar-toggle {
  display: none;
  flex-direction: column;
  justify-content: center;
  gap: 4px;
  width: 44px;
  height: 44px;
  background: transparent;
  border: none;
  cursor: pointer;
}

.hamburger-line {
  width: 20px;
  height: 2px;
  background: var(--label-primary);
  border-radius: 1px;
  transition: transform var(--duration-fast) var(--ease-out);
}

@media (max-width: 768px) {
  .navbar-menu,
  .navbar-actions {
    display: none;
  }

  .navbar-toggle {
    display: flex;
  }
}
```

### Tab Bar (iOS Style)

```html
<nav class="tab-bar" role="tablist" aria-label="Main sections">
  <a href="/" class="tab-item active" role="tab" aria-selected="true">
    <span class="tab-icon">􀎟</span>
    <span class="tab-label">Home</span>
  </a>
  <a href="/search" class="tab-item" role="tab" aria-selected="false">
    <span class="tab-icon">􀊫</span>
    <span class="tab-label">Search</span>
  </a>
  <a href="/library" class="tab-item" role="tab" aria-selected="false">
    <span class="tab-icon">􀤆</span>
    <span class="tab-label">Library</span>
  </a>
  <a href="/profile" class="tab-item" role="tab" aria-selected="false">
    <span class="tab-icon">􀉩</span>
    <span class="tab-label">Profile</span>
  </a>
</nav>
```

```css
.tab-bar {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  display: flex;
  justify-content: space-around;
  background: rgba(255, 255, 255, 0.85);
  backdrop-filter: blur(20px) saturate(180%);
  -webkit-backdrop-filter: blur(20px) saturate(180%);
  border-top: 1px solid var(--separator);
  padding-bottom: env(safe-area-inset-bottom);
  z-index: 100;
}

@media (prefers-color-scheme: dark) {
  .tab-bar {
    background: rgba(29, 29, 31, 0.85);
  }
}

.tab-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-width: 64px;
  min-height: 49px;
  padding: var(--space-1) var(--space-3);
  text-decoration: none;
  color: var(--label-secondary);
  transition: color var(--duration-fast) var(--ease-out);
}

.tab-item.active {
  color: var(--system-blue);
}

.tab-icon {
  font-size: 24px;
  margin-bottom: 2px;
}

.tab-label {
  font-size: 10px;
  font-weight: 500;
}
```

---

## Form Design Patterns

### Login Form

```html
<form class="auth-form" autocomplete="on">
  <header class="form-header">
    <h1 class="form-title">Sign In</h1>
    <p class="form-subtitle">Welcome back! Please enter your details.</p>
  </header>

  <div class="form-group">
    <label for="email" class="form-label">Email</label>
    <input
      type="email"
      id="email"
      class="input-field"
      placeholder="Enter your email"
      autocomplete="email"
      required
    >
  </div>

  <div class="form-group">
    <label for="password" class="form-label">Password</label>
    <div class="input-wrapper">
      <input
        type="password"
        id="password"
        class="input-field"
        placeholder="Enter your password"
        autocomplete="current-password"
        required
      >
      <button type="button" class="input-action" aria-label="Show password">
        <span class="sf-symbol">􀋭</span>
      </button>
    </div>
  </div>

  <div class="form-options">
    <label class="checkbox-label">
      <input type="checkbox" class="checkbox" name="remember">
      <span class="checkbox-custom"></span>
      <span class="checkbox-text">Remember me</span>
    </label>
    <a href="/forgot-password" class="link-text">Forgot password?</a>
  </div>

  <button type="submit" class="btn-primary btn-full">Sign In</button>

  <div class="form-divider">
    <span>or continue with</span>
  </div>

  <div class="social-buttons">
    <button type="button" class="btn-social">
      <span class="social-icon">􀣺</span>
      Apple
    </button>
    <button type="button" class="btn-social">
      <span class="social-icon">G</span>
      Google
    </button>
  </div>

  <p class="form-footer">
    Don't have an account? <a href="/signup" class="link-text">Sign up</a>
  </p>
</form>
```

```css
.auth-form {
  max-width: 400px;
  margin: 0 auto;
  padding: var(--space-8) var(--space-4);
}

.form-header {
  text-align: center;
  margin-bottom: var(--space-8);
}

.form-title {
  font-size: 28px;
  font-weight: 700;
  color: var(--label-primary);
  margin-bottom: var(--space-2);
}

.form-subtitle {
  font-size: 15px;
  color: var(--label-secondary);
}

.form-group {
  margin-bottom: var(--space-4);
}

.form-label {
  display: block;
  font-size: 13px;
  font-weight: 600;
  color: var(--label-primary);
  margin-bottom: var(--space-2);
}

.input-wrapper {
  position: relative;
}

.input-field {
  width: 100%;
  min-height: 44px;
  padding: 12px 16px;
  font-family: var(--font-system);
  font-size: 17px;
  color: var(--label-primary);
  background: var(--bg-secondary);
  border: 1px solid transparent;
  border-radius: var(--radius-md);
  outline: none;
  transition: border-color var(--duration-fast) var(--ease-out),
              box-shadow var(--duration-fast) var(--ease-out);
}

.input-field:focus {
  border-color: var(--system-blue);
  box-shadow: 0 0 0 3px rgba(0, 122, 255, 0.2);
}

.input-field::placeholder {
  color: var(--label-tertiary);
}

.input-action {
  position: absolute;
  right: 8px;
  top: 50%;
  transform: translateY(-50%);
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: transparent;
  border: none;
  color: var(--label-secondary);
  cursor: pointer;
}

.form-options {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: var(--space-6);
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  cursor: pointer;
}

.checkbox {
  position: absolute;
  opacity: 0;
  cursor: pointer;
}

.checkbox-custom {
  width: 20px;
  height: 20px;
  border: 2px solid var(--system-gray3);
  border-radius: 6px;
  transition: all var(--duration-fast) var(--ease-out);
}

.checkbox:checked + .checkbox-custom {
  background: var(--system-blue);
  border-color: var(--system-blue);
}

.checkbox:checked + .checkbox-custom::after {
  content: '✓';
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-size: 12px;
  font-weight: 700;
}

.checkbox-text {
  font-size: 14px;
  color: var(--label-primary);
}

.link-text {
  font-size: 14px;
  color: var(--system-blue);
  text-decoration: none;
}

.link-text:hover {
  text-decoration: underline;
}

.btn-full {
  width: 100%;
}

.form-divider {
  display: flex;
  align-items: center;
  margin: var(--space-6) 0;
  color: var(--label-tertiary);
  font-size: 13px;
}

.form-divider::before,
.form-divider::after {
  content: '';
  flex: 1;
  height: 1px;
  background: var(--separator);
}

.form-divider span {
  padding: 0 var(--space-3);
}

.social-buttons {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--space-3);
  margin-bottom: var(--space-6);
}

.btn-social {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-2);
  min-height: 44px;
  font-family: var(--font-system);
  font-size: 15px;
  font-weight: 500;
  color: var(--label-primary);
  background: var(--bg-tertiary);
  border: 1px solid var(--separator);
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: background var(--duration-fast) var(--ease-out);
}

.btn-social:hover {
  background: var(--bg-secondary);
}

.form-footer {
  text-align: center;
  font-size: 14px;
  color: var(--label-secondary);
}
```

### Settings Form (Grouped Style)

```html
<div class="settings-container">
  <section class="settings-group">
    <h3 class="settings-group-title">Account</h3>
    <div class="settings-card">
      <div class="settings-item">
        <div class="settings-item-content">
          <span class="settings-icon" style="background: var(--system-blue);">􀉩</span>
          <div class="settings-text">
            <span class="settings-label">Profile</span>
            <span class="settings-value">John Doe</span>
          </div>
        </div>
        <span class="settings-chevron">􀆊</span>
      </div>
      <div class="settings-item">
        <div class="settings-item-content">
          <span class="settings-icon" style="background: var(--system-gray);">􀍕</span>
          <div class="settings-text">
            <span class="settings-label">Email</span>
            <span class="settings-value">john@example.com</span>
          </div>
        </div>
        <span class="settings-chevron">􀆊</span>
      </div>
    </div>
  </section>

  <section class="settings-group">
    <h3 class="settings-group-title">Preferences</h3>
    <div class="settings-card">
      <div class="settings-item">
        <div class="settings-item-content">
          <span class="settings-icon" style="background: var(--system-orange);">􀆫</span>
          <span class="settings-label">Notifications</span>
        </div>
        <label class="toggle">
          <input type="checkbox" checked>
          <span class="toggle-slider"></span>
        </label>
      </div>
      <div class="settings-item">
        <div class="settings-item-content">
          <span class="settings-icon" style="background: var(--system-indigo);">􀆹</span>
          <span class="settings-label">Dark Mode</span>
        </div>
        <label class="toggle">
          <input type="checkbox">
          <span class="toggle-slider"></span>
        </label>
      </div>
    </div>
  </section>
</div>
```

```css
.settings-container {
  max-width: 600px;
  margin: 0 auto;
  padding: var(--space-4);
}

.settings-group {
  margin-bottom: var(--space-6);
}

.settings-group-title {
  font-size: 13px;
  font-weight: 400;
  color: var(--label-secondary);
  text-transform: uppercase;
  letter-spacing: 0.02em;
  margin-left: var(--space-4);
  margin-bottom: var(--space-2);
}

.settings-card {
  background: var(--bg-tertiary);
  border-radius: var(--radius-lg);
  overflow: hidden;
}

.settings-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-3) var(--space-4);
  border-bottom: 1px solid var(--separator);
  cursor: pointer;
  transition: background var(--duration-fast) var(--ease-out);
}

.settings-item:last-child {
  border-bottom: none;
}

.settings-item:hover {
  background: var(--bg-secondary);
}

.settings-item-content {
  display: flex;
  align-items: center;
  gap: var(--space-3);
}

.settings-icon {
  width: 28px;
  height: 28px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 16px;
  color: white;
  border-radius: 6px;
}

.settings-text {
  display: flex;
  flex-direction: column;
}

.settings-label {
  font-size: 17px;
  color: var(--label-primary);
}

.settings-value {
  font-size: 13px;
  color: var(--label-secondary);
}

.settings-chevron {
  font-size: 14px;
  color: var(--label-tertiary);
}

/* Toggle Switch */
.toggle {
  position: relative;
  width: 51px;
  height: 31px;
  cursor: pointer;
}

.toggle input {
  opacity: 0;
  width: 0;
  height: 0;
}

.toggle-slider {
  position: absolute;
  inset: 0;
  background: var(--system-gray4);
  border-radius: 31px;
  transition: background var(--duration-fast) var(--ease-out);
}

.toggle-slider::before {
  content: '';
  position: absolute;
  width: 27px;
  height: 27px;
  left: 2px;
  top: 2px;
  background: white;
  border-radius: 50%;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
  transition: transform var(--duration-fast) var(--ease-out);
}

.toggle input:checked + .toggle-slider {
  background: var(--system-green);
}

.toggle input:checked + .toggle-slider::before {
  transform: translateX(20px);
}
```

---

## Data Display Patterns

### List View

```html
<ul class="list-view" role="list">
  <li class="list-item">
    <img src="avatar1.jpg" alt="" class="list-avatar">
    <div class="list-content">
      <span class="list-title">Sarah Johnson</span>
      <span class="list-subtitle">Product Designer</span>
    </div>
    <span class="list-accessory">􀆊</span>
  </li>
  <li class="list-item">
    <img src="avatar2.jpg" alt="" class="list-avatar">
    <div class="list-content">
      <span class="list-title">Mike Chen</span>
      <span class="list-subtitle">Engineer</span>
    </div>
    <span class="list-accessory">􀆊</span>
  </li>
</ul>
```

```css
.list-view {
  list-style: none;
  margin: 0;
  padding: 0;
  background: var(--bg-tertiary);
  border-radius: var(--radius-lg);
  overflow: hidden;
}

.list-item {
  display: flex;
  align-items: center;
  padding: var(--space-3) var(--space-4);
  border-bottom: 1px solid var(--separator);
  cursor: pointer;
  transition: background var(--duration-fast) var(--ease-out);
}

.list-item:last-child {
  border-bottom: none;
}

.list-item:hover {
  background: var(--bg-secondary);
}

.list-item:active {
  background: var(--system-gray5);
}

.list-avatar {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  object-fit: cover;
  margin-right: var(--space-3);
}

.list-content {
  flex: 1;
  min-width: 0;
}

.list-title {
  display: block;
  font-size: 17px;
  font-weight: 400;
  color: var(--label-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.list-subtitle {
  display: block;
  font-size: 14px;
  color: var(--label-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.list-accessory {
  font-size: 14px;
  color: var(--label-tertiary);
  margin-left: var(--space-2);
}
```

### Data Table

```html
<div class="table-container">
  <table class="data-table">
    <thead>
      <tr>
        <th>Name</th>
        <th>Status</th>
        <th>Date</th>
        <th>Amount</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>
          <div class="table-cell-main">
            <img src="avatar.jpg" alt="" class="table-avatar">
            <span>Sarah Johnson</span>
          </div>
        </td>
        <td><span class="badge badge-success">Active</span></td>
        <td>Dec 12, 2024</td>
        <td>$2,400.00</td>
      </tr>
    </tbody>
  </table>
</div>
```

```css
.table-container {
  overflow-x: auto;
  border-radius: var(--radius-lg);
  background: var(--bg-tertiary);
}

.data-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 14px;
}

.data-table th {
  padding: var(--space-3) var(--space-4);
  text-align: left;
  font-weight: 600;
  color: var(--label-secondary);
  background: var(--bg-secondary);
  border-bottom: 1px solid var(--separator);
}

.data-table td {
  padding: var(--space-3) var(--space-4);
  color: var(--label-primary);
  border-bottom: 1px solid var(--separator);
}

.data-table tr:last-child td {
  border-bottom: none;
}

.data-table tr:hover td {
  background: var(--bg-secondary);
}

.table-cell-main {
  display: flex;
  align-items: center;
  gap: var(--space-3);
}

.table-avatar {
  width: 32px;
  height: 32px;
  border-radius: 50%;
}

.badge {
  display: inline-flex;
  align-items: center;
  padding: 4px 10px;
  font-size: 12px;
  font-weight: 500;
  border-radius: var(--radius-full);
}

.badge-success {
  color: var(--system-green);
  background: rgba(52, 199, 89, 0.12);
}

.badge-warning {
  color: var(--system-orange);
  background: rgba(255, 149, 0, 0.12);
}

.badge-error {
  color: var(--system-red);
  background: rgba(255, 59, 48, 0.12);
}
```

---

## Modal & Dialog Patterns

### Alert Dialog

```html
<div class="modal-overlay" role="dialog" aria-modal="true" aria-labelledby="modal-title">
  <div class="modal-content modal-alert">
    <div class="modal-icon modal-icon-warning">
      <span>􀇾</span>
    </div>
    <h2 id="modal-title" class="modal-title">Delete Item?</h2>
    <p class="modal-message">
      This action cannot be undone. Are you sure you want to delete this item?
    </p>
    <div class="modal-actions">
      <button class="btn-secondary">Cancel</button>
      <button class="btn-destructive">Delete</button>
    </div>
  </div>
</div>
```

```css
.modal-overlay {
  position: fixed;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.4);
  backdrop-filter: blur(4px);
  z-index: 1000;
  animation: fadeIn var(--duration-fast) var(--ease-out);
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

.modal-content {
  background: var(--bg-tertiary);
  border-radius: var(--radius-xl);
  padding: var(--space-6);
  max-width: 320px;
  width: 90%;
  text-align: center;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  animation: slideUp var(--duration-normal) var(--ease-spring);
}

@keyframes slideUp {
  from {
    opacity: 0;
    transform: translateY(20px) scale(0.95);
  }
  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}

.modal-icon {
  width: 56px;
  height: 56px;
  margin: 0 auto var(--space-4);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 28px;
  border-radius: 50%;
}

.modal-icon-warning {
  color: var(--system-orange);
  background: rgba(255, 149, 0, 0.12);
}

.modal-icon-error {
  color: var(--system-red);
  background: rgba(255, 59, 48, 0.12);
}

.modal-icon-success {
  color: var(--system-green);
  background: rgba(52, 199, 89, 0.12);
}

.modal-title {
  font-size: 17px;
  font-weight: 600;
  color: var(--label-primary);
  margin-bottom: var(--space-2);
}

.modal-message {
  font-size: 13px;
  color: var(--label-secondary);
  line-height: 1.5;
  margin-bottom: var(--space-6);
}

.modal-actions {
  display: flex;
  gap: var(--space-3);
}

.modal-actions button {
  flex: 1;
}

.btn-destructive {
  min-height: 44px;
  padding: 12px 24px;
  font-family: var(--font-system);
  font-size: 17px;
  font-weight: 600;
  color: white;
  background: var(--system-red);
  border: none;
  border-radius: var(--radius-full);
  cursor: pointer;
}
```

### Bottom Sheet

```html
<div class="sheet-overlay">
  <div class="sheet-container">
    <div class="sheet-handle"></div>
    <div class="sheet-content">
      <h3 class="sheet-title">Share</h3>
      <div class="sheet-grid">
        <button class="sheet-action">
          <span class="sheet-action-icon" style="background: var(--system-green);">􀈂</span>
          <span class="sheet-action-label">Messages</span>
        </button>
        <button class="sheet-action">
          <span class="sheet-action-icon" style="background: var(--system-blue);">􀍕</span>
          <span class="sheet-action-label">Mail</span>
        </button>
        <button class="sheet-action">
          <span class="sheet-action-icon" style="background: #1DA1F2;">􀌫</span>
          <span class="sheet-action-label">Twitter</span>
        </button>
        <button class="sheet-action">
          <span class="sheet-action-icon" style="background: var(--system-gray);">􀈄</span>
          <span class="sheet-action-label">Copy Link</span>
        </button>
      </div>
      <button class="sheet-cancel">Cancel</button>
    </div>
  </div>
</div>
```

```css
.sheet-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.4);
  z-index: 1000;
  display: flex;
  align-items: flex-end;
}

.sheet-container {
  width: 100%;
  background: var(--bg-secondary);
  border-radius: var(--radius-xl) var(--radius-xl) 0 0;
  padding-bottom: env(safe-area-inset-bottom);
  animation: slideUpSheet var(--duration-normal) var(--ease-out);
}

@keyframes slideUpSheet {
  from { transform: translateY(100%); }
  to { transform: translateY(0); }
}

.sheet-handle {
  width: 36px;
  height: 5px;
  background: var(--system-gray4);
  border-radius: 2.5px;
  margin: var(--space-2) auto var(--space-4);
}

.sheet-content {
  padding: 0 var(--space-4) var(--space-4);
}

.sheet-title {
  font-size: 13px;
  font-weight: 600;
  color: var(--label-secondary);
  text-align: center;
  margin-bottom: var(--space-4);
}

.sheet-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: var(--space-4);
  margin-bottom: var(--space-4);
}

.sheet-action {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-2);
  padding: var(--space-2);
  background: transparent;
  border: none;
  cursor: pointer;
}

.sheet-action-icon {
  width: 60px;
  height: 60px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 28px;
  color: white;
  border-radius: var(--radius-lg);
}

.sheet-action-label {
  font-size: 11px;
  color: var(--label-primary);
}

.sheet-cancel {
  width: 100%;
  min-height: 56px;
  font-family: var(--font-system);
  font-size: 17px;
  font-weight: 600;
  color: var(--system-blue);
  background: var(--bg-tertiary);
  border: none;
  border-radius: var(--radius-lg);
  cursor: pointer;
}
```

---

## Empty States & Error Handling

### Empty State

```html
<div class="empty-state">
  <div class="empty-icon">
    <span>􀈕</span>
  </div>
  <h3 class="empty-title">No Messages</h3>
  <p class="empty-description">
    Your inbox is empty. Start a conversation to see messages here.
  </p>
  <button class="btn-primary">Compose Message</button>
</div>
```

```css
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--space-12) var(--space-4);
  text-align: center;
  min-height: 400px;
}

.empty-icon {
  width: 80px;
  height: 80px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 40px;
  color: var(--label-tertiary);
  background: var(--bg-secondary);
  border-radius: 50%;
  margin-bottom: var(--space-4);
}

.empty-title {
  font-size: 21px;
  font-weight: 600;
  color: var(--label-primary);
  margin-bottom: var(--space-2);
}

.empty-description {
  font-size: 15px;
  color: var(--label-secondary);
  max-width: 280px;
  margin-bottom: var(--space-6);
  line-height: 1.5;
}
```

### Error State

```html
<div class="error-state">
  <div class="error-icon">
    <span>􀇾</span>
  </div>
  <h3 class="error-title">Something Went Wrong</h3>
  <p class="error-description">
    We couldn't load this content. Please check your connection and try again.
  </p>
  <button class="btn-secondary">
    <span>􀅈</span>
    Try Again
  </button>
</div>
```

```css
.error-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--space-12) var(--space-4);
  text-align: center;
}

.error-icon {
  width: 80px;
  height: 80px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 40px;
  color: var(--system-red);
  background: rgba(255, 59, 48, 0.12);
  border-radius: 50%;
  margin-bottom: var(--space-4);
}

.error-title {
  font-size: 21px;
  font-weight: 600;
  color: var(--label-primary);
  margin-bottom: var(--space-2);
}

.error-description {
  font-size: 15px;
  color: var(--label-secondary);
  max-width: 280px;
  margin-bottom: var(--space-6);
  line-height: 1.5;
}
```

---

## Loading States

### Skeleton Loading

```html
<div class="skeleton-card">
  <div class="skeleton skeleton-avatar"></div>
  <div class="skeleton-content">
    <div class="skeleton skeleton-title"></div>
    <div class="skeleton skeleton-text"></div>
    <div class="skeleton skeleton-text skeleton-text-short"></div>
  </div>
</div>
```

```css
.skeleton {
  background: linear-gradient(
    90deg,
    var(--system-gray5) 25%,
    var(--system-gray6) 50%,
    var(--system-gray5) 75%
  );
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
  border-radius: var(--radius-sm);
}

@keyframes shimmer {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

.skeleton-card {
  display: flex;
  gap: var(--space-3);
  padding: var(--space-4);
  background: var(--bg-tertiary);
  border-radius: var(--radius-lg);
}

.skeleton-avatar {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  flex-shrink: 0;
}

.skeleton-content {
  flex: 1;
}

.skeleton-title {
  height: 20px;
  width: 60%;
  margin-bottom: var(--space-2);
}

.skeleton-text {
  height: 14px;
  width: 100%;
  margin-bottom: var(--space-1);
}

.skeleton-text-short {
  width: 40%;
}
```

### Spinner

```html
<div class="spinner-container">
  <div class="spinner"></div>
  <span class="spinner-text">Loading...</span>
</div>
```

```css
.spinner-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--space-8);
  gap: var(--space-3);
}

.spinner {
  width: 32px;
  height: 32px;
  border: 3px solid var(--system-gray5);
  border-top-color: var(--system-blue);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.spinner-text {
  font-size: 15px;
  color: var(--label-secondary);
}
```

---

## Responsive Design Breakpoints

```css
/* Apple-style Breakpoints */
:root {
  /* Compact (iPhone Portrait) */
  --breakpoint-compact: 430px;

  /* Regular (iPhone Landscape, iPad) */
  --breakpoint-regular: 744px;

  /* Large (iPad Landscape, Desktop) */
  --breakpoint-large: 1024px;

  /* Extra Large (Large Displays) */
  --breakpoint-xl: 1280px;
}

/* Mobile First Approach */

/* Base: iPhone Portrait (compact) */
.container {
  padding: var(--space-4);
  max-width: 100%;
}

/* iPhone Landscape / iPad Portrait */
@media (min-width: 744px) {
  .container {
    padding: var(--space-6);
    max-width: 720px;
    margin: 0 auto;
  }
}

/* iPad Landscape / Desktop */
@media (min-width: 1024px) {
  .container {
    padding: var(--space-8);
    max-width: 980px;
  }
}

/* Large Displays */
@media (min-width: 1280px) {
  .container {
    max-width: 1200px;
  }
}

/* Dynamic Type Support */
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}

/* High Contrast Mode */
@media (prefers-contrast: high) {
  :root {
    --separator: rgba(0, 0, 0, 0.5);
  }

  .btn-primary {
    border: 2px solid currentColor;
  }
}
```

---

## Platform-Specific Adaptations

### iOS Adaptations

```css
/* Safe Area Insets for iOS */
.app-container {
  padding-top: env(safe-area-inset-top);
  padding-bottom: env(safe-area-inset-bottom);
  padding-left: env(safe-area-inset-left);
  padding-right: env(safe-area-inset-right);
}

/* iOS Scroll Behavior */
.scrollable {
  -webkit-overflow-scrolling: touch;
  overscroll-behavior: contain;
}

/* iOS Tap Highlight */
button, a {
  -webkit-tap-highlight-color: transparent;
}

/* iOS Input Styling */
input, textarea, select {
  -webkit-appearance: none;
  appearance: none;
}
```

### macOS Adaptations

```css
/* macOS Window Controls Spacing */
.titlebar {
  padding-left: 78px; /* Space for traffic lights */
}

/* macOS Sidebar */
.sidebar {
  width: 240px;
  background: var(--bg-secondary);
  border-right: 1px solid var(--separator);
}

/* macOS uses smaller touch targets */
@media (pointer: fine) {
  .btn-primary {
    min-height: 28px;
    padding: 6px 12px;
    font-size: 13px;
  }

  .input-field {
    min-height: 24px;
    padding: 4px 8px;
    font-size: 13px;
  }
}
```

---

## Complete Component Examples

### Profile Card Component

```jsx
/**
 * Profile Card - Apple HIG Compliant
 *
 * Design Decisions:
 * - Uses SF Pro system font for native feel
 * - Circular avatar with subtle shadow
 * - Grouped card style for settings context
 * - Supports Light/Dark mode automatically
 */

const ProfileCard = ({ user }) => {
  return (
    <div className="profile-card">
      <div className="profile-header">
        <img
          src={user.avatar}
          alt={`${user.name}'s avatar`}
          className="profile-avatar"
        />
        <div className="profile-info">
          <h2 className="profile-name">{user.name}</h2>
          <p className="profile-email">{user.email}</p>
        </div>
      </div>

      <div className="profile-stats">
        <div className="stat-item">
          <span className="stat-value">{user.posts}</span>
          <span className="stat-label">Posts</span>
        </div>
        <div className="stat-item">
          <span className="stat-value">{user.followers}</span>
          <span className="stat-label">Followers</span>
        </div>
        <div className="stat-item">
          <span className="stat-value">{user.following}</span>
          <span className="stat-label">Following</span>
        </div>
      </div>

      <button className="btn-primary btn-full">
        Edit Profile
      </button>
    </div>
  );
};
```

```css
.profile-card {
  background: var(--bg-tertiary);
  border-radius: var(--radius-xl);
  padding: var(--space-6);
  max-width: 360px;
}

.profile-header {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  margin-bottom: var(--space-6);
}

.profile-avatar {
  width: 96px;
  height: 96px;
  border-radius: 50%;
  object-fit: cover;
  margin-bottom: var(--space-4);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.profile-name {
  font-size: 22px;
  font-weight: 600;
  color: var(--label-primary);
  margin-bottom: var(--space-1);
}

.profile-email {
  font-size: 15px;
  color: var(--label-secondary);
}

.profile-stats {
  display: flex;
  justify-content: space-around;
  padding: var(--space-4) 0;
  border-top: 1px solid var(--separator);
  border-bottom: 1px solid var(--separator);
  margin-bottom: var(--space-6);
}

.stat-item {
  display: flex;
  flex-direction: column;
  align-items: center;
}

.stat-value {
  font-size: 20px;
  font-weight: 600;
  color: var(--label-primary);
}

.stat-label {
  font-size: 13px;
  color: var(--label-secondary);
}
```

---

*This reference guide provides comprehensive patterns for building Apple-quality interfaces. Always refer to the official Apple Human Interface Guidelines for the most up-to-date specifications.*
