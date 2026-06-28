// The fixed (non-scrolling) header region at the top of a page. Title bar
// (breadcrumb left, actions right) from props, then `children` below for
// page-specific chrome (search/filter toolbar). Ported from fai-cd packages/ui
// navigation/header-container.
export function HeaderContainer({ breadcrumb, actions, children, className }) {
  return (
    <div className={className ? `HeaderContainer ${className}` : 'HeaderContainer'}>
      <div className="HeaderContainer__Bar">
        {breadcrumb}
        {actions}
      </div>
      {children}
    </div>
  );
}
