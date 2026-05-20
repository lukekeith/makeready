# Add Variants Command

Add or modify CVA variants in an existing component with automatic Storybook story generation.

## Usage

```
/variants <component> <variants> [options]
```

## Arguments

- `<component>` - Component name or path
  - Examples: "Button", "avatar", "ui/components/primitive/button"
  - Searches for component automatically

- `<variants>` - Variants to add (JSON format)
  - Format: `{"variantName": ["Value1", "Value2", "Value3"]}`
  - Can specify multiple variant groups

## Options

- `--merge` - Merge with existing variants (default)
- `--replace` - Replace all existing variants
- `--defaults` - Set default variants `{"size": "Medium"}`
- `--compound` - Add compound variants (advanced)
- `--stories` - Auto-generate stories for new variants
- `--styles` - Generate SCSS for new variants

## Examples

### Add Simple Variants
```
/variants button '{"size": ["Small", "Medium", "Large"]}'
```
Adds size variants to Button component.

### Add Multiple Variant Groups
```
/variants avatar '{"size": ["Small", "Medium", "Large"], "status": ["Online", "Offline", "Away"]}'
```
Adds both size and status variants to Avatar.

### Replace Existing Variants
```
/variants button '{"mode": ["Primary", "Secondary", "Tertiary"]}' --replace
```
Replaces all existing variants with new mode variants.

### With Defaults
```
/variants dropdown '{"size": ["Small", "Medium", "Large"]}' --defaults '{"size": "Medium"}'
```
Adds variants and sets Medium as default.

### With Stories and Styles
```
/variants badge '{"variant": ["Success", "Warning", "Error"], "size": ["Small", "Large"]}' --stories --styles
```
Adds variants, generates stories showing all combinations, and creates SCSS classes.

### Compound Variants
```
/variants button '{"size": ["Small"], "mode": ["Primary"]}' --compound '[{"size": "Small", "mode": "Primary", "className": "Button--small-primary"}]'
```
Adds compound variant for specific size+mode combination.

## What Gets Modified

### 1. Component CVA Definition
Updates the CVA configuration:

**Before:**
```typescript
export const ButtonCva = cva("Button", {
  variants: {
    mode: {
      Primary: "Button--primary",
    },
  },
  defaultVariants: { mode: "Primary" },
});
```

**After:**
```typescript
export const ButtonCva = cva("Button", {
  variants: {
    mode: {
      Primary: "Button--primary",
    },
    size: {
      Small: "Button--small",
      Medium: "Button--medium",
      Large: "Button--large",
    },
  },
  defaultVariants: {
    mode: "Primary",
    size: "Medium",
  },
});
```

### 2. Component Props Interface
Automatically extends VariantProps (no changes needed - it's already typed).

### 3. Component Implementation
Updates destructuring and usage:

```typescript
export const Button = observer(
  React.forwardRef<HTMLButtonElement, IButton>((props, ref) => {
    const {
      mode = ButtonCva.defaults?.mode,
      size = ButtonCva.defaults?.size,  // Added
      // ... other props
    } = props;

    return (
      <button
        className={classnames(
          ButtonCva.variants({ mode, size }),  // Updated
          className
        )}
        {...containerProps}
      >
        {children}
      </button>
    );
  })
);
```

### 4. SCSS Styles (if --styles)
Generates variant classes:

```scss
.Button {
  // existing styles

  &--small {
    padding: 4px 8px;
    font-size: 12px;
  }

  &--medium {
    padding: 8px 16px;
    font-size: 14px;
  }

  &--large {
    padding: 12px 24px;
    font-size: 16px;
  }
}
```

### 5. Storybook Stories (if --stories)
Adds "All" story showing variant matrix:

```typescript
export const AllSizes: StoryFn = () => (
  <Center column gap={20}>
    <h2>Sizes</h2>
    {Object.values(ButtonCva.size).map(size => (
      <Center key={size} row gap={10}>
        <h3>{size}</h3>
        {Object.values(ButtonCva.mode).map(mode => (
          <Button key={mode} size={size} mode={mode}>
            {mode} {size}
          </Button>
        ))}
      </Center>
    ))}
  </Center>
);

export const Small: StoryFn = Template("Small Button").bind({});
Small.args = { size: ButtonCva.size.Small };

export const Medium: StoryFn = Template("Medium Button").bind({});
Medium.args = { size: ButtonCva.size.Medium };

export const Large: StoryFn = Template("Large Button").bind({});
Large.args = { size: ButtonCva.size.Large };
```

## AI-Enhanced Features

### Smart Class Naming
- Converts variant values to BEM-style class names
- `Primary` → `Component--primary`
- `Large` → `Component--large`
- `PrimaryDestructive` → `Component--primary-destructive`

### Style Generation
With `--styles`, generates appropriate CSS based on variant type:
- **Size variants** → dimensions, padding, font-size
- **Color/mode variants** → background, color, border
- **State variants** → hover, focus, active, disabled
- **Status variants** → indicator colors, icons

### Story Generation
Creates comprehensive stories:
- Individual story per variant value
- Matrix story showing all combinations
- Interactive controls in Storybook
- Accessibility testing for each variant

### Validation
- Checks for naming conflicts
- Validates BEM naming conventions
- Ensures variant values are unique
- Verifies compound variant combinations exist

## Compound Variants

For complex styling based on multiple variants:

```
/variants button --compound '[
  {
    "size": "Small",
    "mode": "Primary",
    "className": "Button--compact-primary"
  },
  {
    "size": "Large",
    "mode": "Destructive",
    "className": "Button--large-destructive"
  }
]'
```

Generates:

```typescript
export const ButtonCva = cva("Button", {
  variants: { /* ... */ },
  compoundVariants: [
    {
      size: "Small",
      mode: "Primary",
      className: "Button--compact-primary",
    },
    {
      size: "Large",
      mode: "Destructive",
      className: "Button--large-destructive",
    },
  ],
  defaultVariants: { /* ... */ },
});
```

## Best Practices

1. **Start with essential variants** - Add only necessary variants
2. **Use semantic names** - "Primary" not "Blue", "Large" not "48px"
3. **Set sensible defaults** - Most common use case
4. **Generate stories** - Always use `--stories` to document variants
5. **Style incrementally** - Add base styles first, then variants
6. **Test combinations** - Verify all variant combinations work together

## Example Workflow

```bash
# 1. Add size variants
/variants button '{"size": ["Small", "Medium", "Large"]}' --defaults '{"size": "Medium"}' --stories --styles

# 2. Review generated code in IDE

# 3. Test in Storybook
npm run storybook

# 4. Refine styles
"Adjust the Button small size to have more compact padding"

# 5. Add more variants if needed
/variants button '{"loading": ["True", "False"]}' --stories
```

## Validation

The command validates:
- ✅ Component exists
- ✅ Variant names are valid identifiers
- ✅ Variant values are unique within group
- ✅ Compound variants reference existing variants
- ✅ Default variants exist in variant definitions

## Post-Modification

After modifying component, the command:
1. ✅ Updates component CVA definition
2. ✅ Updates component implementation if needed
3. ✅ Generates/updates SCSS (if --styles)
4. ✅ Generates/updates stories (if --stories)
5. ✅ Runs TypeScript check
6. ✅ Reports changes made

## Related Commands

- `/component` - Generate new component with variants
- `/refactor-component` - Restructure component architecture
- `/story` - Add stories without modifying variants

## Notes

- Variant names should be descriptive (size, mode, status)
- Variant values should be PascalCase (Small, Primary, Online)
- Generated class names use kebab-case (button--small)
- Always test in Storybook after adding variants
- Keep variant count reasonable (3-5 values per variant)
