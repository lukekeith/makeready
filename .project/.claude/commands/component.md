# Component Generation Command

Generate a new React component with CVA variants, Storybook integration, and MobX props store following the project's architecture patterns.

## Quick Start

### Interactive Mode (Default - Recommended)

```
/component <name>
```

**How it works:**
1. You provide just the component name
2. I analyze the name and suggest:
   - Appropriate category
   - Common variants for this type of component
   - Typical props
   - Whether to include logic and styles
3. I present the suggestions and ask for your approval
4. You can say "proceed", "yes", or request changes
5. I generate all files based on final decisions

**Example conversation:**
```
You: /component badge

Me: I'll create a Badge component. Here's what I suggest:

📦 Category: primitive
🎨 Variants:
   • variant: Success, Warning, Error, Info
   • size: Small, Medium
✨ Props: children, icon, onClick
🔧 Logic: Display text with optional icon
💅 Styles: Color variants, icon positioning, rounded corners

Shall I proceed with these? Or would you like to adjust anything?

You: Skip the onClick, otherwise looks good

Me: Perfect! Generating Badge component without onClick...
[creates all 4 files]
```

---

### Direct Mode (For Power Users)

```
/component <name> [category] --variants '{...}' [other options]
```

Provide all arguments upfront to skip confirmation and generate immediately.

## Arguments

- `<name>` - Component name (will be converted to PascalCase)
  - Examples: "avatar", "user avatar", "dropdown-menu"
  - Result: `Avatar`, `UserAvatar`, `DropdownMenu`

- `[category]` - Component category (optional)
  - If not provided, I'll suggest the most appropriate category
  - Options: `primitive`, `domain`, `domain-form`, `layout`, `table`, `container`, `domain-modal`, `domain-panel`
  - Can specify a new category name to create a new category folder

## Options

Use `--` followed by option flags:

- `--variants` - CVA variants to include (JSON format)
- `--props` - Additional props to add to interface
- `--stories` - Generate specific story examples
- `--with-logic` - Include component implementation logic
- `--with-styles` - Generate complete SCSS styles
- `--skip-barrel` - Don't update barrel export file

## Examples

### Interactive Mode (Recommended)
```
/component avatar
```

**Claude responds:**
> I'll create an Avatar component. Based on the name, I suggest:
> - **Category:** primitive
> - **Variants:** size (Small, Medium, Large), status (Online, Offline, Away)
> - **Props:** src, alt, initials
> - **Logic:** Display image with fallback to initials, status indicator
> - **Styles:** Circular avatar with status dot
>
> Proceed with these suggestions? Or would you like to customize?

**You reply:** "Yes, proceed" or "Skip the status variant"

### Direct Mode (Skip Confirmation)
```
/component avatar primitive --variants '{"size": ["Small", "Medium", "Large"]}' --with-logic --with-styles
```
Generates immediately without asking for confirmation.

### Component with Category
```
/component user-card domain
```
Creates a UserCard component in the `domain` category.

### Component with Variants
```
/component button primitive --variants '{"size": ["Small", "Medium", "Large"], "mode": ["Primary", "Secondary", "Tertiary"]}'
```
Creates a Button component with size and mode variants pre-configured.

### Component with Full Implementation
```
/component dropdown primitive --variants '{"size": ["Small", "Medium", "Large"]}' --props '["options: string[]", "value: string", "onChange: (value: string) => void"]' --with-logic --with-styles
```
Creates a fully implemented Dropdown component with:
- Size variants
- Options, value, and onChange props
- Complete component logic
- Full SCSS styles

### New Category
```
/component alert notification
```
Creates an Alert component in a new `notification` category folder.

## Interactive Response Pattern

When you use interactive mode, I will respond with:

```
I'll create a [ComponentName] component. Here's what I suggest:

📦 Category: [suggested-category]
   Reason: [why this category fits]

🎨 Variants:
   • [variantName]: [Value1, Value2, Value3]
   • [variantName2]: [Value1, Value2]
   Reason: [why these variants are common for this component]

✨ Props:
   • [propName]: [type]
   • [propName2]: [type]
   Reason: [why these props are typical]

🔧 Logic: [description of implementation]
💅 Styles: [description of styling approach]

Options:
1. "Proceed" or "Yes" - Generate with these suggestions
2. "Skip [feature]" - Remove specific feature (e.g., "skip the status variant")
3. "Add [feature]" - Add specific feature (e.g., "add loading state")
4. "Change [feature]" - Modify specific feature (e.g., "change category to domain")
5. "Minimal" - Generate basic boilerplate only

What would you like to do?
```

You can respond naturally:
- ✅ "Looks good"
- ✅ "Proceed"
- ✅ "Yes, but skip the onClick prop"
- ✅ "Add a loading variant"
- ✅ "Change category to domain"
- ✅ "Just create the minimal version"

---

## What Gets Generated

After confirmation, I create 4 files following the devops template pattern:

### 1. Component File
`ui/components/{category}/{component-kebab}/{component-kebab}.tsx`

**Includes:**
- CVA variant definitions
- TypeScript interface extending VariantProps
- MobX observer wrapper
- React.forwardRef support
- Component implementation (basic or full logic)

### 2. Styles File
`ui/components/{category}/{component-kebab}/{component-kebab}.scss`

**Includes:**
- Component base class
- Variant modifier classes
- BEM-style nested selectors
- CSS custom property usage

### 3. Storybook Story
`ui/stories/components/{category}/{component-kebab}.stories.tsx`

**Includes:**
- Story metadata with hierarchical title
- CVA auto-generated controls via `cvaOptionsToStorybook()`
- Template pattern
- Basic story export
- "All" story showing all variant combinations (if variants provided)

### 4. Props Store
`ui/stories/data/{category}/{component-kebab}-props.tsx`

**Includes:**
- MobX observable store implementing component interface
- Constructor with makeObservable
- Factory function export
- Builder methods for common scenarios (if --with-logic)

### 5. Barrel Export Update
`ui/components/{category}/index.ts`

**Updates:**
- Adds export statement for new component
- Creates barrel file if category is new
- Maintains alphabetical order

## Template Pattern

The command follows the exact devops template structure:

```typescript
// Component structure
export const {ComponentName}Cva = cva("{ComponentName}", {
  variants: { /* variants here */ },
  defaultVariants: { /* defaults here */ }
});

export interface I{ComponentName} extends VariantProps<typeof {ComponentName}Cva.variants> {
  className?: string;
  containerProps?: React.HTMLProps<HTMLDivElement>;
  // additional props
}

export const {ComponentName} = observer(
  React.forwardRef<HTMLDivElement, I{ComponentName}>((props, ref) => {
    // implementation
  })
);
```

## AI-Enhanced Features

Beyond basic templating, this command can:

### Smart Variant Generation
- Analyze existing components in the same category
- Suggest appropriate variant names and values
- Generate sensible default variants

### Intelligent Props
- Infer common props based on component name
  - Avatar → `src`, `alt`, `initials`
  - Dropdown → `options`, `value`, `onChange`
  - Modal → `isOpen`, `onClose`, `title`

### Complete Implementation
With `--with-logic`, generates working component logic:
- Event handlers
- State management (if needed)
- Conditional rendering
- Accessibility attributes
- Proper ref forwarding

### Comprehensive Styles
With `--with-styles`, generates production-ready SCSS:
- Flexbox/Grid layouts
- Responsive sizing
- Hover/focus/active states
- Transition animations
- CSS custom property integration

### Rich Storybook Stories
- Multiple story variants showing different use cases
- Interactive controls for all props
- Accessibility testing setup
- Documentation blocks

## Validation

The command validates:
- ✅ Component name doesn't already exist
- ✅ Category is valid or creates new category
- ✅ Variant JSON is properly formatted
- ✅ Props syntax is correct
- ✅ Required directories exist
- ✅ Barrel file is accessible

## Post-Generation

After generating files, the command:
1. ✅ Creates all directories if missing
2. ✅ Writes all 4 files with correct content
3. ✅ Updates barrel export
4. ✅ Reports file locations
5. ✅ Suggests next steps (run Storybook, add tests, etc.)

## Integration with Devops

This Claude command is **compatible** with the devops tooling:
- Follows exact same file structure
- Uses identical naming conventions
- Generates same template boilerplate
- Updates barrel files the same way

You can mix usage:
- Use Claude commands for complex components
- Use devops commands for simple boilerplate
- Files are interchangeable

## Best Practices

1. **Start minimal** - Generate basic component, then enhance
2. **Use variants early** - Easier to add variants during generation
3. **Review generated code** - AI suggestions may need tweaking
4. **Test in Storybook** - Verify all variants render correctly
5. **Add to barrel** - Ensure exports are updated

## Example Workflow

```bash
# 1. Generate component with variants
/component avatar primitive --variants '{"size": ["Small", "Medium", "Large"], "status": ["Online", "Offline", "Away"]}'

# 2. Review generated files in IDE

# 3. Run Storybook to see component
npm run storybook

# 4. Ask Claude to enhance:
"Add image loading states and fallback to initials"

# 5. Ask Claude to add styles:
"Style the Avatar with rounded borders and status indicator in bottom-right"
```

## Related Commands

- `/page` - Generate a new page component
- `/story` - Add additional stories to existing component
- `/variants` - Add variants to existing component
- `/refactor-component` - Refactor existing component to follow patterns

## Notes

- Component names are automatically converted to PascalCase
- File/folder names use kebab-case
- Category names use kebab-case
- Barrel exports use ES module syntax (.js extensions)
- All components use TypeScript
- All components wrapped in MobX observer
- All components support forwardRef
