export const PLUGIN_ID = "orchestration.subagent-statusline";
export const STATUS_SLOT = "prompt.footer.status";
export const STATE_ORDER = Object.freeze(["running", "succeeded", "failed", "interrupted", "idle", "unknown"]);

// The host cache owns event reduction and hydration; do not infer task state
// from messages, tool names, titles, or legacy session.status events.
export function childStatusLabel(sessions, sessionID) {
  if (!sessionID) return "";
  const counts = new Map();
  for (const child of sessions.list()) {
    if (child.id === sessionID || child.parentID !== sessionID) continue;
    const status = sessions.status(child.id);
    const state = status === "running"
      ? "running"
      : status === "idle"
        ? STATE_ORDER.includes(child.outcome) ? child.outcome : "idle"
        : "unknown";
    counts.set(state, (counts.get(state) ?? 0) + 1);
  }
  if (!counts.size) return "";
  return `Subagents: ${STATE_ORDER.filter((state) => counts.has(state))
    .map((state) => `${counts.get(state)} ${state}`).join(" · ")}`;
}

// Inject rendering/reactive primitives so Node tests exercise the same setup,
// slot and lifecycle as the native TSX entrypoint without installing peers.
export function statuslineDefinition({ createEffect, untrack, renderStatus }) {
  return {
    id: PLUGIN_ID,
    setup(context) {
      const unregister = context.ui.slot({
        append: STATUS_SLOT,
        render(props) {
          createEffect(() => {
            const sessionID = props.sessionID;
            if (!sessionID) return;
            // v2.0.28 uses the same children hydration in its session route.
            // Cache writes after unmount remain host-owned, not plugin state.
            untrack(() => {
              void context.data.session.sync(sessionID, { children: true }).catch(() => {});
            });
          });
          return renderStatus(context, () => childStatusLabel(context.data.session, props.sessionID));
        },
      });
      let disposed = false;
      return () => {
        if (disposed) return;
        disposed = true;
        unregister();
      };
    },
  };
}
