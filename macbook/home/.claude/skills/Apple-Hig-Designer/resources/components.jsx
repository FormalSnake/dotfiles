/**
 * Apple HIG React Component Library
 *
 * A collection of React components following Apple Human Interface Guidelines.
 * Use these components as templates for building Apple-quality interfaces.
 *
 * @requires React 18+
 * @requires CSS Variables from design-tokens.css
 */

import React, { forwardRef, useState, useEffect, useRef } from 'react';

// ============================================================================
// BUTTON COMPONENTS
// ============================================================================

/**
 * Primary Button - Capsule style for main actions
 *
 * @example
 * <Button variant="primary" onClick={handleClick}>Get Started</Button>
 * <Button variant="secondary" size="sm">Learn More</Button>
 * <Button variant="destructive" loading>Deleting...</Button>
 */
export const Button = forwardRef(({
  children,
  variant = 'primary',
  size = 'md',
  loading = false,
  disabled = false,
  fullWidth = false,
  icon,
  iconPosition = 'left',
  className = '',
  ...props
}, ref) => {
  const baseStyles = {
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '8px',
    fontFamily: 'var(--font-system)',
    fontWeight: 600,
    border: 'none',
    borderRadius: 'var(--radius-full)',
    cursor: disabled || loading ? 'not-allowed' : 'pointer',
    opacity: disabled ? 0.5 : 1,
    transition: 'transform 0.1s ease, opacity 0.1s ease, background 0.2s ease',
    width: fullWidth ? '100%' : 'auto',
  };

  const sizeStyles = {
    sm: { minHeight: '32px', padding: '8px 16px', fontSize: '14px' },
    md: { minHeight: '44px', padding: '12px 24px', fontSize: '17px' },
    lg: { minHeight: '56px', padding: '16px 32px', fontSize: '19px' },
  };

  const variantStyles = {
    primary: {
      color: '#FFFFFF',
      background: 'var(--system-blue)',
    },
    secondary: {
      color: 'var(--system-blue)',
      background: 'rgba(0, 122, 255, 0.1)',
    },
    tertiary: {
      color: 'var(--system-blue)',
      background: 'transparent',
    },
    destructive: {
      color: '#FFFFFF',
      background: 'var(--system-red)',
    },
    ghost: {
      color: 'var(--label-primary)',
      background: 'transparent',
    },
  };

  const handleMouseDown = (e) => {
    if (!disabled && !loading) {
      e.currentTarget.style.transform = 'scale(0.98)';
    }
  };

  const handleMouseUp = (e) => {
    e.currentTarget.style.transform = 'scale(1)';
  };

  return (
    <button
      ref={ref}
      disabled={disabled || loading}
      style={{
        ...baseStyles,
        ...sizeStyles[size],
        ...variantStyles[variant],
      }}
      className={`apple-button apple-button--${variant} ${className}`}
      onMouseDown={handleMouseDown}
      onMouseUp={handleMouseUp}
      onMouseLeave={handleMouseUp}
      {...props}
    >
      {loading && <Spinner size="sm" />}
      {icon && iconPosition === 'left' && !loading && <span className="button-icon">{icon}</span>}
      {children}
      {icon && iconPosition === 'right' && <span className="button-icon">{icon}</span>}
    </button>
  );
});

Button.displayName = 'Button';

// ============================================================================
// INPUT COMPONENTS
// ============================================================================

/**
 * Text Input - HIG compliant text field
 *
 * @example
 * <Input
 *   label="Email"
 *   type="email"
 *   placeholder="Enter your email"
 *   error="Invalid email format"
 * />
 */
export const Input = forwardRef(({
  label,
  error,
  helper,
  icon,
  iconPosition = 'left',
  fullWidth = true,
  className = '',
  ...props
}, ref) => {
  const [isFocused, setIsFocused] = useState(false);

  const containerStyles = {
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
    width: fullWidth ? '100%' : 'auto',
  };

  const labelStyles = {
    fontSize: '13px',
    fontWeight: 600,
    color: 'var(--label-primary)',
    fontFamily: 'var(--font-system)',
  };

  const inputWrapperStyles = {
    position: 'relative',
    display: 'flex',
    alignItems: 'center',
  };

  const inputStyles = {
    width: '100%',
    minHeight: '44px',
    padding: icon ? (iconPosition === 'left' ? '12px 16px 12px 44px' : '12px 44px 12px 16px') : '12px 16px',
    fontFamily: 'var(--font-system)',
    fontSize: '17px',
    color: 'var(--label-primary)',
    background: 'var(--bg-secondary)',
    border: `1px solid ${error ? 'var(--system-red)' : isFocused ? 'var(--system-blue)' : 'transparent'}`,
    borderRadius: 'var(--radius-md)',
    outline: 'none',
    transition: 'border-color 0.2s ease, box-shadow 0.2s ease',
    boxShadow: isFocused ? '0 0 0 3px rgba(0, 122, 255, 0.2)' : 'none',
  };

  const iconStyles = {
    position: 'absolute',
    [iconPosition]: '12px',
    color: 'var(--label-tertiary)',
    fontSize: '17px',
    pointerEvents: 'none',
  };

  const helperStyles = {
    fontSize: '13px',
    color: error ? 'var(--system-red)' : 'var(--label-secondary)',
    fontFamily: 'var(--font-system)',
  };

  return (
    <div style={containerStyles} className={className}>
      {label && <label style={labelStyles}>{label}</label>}
      <div style={inputWrapperStyles}>
        {icon && <span style={iconStyles}>{icon}</span>}
        <input
          ref={ref}
          style={inputStyles}
          onFocus={() => setIsFocused(true)}
          onBlur={() => setIsFocused(false)}
          {...props}
        />
      </div>
      {(error || helper) && <span style={helperStyles}>{error || helper}</span>}
    </div>
  );
});

Input.displayName = 'Input';

/**
 * Textarea - Multi-line text input
 */
export const Textarea = forwardRef(({
  label,
  error,
  helper,
  rows = 4,
  className = '',
  ...props
}, ref) => {
  const [isFocused, setIsFocused] = useState(false);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', width: '100%' }} className={className}>
      {label && (
        <label style={{ fontSize: '13px', fontWeight: 600, color: 'var(--label-primary)' }}>
          {label}
        </label>
      )}
      <textarea
        ref={ref}
        rows={rows}
        style={{
          width: '100%',
          padding: '12px 16px',
          fontFamily: 'var(--font-system)',
          fontSize: '17px',
          color: 'var(--label-primary)',
          background: 'var(--bg-secondary)',
          border: `1px solid ${error ? 'var(--system-red)' : isFocused ? 'var(--system-blue)' : 'transparent'}`,
          borderRadius: 'var(--radius-md)',
          outline: 'none',
          resize: 'vertical',
          transition: 'border-color 0.2s ease, box-shadow 0.2s ease',
          boxShadow: isFocused ? '0 0 0 3px rgba(0, 122, 255, 0.2)' : 'none',
        }}
        onFocus={() => setIsFocused(true)}
        onBlur={() => setIsFocused(false)}
        {...props}
      />
      {(error || helper) && (
        <span style={{ fontSize: '13px', color: error ? 'var(--system-red)' : 'var(--label-secondary)' }}>
          {error || helper}
        </span>
      )}
    </div>
  );
});

Textarea.displayName = 'Textarea';

// ============================================================================
// TOGGLE / SWITCH COMPONENT
// ============================================================================

/**
 * Toggle Switch - iOS style toggle
 *
 * @example
 * <Toggle checked={isEnabled} onChange={setIsEnabled} label="Notifications" />
 */
export const Toggle = ({ checked, onChange, label, disabled = false, className = '' }) => {
  const toggleStyles = {
    position: 'relative',
    width: '51px',
    height: '31px',
    cursor: disabled ? 'not-allowed' : 'pointer',
    opacity: disabled ? 0.5 : 1,
  };

  const sliderStyles = {
    position: 'absolute',
    inset: 0,
    background: checked ? 'var(--system-green)' : 'var(--system-gray4)',
    borderRadius: '31px',
    transition: 'background 0.2s ease',
  };

  const knobStyles = {
    position: 'absolute',
    width: '27px',
    height: '27px',
    left: '2px',
    top: '2px',
    background: 'white',
    borderRadius: '50%',
    boxShadow: '0 2px 4px rgba(0, 0, 0, 0.2)',
    transform: checked ? 'translateX(20px)' : 'translateX(0)',
    transition: 'transform 0.2s ease',
  };

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }} className={className}>
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        disabled={disabled}
        onClick={() => !disabled && onChange(!checked)}
        style={toggleStyles}
      >
        <span style={sliderStyles} />
        <span style={knobStyles} />
      </button>
      {label && <span style={{ fontSize: '17px', color: 'var(--label-primary)' }}>{label}</span>}
    </div>
  );
};

// ============================================================================
// CARD COMPONENTS
// ============================================================================

/**
 * Card - Container with Apple styling
 *
 * @example
 * <Card variant="elevated">
 *   <Card.Header>Title</Card.Header>
 *   <Card.Body>Content here</Card.Body>
 * </Card>
 */
export const Card = ({ children, variant = 'default', padding = 'md', className = '', style = {}, ...props }) => {
  const paddingValues = {
    none: '0',
    sm: 'var(--space-3)',
    md: 'var(--space-4)',
    lg: 'var(--space-6)',
  };

  const variantStyles = {
    default: {
      background: 'var(--bg-tertiary)',
      boxShadow: 'none',
    },
    elevated: {
      background: 'var(--bg-tertiary)',
      boxShadow: '0 1px 3px rgba(0, 0, 0, 0.04), 0 4px 12px rgba(0, 0, 0, 0.04)',
    },
    glass: {
      background: 'rgba(255, 255, 255, 0.7)',
      backdropFilter: 'blur(20px) saturate(180%)',
      WebkitBackdropFilter: 'blur(20px) saturate(180%)',
      border: '1px solid rgba(255, 255, 255, 0.3)',
    },
  };

  return (
    <div
      style={{
        borderRadius: 'var(--radius-xl)',
        padding: paddingValues[padding],
        ...variantStyles[variant],
        ...style,
      }}
      className={`apple-card apple-card--${variant} ${className}`}
      {...props}
    >
      {children}
    </div>
  );
};

Card.Header = ({ children, className = '', ...props }) => (
  <div
    style={{
      fontSize: '17px',
      fontWeight: 600,
      color: 'var(--label-primary)',
      marginBottom: 'var(--space-3)',
    }}
    className={className}
    {...props}
  >
    {children}
  </div>
);

Card.Body = ({ children, className = '', ...props }) => (
  <div
    style={{
      fontSize: '15px',
      color: 'var(--label-secondary)',
      lineHeight: 1.5,
    }}
    className={className}
    {...props}
  >
    {children}
  </div>
);

// ============================================================================
// MODAL COMPONENTS
// ============================================================================

/**
 * Modal - Alert dialog or sheet
 *
 * @example
 * <Modal isOpen={showModal} onClose={() => setShowModal(false)}>
 *   <Modal.Header>Confirm Action</Modal.Header>
 *   <Modal.Body>Are you sure?</Modal.Body>
 *   <Modal.Actions>
 *     <Button variant="secondary">Cancel</Button>
 *     <Button variant="destructive">Delete</Button>
 *   </Modal.Actions>
 * </Modal>
 */
export const Modal = ({ isOpen, onClose, children, variant = 'alert', className = '' }) => {
  const overlayRef = useRef(null);

  useEffect(() => {
    const handleEscape = (e) => {
      if (e.key === 'Escape') onClose();
    };

    if (isOpen) {
      document.addEventListener('keydown', handleEscape);
      document.body.style.overflow = 'hidden';
    }

    return () => {
      document.removeEventListener('keydown', handleEscape);
      document.body.style.overflow = '';
    };
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  const handleOverlayClick = (e) => {
    if (e.target === overlayRef.current) onClose();
  };

  return (
    <div
      ref={overlayRef}
      onClick={handleOverlayClick}
      style={{
        position: 'fixed',
        inset: 0,
        display: 'flex',
        alignItems: variant === 'sheet' ? 'flex-end' : 'center',
        justifyContent: 'center',
        background: 'rgba(0, 0, 0, 0.4)',
        backdropFilter: 'blur(4px)',
        zIndex: 1000,
        animation: 'fadeIn 0.2s ease',
      }}
      role="dialog"
      aria-modal="true"
      className={className}
    >
      <div
        style={{
          background: 'var(--bg-tertiary)',
          borderRadius: variant === 'sheet' ? 'var(--radius-xl) var(--radius-xl) 0 0' : 'var(--radius-xl)',
          padding: 'var(--space-6)',
          maxWidth: variant === 'sheet' ? '100%' : '320px',
          width: variant === 'sheet' ? '100%' : '90%',
          textAlign: 'center',
          boxShadow: '0 20px 60px rgba(0, 0, 0, 0.3)',
          animation: variant === 'sheet' ? 'slideUp 0.3s ease' : 'scaleIn 0.2s ease',
        }}
      >
        {children}
      </div>
    </div>
  );
};

Modal.Header = ({ children, icon, iconVariant = 'default' }) => {
  const iconColors = {
    default: { color: 'var(--system-blue)', bg: 'rgba(0, 122, 255, 0.12)' },
    warning: { color: 'var(--system-orange)', bg: 'rgba(255, 149, 0, 0.12)' },
    error: { color: 'var(--system-red)', bg: 'rgba(255, 59, 48, 0.12)' },
    success: { color: 'var(--system-green)', bg: 'rgba(52, 199, 89, 0.12)' },
  };

  return (
    <>
      {icon && (
        <div
          style={{
            width: '56px',
            height: '56px',
            margin: '0 auto var(--space-4)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: '28px',
            color: iconColors[iconVariant].color,
            background: iconColors[iconVariant].bg,
            borderRadius: '50%',
          }}
        >
          {icon}
        </div>
      )}
      <h2 style={{ fontSize: '17px', fontWeight: 600, color: 'var(--label-primary)', marginBottom: 'var(--space-2)' }}>
        {children}
      </h2>
    </>
  );
};

Modal.Body = ({ children }) => (
  <p style={{ fontSize: '13px', color: 'var(--label-secondary)', lineHeight: 1.5, marginBottom: 'var(--space-6)' }}>
    {children}
  </p>
);

Modal.Actions = ({ children }) => (
  <div style={{ display: 'flex', gap: 'var(--space-3)' }}>
    {React.Children.map(children, (child) =>
      React.cloneElement(child, { style: { ...child.props.style, flex: 1 } })
    )}
  </div>
);

// ============================================================================
// LOADING COMPONENTS
// ============================================================================

/**
 * Spinner - Loading indicator
 */
export const Spinner = ({ size = 'md', color = 'var(--system-blue)' }) => {
  const sizes = { sm: 16, md: 32, lg: 48 };

  return (
    <div
      style={{
        width: sizes[size],
        height: sizes[size],
        border: `3px solid var(--system-gray5)`,
        borderTopColor: color,
        borderRadius: '50%',
        animation: 'spin 0.8s linear infinite',
      }}
      role="status"
      aria-label="Loading"
    />
  );
};

/**
 * Skeleton - Loading placeholder
 */
export const Skeleton = ({ width = '100%', height = '20px', variant = 'text', className = '' }) => {
  const variantStyles = {
    text: { borderRadius: 'var(--radius-sm)' },
    circular: { borderRadius: '50%' },
    rectangular: { borderRadius: 'var(--radius-md)' },
  };

  return (
    <div
      style={{
        width,
        height,
        background: 'linear-gradient(90deg, var(--system-gray5) 25%, var(--system-gray6) 50%, var(--system-gray5) 75%)',
        backgroundSize: '200% 100%',
        animation: 'shimmer 1.5s infinite',
        ...variantStyles[variant],
      }}
      className={className}
    />
  );
};

// ============================================================================
// LIST COMPONENTS
// ============================================================================

/**
 * List - iOS style list view
 */
export const List = ({ children, className = '' }) => (
  <ul
    style={{
      listStyle: 'none',
      margin: 0,
      padding: 0,
      background: 'var(--bg-tertiary)',
      borderRadius: 'var(--radius-lg)',
      overflow: 'hidden',
    }}
    role="list"
    className={className}
  >
    {children}
  </ul>
);

List.Item = ({ children, onClick, accessory, avatar, className = '' }) => (
  <li
    onClick={onClick}
    style={{
      display: 'flex',
      alignItems: 'center',
      padding: 'var(--space-3) var(--space-4)',
      borderBottom: '1px solid var(--separator)',
      cursor: onClick ? 'pointer' : 'default',
      transition: 'background 0.1s ease',
    }}
    className={className}
  >
    {avatar && (
      <img
        src={avatar}
        alt=""
        style={{
          width: '44px',
          height: '44px',
          borderRadius: '50%',
          objectFit: 'cover',
          marginRight: 'var(--space-3)',
        }}
      />
    )}
    <div style={{ flex: 1, minWidth: 0 }}>{children}</div>
    {accessory && <span style={{ color: 'var(--label-tertiary)', marginLeft: 'var(--space-2)' }}>{accessory}</span>}
  </li>
);

// ============================================================================
// BADGE COMPONENT
// ============================================================================

/**
 * Badge - Status indicator
 */
export const Badge = ({ children, variant = 'default', size = 'md' }) => {
  const variantStyles = {
    default: { color: 'var(--label-secondary)', background: 'var(--system-gray6)' },
    success: { color: 'var(--system-green)', background: 'rgba(52, 199, 89, 0.12)' },
    warning: { color: 'var(--system-orange)', background: 'rgba(255, 149, 0, 0.12)' },
    error: { color: 'var(--system-red)', background: 'rgba(255, 59, 48, 0.12)' },
    info: { color: 'var(--system-blue)', background: 'rgba(0, 122, 255, 0.12)' },
  };

  const sizeStyles = {
    sm: { padding: '2px 6px', fontSize: '11px' },
    md: { padding: '4px 10px', fontSize: '12px' },
    lg: { padding: '6px 12px', fontSize: '14px' },
  };

  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        fontWeight: 500,
        borderRadius: 'var(--radius-full)',
        fontFamily: 'var(--font-system)',
        ...variantStyles[variant],
        ...sizeStyles[size],
      }}
    >
      {children}
    </span>
  );
};

// ============================================================================
// AVATAR COMPONENT
// ============================================================================

/**
 * Avatar - User profile image
 */
export const Avatar = ({ src, alt = '', size = 'md', fallback }) => {
  const [error, setError] = useState(false);

  const sizes = {
    sm: 32,
    md: 44,
    lg: 64,
    xl: 96,
  };

  const dimension = sizes[size];

  if (error || !src) {
    return (
      <div
        style={{
          width: dimension,
          height: dimension,
          borderRadius: '50%',
          background: 'var(--system-gray5)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: dimension * 0.4,
          fontWeight: 600,
          color: 'var(--label-secondary)',
        }}
      >
        {fallback || alt.charAt(0).toUpperCase()}
      </div>
    );
  }

  return (
    <img
      src={src}
      alt={alt}
      onError={() => setError(true)}
      style={{
        width: dimension,
        height: dimension,
        borderRadius: '50%',
        objectFit: 'cover',
      }}
    />
  );
};

// ============================================================================
// EMPTY STATE COMPONENT
// ============================================================================

/**
 * EmptyState - Placeholder for empty content
 */
export const EmptyState = ({ icon, title, description, action, className = '' }) => (
  <div
    style={{
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      padding: 'var(--space-12) var(--space-4)',
      textAlign: 'center',
    }}
    className={className}
  >
    {icon && (
      <div
        style={{
          width: '80px',
          height: '80px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: '40px',
          color: 'var(--label-tertiary)',
          background: 'var(--bg-secondary)',
          borderRadius: '50%',
          marginBottom: 'var(--space-4)',
        }}
      >
        {icon}
      </div>
    )}
    <h3 style={{ fontSize: '21px', fontWeight: 600, color: 'var(--label-primary)', marginBottom: 'var(--space-2)' }}>
      {title}
    </h3>
    <p style={{ fontSize: '15px', color: 'var(--label-secondary)', maxWidth: '280px', marginBottom: 'var(--space-6)', lineHeight: 1.5 }}>
      {description}
    </p>
    {action}
  </div>
);

// ============================================================================
// CSS KEYFRAMES (inject into document)
// ============================================================================

const injectGlobalStyles = () => {
  const styleId = 'apple-hig-animations';
  if (document.getElementById(styleId)) return;

  const style = document.createElement('style');
  style.id = styleId;
  style.textContent = `
    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }

    @keyframes scaleIn {
      from { opacity: 0; transform: scale(0.95); }
      to { opacity: 1; transform: scale(1); }
    }

    @keyframes slideUp {
      from { transform: translateY(100%); }
      to { transform: translateY(0); }
    }

    @keyframes spin {
      to { transform: rotate(360deg); }
    }

    @keyframes shimmer {
      0% { background-position: 200% 0; }
      100% { background-position: -200% 0; }
    }
  `;
  document.head.appendChild(style);
};

// Auto-inject animations
if (typeof document !== 'undefined') {
  injectGlobalStyles();
}

// ============================================================================
// EXPORTS
// ============================================================================

export default {
  Button,
  Input,
  Textarea,
  Toggle,
  Card,
  Modal,
  Spinner,
  Skeleton,
  List,
  Badge,
  Avatar,
  EmptyState,
};
