# /component - UI Component Generator

Create a UI component in `client/ui/components/` following architecture patterns.

## Required Reading

Before proceeding, read:
1. `.project/ARCHITECTURE_SPEC.md` - Component Architecture section
2. `ARCHITECTURE_COMPLIANCE.md` - Component patterns

## Task

Create a UI component that:
- ✅ Is view-only (no application logic)
- ✅ Uses custom CVA wrapper from `../../../util/cva` (relative path)
- ✅ Follows observer + forwardRef pattern
- ✅ Has SCSS file with BEM naming
- ✅ Has Storybook story
- ✅ Is exported from `client/ui/index.ts`
- ✅ Only imports from `client/util/` (using relative paths)
- ✅ Commits to `/client` git repository

## Steps

1. **Determine component category**: Ask user which category (if not provided):
   - `primitive` - Base components (Button, Input, Icon)
   - `domain` - Business components (UserCard, ProductList)
   - `layout` - Page layouts (HomeLayout, DashboardLayout)

2. **Create component file**: `client/ui/components/[category]/[component-name]/[component-name].tsx`

3. **Follow this exact pattern**:
   ```typescript
   import { observer } from "mobx-react";
   import React from "react";
   import { cva, VariantProps } from "../../../util/cva";
   import { classnames } from "../../../util/classnames";
   import "./[component-name].scss";

   export const ComponentNameCva = cva("ComponentName", {
     variants: {
       mode: {
         Primary: "ComponentName--primary",
         Secondary: "ComponentName--secondary",
       },
       size: {
         Small: "ComponentName--small",
         Large: "ComponentName--large",
       },
     },
     defaultVariants: {
       mode: "Primary",
       size: "Small",
     },
   });

   export interface IComponentName extends VariantProps<typeof ComponentNameCva.variants> {
     children?: React.ReactNode;
     className?: string;
     containerProps?: React.HTMLAttributes<HTMLDivElement>;
     // Add component-specific props
   }

   export const ComponentName = observer(
     React.forwardRef<HTMLDivElement, IComponentName>((props, ref) => {
       const {
         children,
         className,
         mode = ComponentNameCva.defaults?.mode,
         size = ComponentNameCva.defaults?.size,
         containerProps,
       } = props;

       return (
         <div
           ref={ref}
           className={classnames(
             ComponentNameCva.variants({ mode, size }),
             className
           )}
           {...containerProps}
         >
           {children}
         </div>
       );
     })
   );

   ComponentName.displayName = "ComponentName";
   ```

4. **Create SCSS file**: `client/ui/components/[category]/[component-name]/[component-name].scss`
   - Use BEM naming: `.ComponentName`, `.ComponentName--variant`, `.ComponentName__element`
   - Use CSS variables for theming
   - Follow existing component styles

5. **Create Storybook story**: `client/ui/stories/components/[category]/[component-name].stories.tsx`
   ```typescript
   import type { Meta, StoryObj } from '@storybook/react'
   import { ComponentName, ComponentNameCva } from '../../../components/[category]/[component-name]/[component-name]'

   const meta = {
     title: '[Category]/ComponentName',
     component: ComponentName,
     parameters: {
       layout: 'centered',
     },
     tags: ['autodocs'],
     argTypes: {
       mode: {
         control: 'select',
         options: Object.keys(ComponentNameCva.mode),
       },
     },
   } satisfies Meta<typeof ComponentName>

   export default meta
   type Story = StoryObj<typeof meta>

   export const Primary: Story = {
     args: {
       children: 'Component',
       mode: ComponentNameCva.mode.Primary,
     },
   }

   // Add more stories for each variant
   ```

6. **Add to barrel export**: Update `client/ui/index.ts`
   ```typescript
   export * from './components/[category]/[component-name]/[component-name]';
   ```

7. **Verify in Storybook**: Run `cd client && npm run storybook` and test the component

8. **Commit to client repository**:
   ```bash
   cd client
   git status
   git add ui/components/[category]/[component-name]/ ui/stories/components/[category]/[component-name].stories.tsx ui/index.ts
   git commit -m "Add [ComponentName] component

   🤖 Generated with [Claude Code](https://claude.com/claude-code)

   Co-Authored-By: Claude <noreply@anthropic.com>"
   ```

## Validation Checklist

Before completing, verify:
- [ ] Component is in `client/ui/components/[category]/[name]/`
- [ ] Uses custom CVA wrapper from `../../../util/cva` (not raw CVA)
- [ ] Has CVA enum access (.variant.Primary, .size.Large)
- [ ] Observer + forwardRef pattern
- [ ] VariantProps extends ComponentCva.variants
- [ ] SCSS uses BEM naming in same folder
- [ ] No imports from `client/src/` or `@/`
- [ ] Only imports from `client/util/` using relative paths
- [ ] Story created in `client/ui/stories/components/[category]/`
- [ ] Exported from `client/ui/index.ts`
- [ ] No application logic (no store access, no API calls)
- [ ] Has containerProps for HTML attributes
- [ ] Works in Storybook
- [ ] Committed to `/client` git repository

## Examples

Good examples to reference:
- `client/ui/components/primitive/button/button.tsx`
- `client/ui/components/primitive/icon/icon.tsx`
- `client/ui/components/primitive/social-button/social-button.tsx`
