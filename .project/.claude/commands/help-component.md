# Component Generation Helper

Shows available options, categories, and examples for the `/component` command.

## Available Categories

### primitive
**Purpose:** Base UI components with no business logic

**Examples from your project:**
- button - Clickable buttons with modes and sizes
- form-input - Text inputs with validation states
- form-selection - Dropdowns, checkboxes, radio buttons
- icon - SVG icon wrapper
- text-style - Typography components
- modal - Base modal container
- tabs - Tab navigation
- tooltip - Tooltips and popovers
- badge - Status badges
- loading-animation - Spinners and loaders

**When to use:** Creating reusable UI elements

---

### domain
**Purpose:** Business-specific components that compose primitives

**Examples from your project:**
- kpi - Key performance indicator cards
- panel - Data display panels
- sidebar - Navigation sidebars
- header - Page headers

**When to use:** Business logic display components

---

### domain-form
**Purpose:** Complex form workflows with validation

**Examples from your project:**
- login-form - Multi-step login (ID → MFA → Complete)
- create-account-form - Account creation workflow
- payment-form - Payment processing forms

**When to use:** Multi-step forms with business logic

---

### layout
**Purpose:** Page-level templates that compose domain components

**Examples from your project:**
- login-layout - Login page structure
- customer-dashboard-layout - Customer dashboard template
- user-management-layout - Admin user management template

**When to use:** Page templates and structure

---

### table
**Purpose:** Data table variants

**Examples from your project:**
- tax-guardian-codes-table
- user-table
- payment-table

**When to use:** Tabular data display

---

### container
**Purpose:** Container components for layout and grouping

**When to use:** Wrapper components, sections

---

### domain-modal
**Purpose:** Modal variants for specific use cases

**When to use:** Specialized modal dialogs

---

### domain-panel
**Purpose:** Panel components for data display

**When to use:** Data panels, cards, sections

---

## Common Component Patterns

### Avatar Component
```
/component avatar primitive
```

**Typical features:**
- Variants: size (Small, Medium, Large), status (Online, Offline, Away)
- Props: src, alt, initials, onClick
- Logic: Image with fallback to initials, status indicator
- Styles: Circular, status dot in corner

---

### Button Component
```
/component button primitive
```

**Typical features:**
- Variants: mode (Primary, Secondary, Tertiary, Destructive), size (Small, Medium, Large)
- Props: children, onClick, disabled, loading
- Logic: Click handler, disabled state, loading spinner
- Styles: Color modes, hover/focus/active states

---

### Dropdown Component
```
/component dropdown primitive
```

**Typical features:**
- Variants: size (Small, Medium, Large), mode (Single, Multi)
- Props: options, value, onChange, placeholder
- Logic: Option selection, search/filter, keyboard navigation
- Styles: Dropdown menu, selected state, focus styles

---

### Badge Component
```
/component badge primitive
```

**Typical features:**
- Variants: variant (Success, Warning, Error, Info), size (Small, Medium)
- Props: children, icon
- Logic: Display text with icon
- Styles: Color modes, icon positioning

---

### Card Component
```
/component card domain
```

**Typical features:**
- Variants: mode (Default, Elevated, Outlined)
- Props: title, subtitle, children, actions
- Logic: Header, body, footer sections
- Styles: Elevation, borders, padding

---

### Form Component
```
/component user-form domain-form
```

**Typical features:**
- Variants: mode (Create, Edit)
- Props: initialData, onSubmit, isLoading
- Logic: Form validation, multi-step flow, error handling
- Styles: Form layout, input spacing

---

## Variant Naming Conventions

### Size Variants
```json
{"size": ["Small", "Medium", "Large"]}
{"size": ["XSmall", "Small", "Medium", "Large", "XLarge"]}
```

---

### Mode/Type Variants
```json
{"mode": ["Primary", "Secondary", "Tertiary"]}
{"mode": ["Default", "Outlined", "Filled"]}
{"type": ["Button", "Link", "Icon"]}
```

---

### State/Status Variants
```json
{"status": ["Online", "Offline", "Away", "Busy"]}
{"state": ["Active", "Inactive", "Pending"]}
```

---

### Color/Semantic Variants
```json
{"variant": ["Success", "Warning", "Error", "Info"]}
{"color": ["Primary", "Secondary", "Success", "Error"]}
```

---

## Option Flags

### --variants
Add CVA variants to the component.

**Format:** JSON object with variant groups
```bash
--variants '{"size": ["Small", "Medium", "Large"], "mode": ["Primary", "Secondary"]}'
```

---

### --props
Add custom props to the interface.

**Format:** JSON array of prop definitions
```bash
--props '["src: string", "alt: string", "onClick?: () => void"]'
```

---

### --with-logic
Generate complete component implementation with working logic.

**Includes:**
- Event handlers
- State management
- Conditional rendering
- Accessibility attributes

---

### --with-styles
Generate production-ready SCSS styles.

**Includes:**
- Layout styles (flexbox/grid)
- Variant modifier classes
- Hover/focus/active states
- Transitions and animations
- Responsive sizing

---

### --stories
Generate comprehensive Storybook stories.

**Includes:**
- Multiple story variants
- "All" story showing all combinations
- Interactive controls
- Documentation

---

### --skip-barrel
Don't automatically update the barrel export file.

**Use when:**
- You want to manually manage exports
- Testing component in isolation
- Creating temporary component

---

## Quick Reference

| Want to create... | Use this command |
|-------------------|------------------|
| Simple button | `/component button` |
| Avatar with status | `/component avatar primitive --variants '{"status": ["Online", "Offline"]}'` |
| Complete dropdown | `/component dropdown primitive --with-logic --with-styles` |
| User profile card | `/component user-card domain` |
| Login form | `/component login-form domain-form` |
| Dashboard layout | `/component dashboard-layout layout` |
| Custom category | `/component alert notification` |

---

## Best Practices

1. **Start simple** - Use `/component <name>` and let me suggest features
2. **Use semantic names** - "UserAvatar" not "Avatar2"
3. **Right category** - Primitive for base, Domain for business
4. **Minimal variants** - Add 2-3 variants initially, grow as needed
5. **Test in Storybook** - Always verify components in Storybook
6. **Follow patterns** - Look at existing components in category

---

## Need Help?

Just ask! For example:
- "What variants should I add to a Button component?"
- "Show me examples of domain components"
- "How do I create a multi-step form?"
- "What's the difference between primitive and domain?"

I'll analyze your needs and suggest the best approach.
