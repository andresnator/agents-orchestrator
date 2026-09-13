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


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def state_for(kind, today):
    slug = 'pizza' if kind == 'pizza' else 'airport' if kind.startswith('language') else 'http-cache-validation'
    state = dict(schema_version=1, revision=REVISION,
                 topic=dict(slug=slug, title='Synthetic fixture: ' + slug, materials_language='Spanish',
                            goal='Decide reuse, revalidation, or refetch from freshness and validators.', status='active'),
                 concepts=[dict(id='K-0001', title='Freshness and validation', prerequisites=[], taught=False)],
                 modules=[dict(id='M-0001', title='Freshness and validation', win='Explain and apply freshness and conditional validation.',
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
        for path, content in [('notes/m-0001.md', '# Cornell: cache validation\n\n## Questions\n- When is a response stale?\n- What does a 304 permit?\n\n## Notes\nAge greater than max-age is stale. A 304 allows body reuse.\n\n## Learner evidence\nPending: synthetic starting material.\n'), ('exercises/m-0001.md', '# Transfer\n\nAge 90, max-age 60, ETag present: explain the next request.\n\nPractice omitted in synthetic history.\n')]:
            state['artifacts'][path] = dict(content=content, source_revision=6, module_id='M-0001')
    if kind == 'flexible':
        state['topic']['goal'] = 'Implement a plugin and incorporate it in an integration project.'
        module.update(title='Plugin theory', win='Implement and operate a plugin.')
        module['consolidation']['blocking_gaps'] = ['No implemented plugin.']
        state['modules'].append(dict(id='M-0002', title='Integration', win='Incorporate your plugin.', phase='mission', taught_concept_ids=[], artifacts={}))
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
