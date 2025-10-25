# List Component Categories

Show all available component categories in the project with component counts and examples.

## Usage

```
/list-categories
```

This command will:
1. Scan the `ui/components/` directory
2. Count components in each category
3. Show examples from each category
4. Suggest which category to use for new components

## Example Output

The command will analyze your project and show something like:

```
Component Categories in your project:

📦 primitive (25 components)
   Base UI components with no business logic
   Examples: button, form-input, icon, modal, tabs
   Use for: Reusable UI building blocks

📦 domain (8 components)
   Business-specific components
   Examples: kpi, panel, sidebar, header
   Use for: Business logic display

📦 domain-form (26 components)
   Form workflows with validation
   Examples: login-form, create-account-form, payment-form
   Use for: Multi-step forms

📦 layout (12 components)
   Page-level templates
   Examples: login-layout, customer-dashboard-layout
   Use for: Page structure

📦 table (4 components)
   Data table variants
   Examples: tax-guardian-codes-table, user-table
   Use for: Tabular data

📦 container (3 components)
   Container components
   Examples: kpi-container, section-container
   Use for: Layout wrappers

📦 domain-modal (2 components)
   Modal variants
   Examples: confirmation-modal, info-modal
   Use for: Specialized modals

📦 domain-panel (5 components)
   Panel components
   Examples: notification-panel, code-library-panel
   Use for: Data panels

---

To create a component in a category:
/component <name> <category>

Example: /component avatar primitive
```

## When to Use This Command

- Starting a new component and unsure of category
- Want to see what components already exist
- Learning the project structure
- Planning component organization

## Related Commands

- `/help-component` - Detailed guide on component generation
- `/component <name>` - Create a new component
