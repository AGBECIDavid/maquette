import type { ButtonHTMLAttributes, ReactNode } from 'react';

export function Card({
  children,
  className = '',
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <div
      className={`rounded-xl border border-ink-800 bg-ink-900 p-5 ${className}`}
    >
      {children}
    </div>
  );
}

export function SectionTitle({
  children,
  action,
}: {
  children: ReactNode;
  action?: ReactNode;
}) {
  return (
    <div className="mb-3 flex items-center justify-between gap-4">
      <h2 className="text-sm font-semibold tracking-wide text-ink-300 uppercase">
        {children}
      </h2>
      {action}
    </div>
  );
}

export function PageHeader({
  title,
  subtitle,
  action,
}: {
  title: string;
  subtitle?: string;
  action?: ReactNode;
}) {
  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
      <div>
        <h1 className="text-2xl font-semibold text-ink-100">{title}</h1>
        {subtitle !== undefined && (
          <p className="mt-1 text-sm text-ink-400">{subtitle}</p>
        )}
      </div>
      {action}
    </div>
  );
}

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: 'primary' | 'ghost' | 'danger';
};

export function Button({ variant = 'ghost', className = '', ...props }: ButtonProps) {
  const styles = {
    primary: 'bg-accent text-white hover:bg-accent-soft',
    ghost: 'border border-ink-700 text-ink-300 hover:border-ink-600 hover:text-ink-100',
    danger: 'border border-bad/40 text-bad hover:bg-bad/10',
  }[variant];

  return (
    <button
      className={`rounded-lg px-3 py-1.5 text-sm font-medium transition-colors disabled:cursor-not-allowed disabled:opacity-40 ${styles} ${className}`}
      {...props}
    />
  );
}

export function EmptyState({
  title,
  hint,
  action,
}: {
  title: string;
  hint?: string;
  action?: ReactNode;
}) {
  return (
    <div className="rounded-xl border border-dashed border-ink-700 p-10 text-center">
      <p className="text-ink-300">{title}</p>
      {hint !== undefined && <p className="mt-1 text-sm text-ink-400">{hint}</p>}
      {action !== undefined && <div className="mt-4">{action}</div>}
    </div>
  );
}

/** Valeur inconnue : « — », jamais une valeur fabriquée. */
export function Unknown() {
  return <span className="text-ink-600">—</span>;
}
