# Boss request context projection

Date: 2026-09-08 (America/New_York)

The owner requested the pasted lightweight context-projection proposal, excluding
all owner notes and memory work. No new state store, classifier, summarizer,
configuration surface, or delegation quota is introduced.

## Runtime decisions

- Reuse the root-only `boss_main_decision_layer` gate at `build_prompt`, shared
  by sampling, retries, prompt debugging, and startup prewarming. Only the request
  copy changes; session persistence and ordinary Codex/Worker requests do not.
- Keep approximately 4,000 tokens of recent recognized technical results. Keep
  the newest tool response batch intact even when it exceeds that budget, so
  fresh parallel results can be read before aging. Older results become call-ID
  references to the session log and original call. Keep call/result pairing.
- Identify technical calls by tool name/namespace, never output text. Start with
  shell, file-read, code-execution, web, and CUA identities; unknown tools remain
  verbatim. User messages, Main language, and Worker handoffs remain intact.
- Reuse existing Worker fork sanitation. For Boss-root forks, retain Main's
  commentary as well as final answers and apply the durable-message filter to
  compacted replacement histories too. Both full and last-N forks use this path;
  no-history workers and Worker-to-Worker forks retain their existing behavior.
- Worker completion already sends a natural-language message without merging the
  execution transcript. Reuse that path and the existing hybrid Worker base.

## Validation

The single new `boss_projection` regression passes, including preservation of
fresh parallel results after runtime developer-context injection. The existing
`spawn_agent_can_fork_parent_thread_history_with_sanitized_items` regression also
passes. Both ran through `just test -p codex-core --lib` with exact test filters;
no full suite or model evaluation was added. Source commit `19852bc74` is pushed
to the configured Codex fork, and the public baseline patch matches it.

`just fmt` ran the Rust formatter; the unrelated Bazel formatter could not run
because `dotslash` is absent. Incidental formatting outside the change was
reverted. Changed Rust files were formatted directly. The public `.gitattributes`
allows blank-line context markers in generated patches, which otherwise produce
false trailing-whitespace failures; source whitespace checks still pass.

The 0.153.4 runtime build is pending. No claim is made about Luna speed or
attention improvement without a comparable model run. Automatic compaction
and existing token accounting are unchanged. Request-prefix cache invalidation
when old outputs age is an intentional tradeoff of this requested projection.

Base/main changed by this request: no. Notes/memory changes: none.
