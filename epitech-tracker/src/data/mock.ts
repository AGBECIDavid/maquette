/**
 * ═══════════════════════════════════════════════════════════════════════
 *  DONNÉES D'EXEMPLE — MOCK. AUCUNE VALEUR OFFICIELLE EPITECH ICI.
 * ═══════════════════════════════════════════════════════════════════════
 *
 * Les noms de modules sont plausibles, mais les crédits, les seuils de
 * Roadblock et les dates sont INVENTÉS pour que l'interface ait quelque
 * chose à afficher. Rien dans ce fichier ne doit servir de référence.
 *
 * Remplacement : Paramètres → « Repartir de zéro », ou import d'un JSON.
 * `settings.source` passe alors à `user` et le bandeau MOCK disparaît.
 *
 * Les dates sont relatives à aujourd'hui pour que les deadlines proches et
 * les retards restent visibles quel que soit le jour où l'on ouvre l'app.
 */

import { addDays, today } from '../domain/dates';
import { SCHEMA_VERSION, DEFAULT_SETTINGS } from './schema';
import type {
  AcademicYear,
  Curriculum,
  Module,
  Priority,
  ProgressStatus,
  Project,
  ProjectStatus,
  Roadblock,
} from '../domain/types';

interface ProjectSpec {
  name: string;
  status: ProjectStatus;
  priority?: Priority;
  /** Décalages en jours par rapport à aujourd'hui. */
  start?: number;
  deadline?: number;
  done?: number;
  repoUrl?: string;
  notes?: string;
}

interface ModuleSpec {
  name: string;
  credits: number;
  start: number;
  end: number;
  grade?: string;
  status?: ProgressStatus;
  projects: ProjectSpec[];
}

interface RoadblockSpec {
  name: string;
  description: string;
  requiredCredits: number;
  start: number;
  end: number;
  modules: ModuleSpec[];
}

const SPECS: RoadblockSpec[] = [
  {
    name: 'Roadblock 1 — Fondations',
    description: 'Bases de la programmation impérative et de l’environnement Unix.',
    requiredCredits: 24,
    start: -380,
    end: -250,
    modules: [
      {
        name: 'C Pool',
        credits: 8,
        start: -380,
        end: -350,
        grade: 'A',
        projects: [
          { name: 'Pool Day 01-05', status: 'validated', start: -380, deadline: -370, done: -371 },
          { name: 'Pool Rush', status: 'validated', start: -365, deadline: -362, done: -362 },
          { name: 'Pool Final', status: 'validated', start: -355, deadline: -350, done: -350 },
        ],
      },
      {
        name: 'Elementary Programming in C',
        credits: 6,
        start: -348,
        end: -300,
        grade: 'B',
        projects: [
          { name: 'my_printf', status: 'validated', start: -348, deadline: -330, done: -331 },
          { name: 'my_sokoban', status: 'validated', start: -328, deadline: -300, done: -302 },
        ],
      },
      {
        name: 'Unix & C Lab Seminar',
        credits: 5,
        start: -340,
        end: -290,
        grade: 'A',
        projects: [
          { name: 'minishell1', status: 'validated', start: -340, deadline: -315, done: -316 },
          { name: 'minishell2', status: 'validated', start: -313, deadline: -290, done: -291 },
        ],
      },
      {
        name: 'Mathematics 1',
        credits: 5,
        start: -335,
        end: -255,
        grade: 'C',
        projects: [
          { name: '101pong', status: 'validated', start: -335, deadline: -300, done: -300 },
          { name: '102architect', status: 'validated', start: -298, deadline: -255, done: -258 },
        ],
      },
    ],
  },
  {
    name: 'Roadblock 2 — Structuration',
    description: 'Algorithmique, systèmes et premiers projets de groupe.',
    requiredCredits: 24,
    start: -248,
    end: -120,
    modules: [
      {
        name: 'Advanced C Programming',
        credits: 7,
        start: -248,
        end: -200,
        grade: 'B',
        projects: [
          { name: 'my_radar', status: 'validated', start: -248, deadline: -220, done: -221 },
          { name: 'corewar', status: 'validated', start: -218, deadline: -200, done: -200 },
        ],
      },
      {
        name: 'Systems Programming',
        credits: 6,
        start: -240,
        end: -190,
        grade: 'B',
        projects: [
          { name: 'my_ls', status: 'validated', start: -240, deadline: -215, done: -216 },
          { name: 'nanotekspice', status: 'validated', start: -213, deadline: -190, done: -192 },
        ],
      },
      {
        name: 'Object-Oriented Programming',
        credits: 6,
        start: -200,
        end: -150,
        grade: 'A',
        projects: [
          { name: 'arcade', status: 'validated', start: -200, deadline: -170, done: -172 },
          { name: 'indie studio', status: 'validated', start: -168, deadline: -150, done: -151 },
        ],
      },
      {
        name: 'English B2',
        credits: 5,
        start: -240,
        end: -125,
        grade: 'B',
        projects: [
          { name: 'TOEIC Blank 1', status: 'validated', start: -240, deadline: -180, done: -181 },
          { name: 'TOEIC Blank 2', status: 'validated', start: -178, deadline: -125, done: -127 },
        ],
      },
    ],
  },
  {
    name: 'Roadblock 3 — Spécialisation',
    description: 'Web, réseaux et bases de données.',
    requiredCredits: 24,
    start: -118,
    end: -10,
    modules: [
      {
        name: 'Web Programming',
        credits: 6,
        start: -118,
        end: -60,
        grade: 'A',
        projects: [
          { name: 'Web Project 1', status: 'validated', start: -118, deadline: -100, done: -101 },
          { name: 'Web Project 2', status: 'validated', start: -98, deadline: -80, done: -80 },
          { name: 'Web Project 3', status: 'validated', start: -78, deadline: -60, done: -62 },
        ],
      },
      {
        name: 'Networks & Protocols',
        credits: 6,
        start: -110,
        end: -55,
        grade: 'B',
        projects: [
          { name: 'myftp', status: 'validated', start: -110, deadline: -85, done: -86 },
          { name: 'myteams', status: 'validated', start: -83, deadline: -55, done: -57 },
        ],
      },
      {
        name: 'Databases',
        credits: 6,
        start: -90,
        end: -30,
        grade: 'B',
        projects: [
          { name: 'Schema design', status: 'validated', start: -90, deadline: -60, done: -61 },
          { name: 'Query optimisation', status: 'validated', start: -58, deadline: -30, done: -32 },
        ],
      },
      {
        name: 'Software Engineering',
        credits: 6,
        start: -80,
        end: -10,
        grade: 'A',
        projects: [
          { name: 'Agile workshop', status: 'validated', start: -80, deadline: -45, done: -46 },
          { name: 'Team project', status: 'validated', start: -43, deadline: -10, done: -12 },
        ],
      },
    ],
  },
  {
    name: 'Roadblock 4 — Approfondissement',
    description: 'Projets longs, DevOps et intelligence artificielle.',
    requiredCredits: 24,
    start: -8,
    end: 110,
    modules: [
      {
        name: 'DevOps',
        credits: 6,
        start: -8,
        end: 20,
        projects: [
          { name: 'Docker pipeline', status: 'validated', start: -8, deadline: 2, done: -1, repoUrl: 'https://github.com/exemple/devops-pipeline' },
          { name: 'CI/CD chain', status: 'in_progress', priority: 'critical', start: -2, deadline: 2 },
          { name: 'Monitoring stack', status: 'todo', priority: 'high', start: 4, deadline: 20 },
        ],
      },
      {
        name: 'Artificial Intelligence',
        credits: 6,
        start: -5,
        end: 45,
        projects: [
          { name: 'my_torch', status: 'in_progress', priority: 'high', start: -5, deadline: 5 },
          { name: 'Neural network report', status: 'todo', priority: 'normal', start: 8, deadline: 45 },
        ],
      },
      {
        name: 'Cyber Security',
        credits: 6,
        start: -3,
        end: 60,
        projects: [
          { name: 'Web exploitation', status: 'done', priority: 'normal', start: -3, deadline: -1, done: -1, notes: 'Rendu, en attente de correction.' },
          { name: 'Reverse engineering', status: 'todo', priority: 'critical', start: 0, deadline: -2, notes: 'Deadline dépassée — à rattraper.' },
          { name: 'Forensics', status: 'todo', priority: 'low', start: 20, deadline: 60 },
        ],
      },
      {
        name: 'Project Management',
        credits: 6,
        start: 10,
        end: 110,
        projects: [
          { name: 'Business plan', status: 'todo', priority: 'normal', start: 10, deadline: 55 },
          { name: 'Final defense', status: 'todo', priority: 'high', start: 60, deadline: 110 },
        ],
      },
    ],
  },
  {
    name: 'Roadblock 5 — Fin de cycle',
    description: 'Dernier palier avant la validation du cycle.',
    requiredCredits: 24,
    start: 120,
    end: 280,
    modules: [
      {
        name: 'Compilation',
        credits: 8,
        start: 120,
        end: 190,
        projects: [
          { name: 'Lexer & parser', status: 'todo', priority: 'normal', start: 120, deadline: 160 },
          { name: 'Code generation', status: 'todo', priority: 'normal', start: 162, deadline: 190 },
        ],
      },
      {
        name: 'Functional Programming',
        credits: 8,
        start: 150,
        end: 230,
        projects: [
          { name: 'glados', status: 'todo', priority: 'normal', start: 150, deadline: 230 },
        ],
      },
      {
        name: 'Mobile Development',
        credits: 8,
        start: 200,
        end: 280,
        projects: [
          { name: 'Mobile app', status: 'todo', priority: 'low', start: 200, deadline: 250 },
          { name: 'Store release', status: 'todo', priority: 'low', start: 252, deadline: 280 },
        ],
      },
    ],
  },
];

/** Construit le jeu de données d'exemple, daté par rapport à aujourd'hui. */
export function mockCurriculum(reference: string = today()): Curriculum {
  const at = (offset: number | undefined): string | null =>
    offset === undefined ? null : addDays(reference, offset);

  const year: AcademicYear = {
    id: 'year-1',
    label: '2026-2027 (exemple)',
    level: 'TEK1',
    order: 1,
    startDate: addDays(reference, -380),
    endDate: addDays(reference, 280),
  };

  const roadblocks: Roadblock[] = [];
  const modules: Module[] = [];
  const projects: Project[] = [];

  SPECS.forEach((rbSpec, rbIndex) => {
    const rbId = `rb-${rbIndex + 1}`;
    roadblocks.push({
      id: rbId,
      yearId: year.id,
      name: rbSpec.name,
      description: rbSpec.description,
      order: rbIndex + 1,
      requiredCredits: rbSpec.requiredCredits,
      startDate: at(rbSpec.start),
      endDate: at(rbSpec.end),
      statusOverride: null,
    });

    rbSpec.modules.forEach((mSpec, mIndex) => {
      const mId = `${rbId}-m${mIndex + 1}`;
      modules.push({
        id: mId,
        roadblockId: rbId,
        name: mSpec.name,
        description: '',
        order: mIndex + 1,
        credits: mSpec.credits,
        startDate: at(mSpec.start),
        endDate: at(mSpec.end),
        statusOverride: mSpec.status ?? null,
        grade: mSpec.grade ?? null,
        notes: '',
      });

      mSpec.projects.forEach((pSpec, pIndex) => {
        projects.push({
          id: `${mId}-p${pIndex + 1}`,
          moduleId: mId,
          name: pSpec.name,
          description: '',
          order: pIndex + 1,
          creditsOverride: null,
          startDate: at(pSpec.start),
          deadline: at(pSpec.deadline),
          completedAt: at(pSpec.done),
          status: pSpec.status,
          priority: pSpec.priority ?? 'normal',
          grade: null,
          repoUrl: pSpec.repoUrl ?? null,
          notes: pSpec.notes ?? '',
        });
      });
    });
  });

  return {
    schemaVersion: SCHEMA_VERSION,
    years: [year],
    roadblocks,
    modules,
    projects,
    settings: { ...DEFAULT_SETTINGS, currentYearId: year.id, source: 'mock' },
  };
}
