#!/usr/bin/env python3
"""Copy synthetic Learning starting points into a new, case-owned directory."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import shlex
import shutil

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
REVISION = 7
PREFIX = 'MT-LEARNING-'

# A prepared topic must describe the behavior exercised by its case.  Keep
# these profiles together so changing a slug cannot silently retain another
# curriculum's goal, concept, module, or language metadata.
TOPIC_PROFILES = {
    'http-cache-validation': {
        'title': 'HTTP cache validation',
        'goal': 'Decide whether a cached response can be reused, revalidated, or refetched from freshness and validators.',
        'concept': 'Freshness and conditional validation',
        'module': 'Freshness and validation',
        'win': 'Explain and apply freshness and conditional validation.',
    },
    'pizza': {
        'title': 'Pizza dough fermentation',
        'goal': 'Explain how fermentation changes pizza dough and apply the explanation to a dough preparation decision.',
        'concept': 'Fermentation and dough structure',
        'module': 'Fermentation of pizza dough',
        'win': 'Explain fermentation and apply it to a pizza dough decision.',
    },
    'airport': {
        'title': 'Airport check-in English',
        'goal': 'Handle an airport check-in exchange in English while preserving the intended meaning.',
        'concept': 'Airport check-in communication',
        'module': 'Check in for a flight',
        'win': 'Produce and understand a clear airport check-in exchange.',
    },
    'plugin-security': {
        'title': 'Plugin security and integration',
        'goal': 'Explain safe plugin activation decisions and their effect on a local and remote integration.',
        'concept': 'Plugin contracts and safe activation',
        'module': 'Plugin theory',
        'win': 'Explain plugin contracts and safe activation decisions.',
    },
}

LANGUAGE_TOPIC_SLUG = 'airport'


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def topic_slug_for_kind(kind):
    if kind == 'pizza':
        return 'pizza'
    if kind.startswith('language'):
        return LANGUAGE_TOPIC_SLUG
    if kind in ('flexible', 'plugin-mission'):
        return 'plugin-security'
    return 'http-cache-validation'


def state_for(kind, today):
    slug = topic_slug_for_kind(kind)
    profile = TOPIC_PROFILES[slug]
    state = dict(schema_version=1, revision=REVISION,
                 topic=dict(slug=slug, title=profile['title'], materials_language='Spanish',
                            goal=profile['goal'], status='active'),
                 concepts=[dict(id='K-0001', title=profile['concept'], prerequisites=[], taught=False)],
                 modules=[dict(id='M-0001', title=profile['module'], win=profile['win'],
                               phase='mission', taught_concept_ids=[], artifacts={})],
                 language_units=[], vocabulary=dict(candidates=[], exports=[]), gaps=[], jobs=[], artifacts={},
                 applied_events={}, consents=[], views=dict(revision=REVISION, status='current'))
    module = state['modules'][0]
    if kind in ('class', 'partial', 'closed', 'consolidation', 'flexible', 'legacy-pending', 'legacy-selected'):
        module.update(phase='class', taught_concept_ids=['K-0001'], class_evidence='SYNTHETIC historical lesson, not live learner evidence.')
        state['concepts'][0]['taught'] = True
    if kind == 'partial':
        module.update(phase='practice', attempt=dict(revision=6, outcome='partial', evidence='SYNTHETIC: stale identified; validator decision missing.'))
    if kind in ('closed', 'consolidation', 'flexible', 'legacy-pending', 'legacy-selected'):
        module.update(phase='closed' if kind == 'closed' else 'consolidation', practice_skipped=True,
                      consolidation=dict(revision=6, learner_evidence='SYNTHETIC historical narrative; obtain real references for new assessment.', blocking_gaps=[]),
                      artifacts=dict(note='notes/m-0001.md', exercise='exercises/m-0001.md'))
        materials = {
            'http-cache-validation': [
                ('notes/m-0001.md', '# Cornell: cache validation\n\n## Questions\n- When is a response stale?\n- What does a 304 permit?\n\n## Notes\nAge greater than max-age is stale. A 304 allows body reuse.\n\n## Learner evidence\nPending: synthetic starting material.\n'),
                ('exercises/m-0001.md', '# Transfer\n\nAge 90, max-age 60, ETag present: explain the next request.\n\nPractice omitted in synthetic history.\n'),
            ],
            'plugin-security': [
                ('notes/m-0001.md', '# Cornell: plugin security\n\n## Questions\n- What must be checked before activation?\n- When should a plugin be disabled?\n\n## Notes\nCheck the host contract, permissions, and failure behavior before activation. Disable an unsafe plugin.\n\n## Learner evidence\nPending: synthetic starting material.\n'),
                ('exercises/m-0001.md', '# Transfer\n\nA plugin requests a capability that is outside its contract: explain the safe decision and its integration impact.\n\nPractice omitted in synthetic history.\n'),
            ],
        }
        for path, content in materials[slug]:
            state['artifacts'][path] = dict(content=content, source_revision=6, module_id='M-0001')
    if kind == 'flexible':
        state['topic']['goal'] = 'Implement a plugin and incorporate it in a local and remote integration project.'
        module['win'] = 'Implement, activate, diagnose and disable a real plugin.'
        module['consolidation']['blocking_gaps'] = ['No implemented plugin.']
        state['modules'].append(dict(id='M-0002', title='Integration', win='Incorporate a personal plugin in the integration project.', phase='mission', taught_concept_ids=[], artifacts={}))
        for artifact in state['artifacts'].values():
            artifact['content'] += '\n## Pending practical requirements\n\n' + '\n'.join('- ' + item['win'] for item in state['modules']) + '\n\nNo implementation or integration has been demonstrated.\n'
    if kind.startswith('language') or kind.startswith('legacy'):
        state['topic'].update(target_language='English', native_language='Spanish', production_required=True)
        count = int(kind.split('-')[1]) if kind.startswith('language') else 1
        state['language_units'] = [dict(id=f'L-{n:04}', passive_at=today, situation=f'Airport check-in {n}',
            target_text=f'I would like to check in for flight {n}.', native_text=f'Quisiera facturar para el vuelo {n}.', status='pending') for n in range(1, count + 1)]
    if kind.startswith('legacy'):
        state['cards'] = [dict(id='C-0001', cue='Why revalidate?', answer='Check whether the representation changed.', concept_id='K-0001', source_revision=5, box=2, last='2026-09-01', next='2026-09-04', status='active', again_count=0, lineage=[])]
        preview = dict(topic_slug=slug, module_id='M-0001', id='OLD-PREVIEW', source_revision=6, cards=[dict(proposal_id='P-1', cue='Why revalidate?', answer='Check changes', concept_id='K-0001', reason='Recurring decision')])
        digest = hashlib.sha256(json.dumps(preview, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        selected = kind == 'legacy-selected'
        module['retention'] = dict(disposition='selected' if selected else 'pending', selected_card_ids=['C-0001'] if selected else [], preview=dict(preview, digest=digest))
        state['review_events'] = [dict(event_id='OLD-GRADE', card_id='C-0001', date='2026-09-02', grade='Good', evidence='SYNTHETIC history')]
        state['consents'] = [dict(interaction_id='old-choice', purpose='cards', request_id='old-request', digest='a' * 64, selected=[])]
        state['language_units'][0]['next_due'] = (datetime.date.fromisoformat(today) + datetime.timedelta(days=30)).isoformat()
    return state


def prepare(case_id, destination, today):
    cases = json.loads((ROOT / 'cases.json').read_text())
    case_id = case_id if case_id.startswith(PREFIX) else PREFIX + case_id
    if case_id not in cases:
        raise ValueError('Unknown case: ' + case_id)
    destination = destination.resolve()
    destination.mkdir(parents=True, exist_ok=False)
    case = cases[case_id]
    for name, kind in case['variants'].items():
        variant = destination / name
        project = variant / 'project'
        project.mkdir(parents=True)
        for folder in ('config', 'xdg/config', 'xdg/data', 'xdg/state', 'xdg/cache', 'tmp', 'evidence', 'provider'):
            (variant / folder).mkdir(parents=True)
        shutil.copytree(ROOT / 'materials', variant / 'materials')
        if kind != 'empty' and not kind.startswith('skill:'):
            state = state_for(kind, today)
            topic = project / '.ai/learning' / state['topic']['slug']
            write_json(topic / '.state.json', state)
            if kind.startswith('legacy') or kind == 'closed':
                (topic / 'review-queue.md').write_text('# Historical queue\nSYNTHETIC immutable fixture.\n')
        if kind.startswith('skill:'):
            skill = kind.split(':')[1]
            shutil.copytree(REPO / 'domains/learning/skills' / skill, variant / 'config/skills' / skill)
        env = dict(OPENCODE_CONFIG_DIR=str(variant / 'config'), OPENCODE_DISABLE_PROJECT_CONFIG='true',
                   OPENCODE_DISABLE_EXTERNAL_SKILLS='true', OPENCODE_DISABLE_CLAUDE_CODE='true',
                   XDG_CONFIG_HOME=str(variant / 'xdg/config'), XDG_DATA_HOME=str(variant / 'xdg/data'),
                   XDG_STATE_HOME=str(variant / 'xdg/state'), XDG_CACHE_HOME=str(variant / 'xdg/cache'), TMPDIR=str(variant / 'tmp'))
        (variant / 'env.sh').write_text('\n'.join('export ' + key + '=' + shlex.quote(value) for key, value in env.items()) + '\ncd ' + shlex.quote(str(project)) + '\n')
    write_json(destination / 'manifest.json', dict(case_id=case_id, synthetic=True, date=today, source=str(REPO), variants=case['variants']))
    shutil.copy2(ROOT / 'README.md', destination / 'preparation.md')
    return destination


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case_id')
    parser.add_argument('destination', type=Path, help='Must not exist; never merge mutable fixtures')
    parser.add_argument('--date', default=datetime.date.today().isoformat())
    args = parser.parse_args()
    datetime.date.fromisoformat(args.date)
    print(prepare(args.case_id, args.destination, args.date))
