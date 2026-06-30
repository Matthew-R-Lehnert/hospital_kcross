# Target journals

This paper sits at the intersection of **health geography / GIScience**,
**health services research / policy**, and **applied spatial statistics**. The
*same study* can be aimed up- or down-stream by changing the framing lever:

- **Finding-forward** ("the US has measurable, mappable hospital–population
  misalignment, and the ambient lens changes the verdict") → high-impact health
  & policy journals.
- **Method-forward** ("a raster-driven population-null inhomogeneous-K test of
  facility location, with family-wise rigor") → geography / spatial-methods
  journals.

The two genuine hooks for prestige are (1) the **ambient-population null** (no
prior hospital study uses it — confirmed in the lit review) and (2) **national
scale with formal, family-wise-corrected hypothesis testing**.

## Tier 1 — prestige reach (finding-forward framing)

| Journal | Why it fits | Caveat |
|---------|-------------|--------|
| **JAMA Network Open** | Open access, very high visibility; hospital access/equity studies are squarely in scope; a clean national finding lands well. | Wants clinical/policy relevance foregrounded over method detail. **Strong realistic top target.** |
| **The Lancet Regional Health – Americas** | High prestige, public-health, US/Americas access equity is core. | Method-heavy framing must be tempered with the policy story. |
| **PNAS** | National inequity finding + methodological novelty can clear the bar. | Competitive; needs a crisp, surprising headline result. |
| **Nature Communications / Communications Medicine** | Rewards data+method novelty (ambient null, national point-process test). | Broad significance must be argued explicitly. |
| *Health Affairs* | The policy venue of record for access/capacity. | Prefers policy analysis over spatial method; would need heavy reframing. |

## Tier 2 — natural home, strong fit (the core targets)

| Journal | Why it fits |
|---------|-------------|
| **International Journal of Health Geographics** | The canonical venue for GIS/spatial-method healthcare-access work; open access; *the* natural home. **Recommended primary if optimizing fit-over-reach.** |
| **Annals of the American Association of Geographers** | Top geography journal; rewards a substantive national analysis with a methodological spine. |
| **Health & Place** | Leading health-geography journal; access/equity + place is exactly its remit. |
| **Social Science & Medicine** | Prestigious, broad; access inequity with a rigorous method travels well. |
| **Health Services Research** / **BMC Health Services Research** | Access/equity and hospital distribution core scope (HSR higher prestige; BMC-HSR faster/OA). |

## Tier 3 — methods / GIScience (method-forward framing)

| Journal | Why it fits |
|---------|-------------|
| **Int. Journal of Geographical Information Science (IJGIS)** | If the contribution is pitched as the population-null K method + national pipeline. |
| **Geographical Analysis** | Spatial-statistics methods journal; the estimator + global-envelope rigor fit. |
| **Spatial and Spatio-temporal Epidemiology** | Point-process + population-baseline lineage (Diggle case-control) is native here. |
| **Computers, Environment and Urban Systems** | Spatial-analysis + urban systems audience. |

## Recommendation

- **Primary (fit + solid prestige):** *International Journal of Health
  Geographics* — the natural home; reviewers will already know `spatstat`,
  commuting zones, and 2SFCA, so the contribution is legible.
- **Reach (if the national result is striking):** *JAMA Network Open* or
  *Lancet Regional Health – Americas* — finding-forward framing.
- **Method showcase fallback:** *Annals of the AAG* or *IJGIS*.

Strategy: draft once with a modular framing, decide reach-vs-fit after the
national results are in (the strength/surprise of the ambient-vs-residential
flip determines whether a Tier 1 reach is justified). Confirm each venue's
current scope and citation style (`manuscript/` builds APA/Chicago/Vancouver/
IEEE/Harvard via `make STYLE=...`).
