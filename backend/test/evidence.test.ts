import { describe, expect, it } from 'vitest';
import { evidence, researchReply } from '../src/evidence.js';
describe('curated evidence',()=>{
  it('keeps provenance and applicability limits on every study',()=>{
    expect(evidence).toHaveLength(4);
    for(const item of evidence){expect(item.doi).toMatch(/^10\./);expect(item.url).toMatch(/^https:\/\/(pubmed\.ncbi\.nlm\.nih\.gov|pmc\.ncbi\.nlm\.nih\.gov|www\.nejm\.org)\//);expect(item.population.length).toBeGreaterThan(10);expect(item.limitations.length).toBeGreaterThan(40);}
  });
  it('retrieves cited evidence only for explicit source questions',()=>{
    expect(researchReply('Suggest my lunch')).toBeNull();
    expect(researchReply('What research supports walking?')).toContain('PMC9289978');
    expect(researchReply('What studies discuss kidney stones?')).toContain('10.1056/NEJMoa010369');
    expect(researchReply('What studies discuss kidney stones?')).toContain('clinician');
  });
});
