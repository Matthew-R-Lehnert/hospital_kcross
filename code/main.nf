#!/usr/bin/env nextflow
// ============================================================================
// main.nf -- Nextflow pipeline for the hospital x population inhomogeneous-K
// analysis. Fans every (commuting zone x population-kind x subset x weighting)
// out as an independent task, each running the R/spatstat engine once, then
// collates all per-run metadata into one summary table.
//
// On a laptop: local executor (queueSize tasks in parallel). On a cluster:
// flip to the slurm / awsbatch profile in nextflow.config; the same processes
// run unchanged. `-resume` re-uses completed tasks.
//
// Examples:
//   nextflow run code/main.nf                               # all zones, ambient, 999 sims
//   nextflow run code/main.nf --pop_kinds ambient,residential
//   nextflow run code/main.nf --zones 'Tucson, AZ;San Diego, CA' --nsim 99
//   nextflow run code/main.nf --subsets all,trauma --weight_by none,beds
//   nextflow run code/main.nf -profile slurm -resume
// ============================================================================

nextflow.enable.dsl = 2

params.root       = "${projectDir}/.."                       // repo root
params.windows    = "${params.root}/data/commuting_zones.gpkg"
params.outdir     = "${params.root}/output"
params.rscript    = "${projectDir}/scripts/run_cz.R"
params.rbin       = "Rscript"                                // override with full path if R not on PATH
params.year       = 2020
params.pop_kinds  = "ambient"        // comma list: ambient,residential
params.subsets    = "all"            // comma list: all,trauma
params.weight_by  = "none"           // comma list: none,beds
params.nsim       = 999
params.zones      = ""               // SEMICOLON list (CZ names contain commas); empty = all

// ---------------------------------------------------------------------------
// Emit the list of commuting-zone window names, one per line.
// ---------------------------------------------------------------------------
process LIST_ZONES {
    output:
    path "zones.txt"

    script:
    """
    python3 ${projectDir}/scripts/list_zones.py "${params.windows}" > zones.txt
    """
}

// ---------------------------------------------------------------------------
// One (zone, pop_kind, subset, weight) combination -> envelope + plot + meta.
// Outputs are optional: zones with too few hospitals are skipped by the engine
// and legitimately produce nothing.
// ---------------------------------------------------------------------------
process HK {
    tag    { "${zone} | ${pop_kind} | ${subset}${weight == 'beds' ? ' | beds' : ''}" }
    cpus   1
    publishDir { "${params.outdir}/${pop_kind}" }, mode: 'copy'

    input:
    tuple val(zone), val(pop_kind), val(subset), val(weight)

    output:
    path "*_envelope.png", optional: true
    path "*_envelope.csv", optional: true
    path "*_meta.json",    optional: true, emit: meta

    script:
    """
    export HK_OUT="\$PWD/_out"
    ${params.rbin} ${params.rscript} "${zone}" ${params.year} ${pop_kind} ${subset} ${weight} ${params.nsim}
    mv _out/* . 2>/dev/null || true
    """
}

// ---------------------------------------------------------------------------
// Collate every task's meta.json into one tidy summary.csv.
// ---------------------------------------------------------------------------
process COLLATE {
    publishDir "${params.outdir}", mode: 'copy'

    input:
    path metas

    output:
    path "summary.csv"

    script:
    """
    python3 ${projectDir}/scripts/collate.py ${metas} > summary.csv
    """
}

workflow {
    zones_ch = LIST_ZONES().splitText().map { it.trim() }.filter { it }

    if (params.zones?.trim()) {
        wanted = params.zones.split(';').collect { it.trim() }
        zones_ch = zones_ch.filter { wanted.contains(it) }
    }

    pop_ch = Channel.fromList(params.pop_kinds.split(',').collect { it.trim() })
    sub_ch = Channel.fromList(params.subsets.split(',').collect   { it.trim() })
    wt_ch  = Channel.fromList(params.weight_by.split(',').collect  { it.trim() })

    combos = zones_ch.combine(pop_ch).combine(sub_ch).combine(wt_ch)

    HK(combos)
    COLLATE(HK.out.meta.collect())
}
