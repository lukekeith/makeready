// Direct port from archive/react-spa:util/classnames.ts
export function classnames(...classes: (string | undefined | false | null)[]): string {
  return classes.filter(Boolean).join(' ')
}

export default classnames
