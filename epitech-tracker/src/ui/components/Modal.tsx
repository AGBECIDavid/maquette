import { useEffect, type ReactNode } from 'react';

export function Modal({
  title,
  onClose,
  children,
  footer,
}: {
  title: string;
  onClose: () => void;
  children: ReactNode;
  footer?: ReactNode;
}) {
  // Échap ferme : un formulaire ouvert ne doit jamais piéger l'utilisateur.
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-ink-950/80 p-4 sm:p-8"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className="w-full max-w-xl rounded-xl border border-ink-700 bg-ink-900 shadow-2xl"
      >
        <div className="flex items-center justify-between border-b border-ink-800 px-5 py-4">
          <h2 className="text-base font-semibold text-ink-100">{title}</h2>
          <button
            type="button"
            onClick={onClose}
            aria-label="Fermer"
            className="rounded-md px-2 text-lg text-ink-400 hover:text-ink-100"
          >
            ×
          </button>
        </div>
        <div className="px-5 py-4">{children}</div>
        {footer !== undefined && (
          <div className="flex justify-end gap-2 border-t border-ink-800 px-5 py-4">
            {footer}
          </div>
        )}
      </div>
    </div>
  );
}
