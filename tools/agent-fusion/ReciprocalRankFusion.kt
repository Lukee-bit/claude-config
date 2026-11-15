package com.orchestrator.context.search

import com.orchestrator.context.domain.ContextSnippet
import java.util.Locale

/**
 * Reciprocal Rank Fusion over per-provider ranked lists.
 *
 * NOTE: reconstructed locally. The upstream repository (krokozyab/Agent-Fusion) references this
 * object from QueryContextTool.kt but does not ship the source file, so HEAD does not compile.
 * Semantics follow the comments in HybridContextProvider: weight / (k + rank), deduplicated by
 * chunkId, normalized so the top hit maps to 1.0.
 */
object ReciprocalRankFusion {

    data class RankedList(
        val providerId: String,
        val weight: Double,
        val snippets: List<ContextSnippet>
    )

    fun fuse(lists: List<RankedList>, k: Int = 60): List<ContextSnippet> {
        if (lists.isEmpty()) return emptyList()

        class Entry(var snippet: ContextSnippet, val providers: MutableList<String>, var score: Double)

        val entries = linkedMapOf<Long, Entry>()
        for (list in lists) {
            list.snippets.forEachIndexed { index, snippet ->
                val entry = entries.getOrPut(snippet.chunkId) { Entry(snippet, mutableListOf(), 0.0) }
                if (snippet.score > entry.snippet.score) entry.snippet = snippet
                entry.providers += list.providerId
                entry.score += list.weight / (k + index + 1)
            }
        }

        val max = entries.values.maxOfOrNull { it.score } ?: 0.0
        if (max <= 0.0) return emptyList()

        return entries.values
            .map { e ->
                val normalized = (e.score / max).coerceIn(0.0, 1.0)
                val sources = (e.snippet.metadata["sources"]?.split(',')?.map { it.trim() }.orEmpty() + e.providers)
                    .filter { it.isNotBlank() }.distinct().joinToString(",")
                e.snippet.copy(
                    score = normalized,
                    metadata = e.snippet.metadata + mapOf(
                        "sources" to sources,
                        "rrf_score" to "%.4f".format(Locale.US, e.score)
                    )
                )
            }
            .sortedByDescending { it.score }
    }
}
