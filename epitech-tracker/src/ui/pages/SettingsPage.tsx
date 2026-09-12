import { useRef, useState } from 'react';
import { useCurriculum } from '../../store/CurriculumContext';
import { findOrphans } from '../../data/schema';
import { buildDiagnostics } from '../../data/diagnostics';
import { APP_STAGE, APP_VERSION } from '../../version';
import { feedbackLink } from '../../config';
import { useSession } from '../../store/SessionContext';
import { today } from '../../domain/dates';
import { Button, Card, PageHeader, SectionTitle } from '../components/Primitives';
import { Field, FieldGrid, NumberInput } from '../components/Form';
import { YearsEditor } from '../components/YearsEditor';
import { PromotionPanel } from '../components/PromotionPanel';

export function SettingsPage() {
  const { data, updateSettings, exportJson, importJson, loadMock, reset } = useCurriculum();
  const { activeProfile } = useSession();
  const fileInput = useRef<HTMLInputElement>(null);
  const [message, setMessage] = useState<{ tone: 'ok' | 'bad'; text: string } | null>(null);

  const orphans = findOrphans(data);

  const saveFile = (content: string, filename: string) => {
    const blob = new Blob([content], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    link.click();
    URL.revokeObjectURL(url);
  };

  const download = () =>
    saveFile(exportJson(), `cursus-${new Date().toISOString().slice(0, 10)}.json`);

  const downloadDiagnostics = () => {
    const report = buildDiagnostics({
      curriculum: data,
      profileName: activeProfile?.name ?? '—',
      version: APP_VERSION,
      stage: APP_STAGE,
      today: today(),
      generatedAt: new Date().toISOString(),
      environment: {
        userAgent: navigator.userAgent,
        language: navigator.language,
        screen: `${window.screen.width}x${window.screen.height}`,
      },
    });
    saveFile(
      JSON.stringify(report, null, 2),
      `diagnostic-${APP_VERSION}-${new Date().toISOString().slice(0, 10)}.json`,
    );
  };

  return (
    <>
      <PageHeader
        title="Paramètres"
        subtitle={`Réglages d’alerte et gestion des données · version ${APP_VERSION} (${APP_STAGE})`}
      />

      <section className="mb-8">
        <SectionTitle>Années académiques</SectionTitle>
        <Card>
          <YearsEditor />
        </Card>
      </section>

      <section className="mb-8">
        <SectionTitle>Niveau et passage</SectionTitle>
        <PromotionPanel />
      </section>

      <section className="mb-8">
        <SectionTitle>Alertes</SectionTitle>
        <Card>
          <FieldGrid>
            <Field label="Deadline proche (jours)" hint="Seuil d’alerte avant échéance">
              <NumberInput
                value={data.settings.deadlineSoonDays}
                onChange={(v) => updateSettings({ deadlineSoonDays: v ?? 0 })}
                min={0}
              />
            </Field>
            <Field label="Roadblock bientôt validé (%)" hint="Part des crédits requis">
              <NumberInput
                value={Math.round(data.settings.roadblockAlmostDoneRatio * 100)}
                onChange={(v) =>
                  updateSettings({ roadblockAlmostDoneRatio: (v ?? 0) / 100 })
                }
                min={0}
                step={5}
              />
            </Field>
          </FieldGrid>
        </Card>
      </section>

      <section className="mb-8">
        <SectionTitle>Données</SectionTitle>
        <Card>
          {data.settings.source === 'mock' && (
            <p className="mb-4 rounded-lg border border-busy/40 bg-busy/5 px-4 py-3 text-sm text-busy">
              Les données affichées sont un <strong>jeu d’exemple</strong>. Aucun chiffre n’est
              officiel : ni les crédits, ni les seuils de Roadblock, ni les dates. Remplace-les par
              un import, ou repars de zéro.
            </p>
          )}

          <dl className="mb-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
            {[
              ['Années', data.years.length],
              ['Roadblocks', data.roadblocks.length],
              ['Modules', data.modules.length],
              ['Projets', data.projects.length],
            ].map(([label, count]) => (
              <div key={String(label)} className="rounded-lg border border-ink-800 px-3 py-2">
                <dt className="text-xs text-ink-400">{label}</dt>
                <dd className="text-lg tabular-nums text-ink-100">{count}</dd>
              </div>
            ))}
          </dl>

          {orphans.length > 0 && (
            <ul className="mb-4 rounded-lg border border-bad/40 bg-bad/5 px-4 py-3 text-sm text-bad">
              {orphans.map((problem) => (
                <li key={problem}>{problem}</li>
              ))}
            </ul>
          )}

          <div className="flex flex-wrap gap-2">
            <Button variant="primary" onClick={download}>Exporter en JSON</Button>
            <Button onClick={downloadDiagnostics}>Exporter un diagnostic</Button>
            <Button onClick={() => fileInput.current?.click()}>Importer un JSON</Button>
            <Button onClick={loadMock}>Recharger le jeu d’exemple</Button>
            <Button
              variant="danger"
              onClick={() => {
                if (window.confirm('Effacer toutes les données et repartir de zéro ?')) {
                  reset();
                  setMessage({ tone: 'ok', text: 'Données effacées.' });
                }
              }}
            >
              Repartir de zéro
            </Button>
          </div>

          <input
            ref={fileInput}
            type="file"
            accept="application/json"
            className="hidden"
            onChange={async (event) => {
              const file = event.target.files?.[0];
              if (file === undefined) return;
              const result = importJson(await file.text());
              setMessage(
                result.ok
                  ? { tone: 'ok', text: 'Import réussi.' }
                  : { tone: 'bad', text: `Import refusé : ${result.error}` },
              );
              event.target.value = '';
            }}
          />

          {message !== null && (
            <p className={`mt-4 text-sm ${message.tone === 'ok' ? 'text-ok' : 'text-bad'}`}>
              {message.text}
            </p>
          )}
        </Card>
      </section>

      <section className="mb-8">
        <SectionTitle>Signaler un problème</SectionTitle>
        <Card>
          <p className="text-sm text-ink-300">
            Version installée : <strong className="text-ink-100">{APP_VERSION}</strong> ({APP_STAGE}).
            Cite-la dans tout signalement — un bug rapporté sans version se cherche dans le mauvais
            code.
          </p>
          <p className="mt-3">
            <a
              href={feedbackLink(APP_VERSION, APP_STAGE)}
              target="_blank"
              rel="noreferrer noopener"
              className="inline-block rounded-lg bg-accent px-3 py-1.5 text-sm font-medium text-white hover:bg-accent-soft"
            >
              Signaler un problème
            </a>
            <span className="mt-2 block text-xs text-ink-400">
              Ouvre un signalement déjà rempli avec ta version, ton navigateur et ton écran.
            </span>
          </p>
          <p className="mt-3 text-sm text-ink-300">
            Le bouton <em>Exporter un diagnostic</em> ci-dessus produit un fichier contenant la
            version, ton navigateur, les compteurs, les incohérences détectées —{' '}
            <strong className="text-ink-100">et l’intégralité de ton cursus</strong>, notes et
            commentaires personnels compris. Relis-le avant de l’envoyer : c’est toi qui décides ce
            qui sort de ta machine.
          </p>
        </Card>
      </section>

      <section>
        <SectionTitle>Règles de calcul appliquées</SectionTitle>
        <Card>
          <ul className="flex list-disc flex-col gap-2 pl-5 text-sm text-ink-300">
            <li>Un module rapporte ses crédits proportionnellement à ses projets validés.</li>
            <li>Le poids d’un projet est une part égale des crédits du module, sauf poids forcé.</li>
            <li>Seul le statut « Validé » rapporte des crédits ; « Terminé » n’en rapporte pas.</li>
            <li>Un Roadblock est validé dès que ses crédits obtenus atteignent son seuil.</li>
            <li>Progression globale = crédits obtenus / crédits totaux requis.</li>
          </ul>
          <p className="mt-4 text-xs text-ink-400">
            Ces règles sont regroupées dans <code>src/domain/rules.ts</code> : si une règle Epitech
            diffère, c’est le seul fichier à modifier.
          </p>
          <p className="mt-3 text-xs text-ink-600">
            Outil de suivi personnel, sans lien officiel avec Epitech. Les chiffres affichés sont
            ceux que tu saisis : ils ne remplacent pas ton intranet.
          </p>
        </Card>
      </section>
    </>
  );
}
