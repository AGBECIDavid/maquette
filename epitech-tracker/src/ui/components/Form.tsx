import type { ReactNode } from 'react';

const INPUT =
  'w-full rounded-lg border border-ink-700 bg-ink-850 px-3 py-2 text-sm text-ink-100 outline-none placeholder:text-ink-600 focus:border-accent';

export function Field({ label, hint, children }: { label: string; hint?: string; children: ReactNode }) {
  return (
    <label className="block">
      <span className="mb-1 block text-xs font-medium text-ink-400">{label}</span>
      {children}
      {hint !== undefined && <span className="mt-1 block text-xs text-ink-600">{hint}</span>}
    </label>
  );
}

export function FieldGrid({ children }: { children: ReactNode }) {
  return <div className="grid gap-4 sm:grid-cols-2">{children}</div>;
}

export function TextInput({
  value,
  onChange,
  placeholder,
  autoFocus,
}: {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  autoFocus?: boolean;
}) {
  return (
    <input
      type="text"
      className={INPUT}
      value={value}
      placeholder={placeholder}
      autoFocus={autoFocus}
      onChange={(event) => onChange(event.target.value)}
    />
  );
}

export function TextArea({
  value,
  onChange,
  rows = 3,
  placeholder,
}: {
  value: string;
  onChange: (value: string) => void;
  rows?: number;
  placeholder?: string;
}) {
  return (
    <textarea
      className={INPUT}
      rows={rows}
      value={value}
      placeholder={placeholder}
      onChange={(event) => onChange(event.target.value)}
    />
  );
}

export function NumberInput({
  value,
  onChange,
  min = 0,
  step = 1,
  placeholder,
}: {
  value: number | null;
  onChange: (value: number | null) => void;
  min?: number;
  step?: number;
  placeholder?: string;
}) {
  return (
    <input
      type="number"
      className={INPUT}
      value={value === null ? '' : value}
      min={min}
      step={step}
      placeholder={placeholder}
      onChange={(event) => {
        const raw = event.target.value;
        onChange(raw === '' ? null : Number(raw));
      }}
    />
  );
}

/** Champ date : vide = inconnu, et c'est une information en soi. */
export function DateInput({
  value,
  onChange,
}: {
  value: string | null;
  onChange: (value: string | null) => void;
}) {
  return (
    <input
      type="date"
      className={`${INPUT} [color-scheme:dark]`}
      value={value ?? ''}
      onChange={(event) => onChange(event.target.value === '' ? null : event.target.value)}
    />
  );
}

export function Select<T extends string>({
  value,
  onChange,
  options,
}: {
  value: T;
  onChange: (value: T) => void;
  options: { value: T; label: string }[];
}) {
  return (
    <select
      className={INPUT}
      value={value}
      onChange={(event) => onChange(event.target.value as T)}
    >
      {options.map((option) => (
        <option key={option.value} value={option.value} className="bg-ink-850">
          {option.label}
        </option>
      ))}
    </select>
  );
}
