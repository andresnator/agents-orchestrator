import { Plugin } from "@opencode/plugin/tui";
import { createEffect, untrack, Show } from "solid-js";
import { statuslineDefinition } from "./statusline.mjs";

export default Plugin.define(statuslineDefinition({
  createEffect,
  untrack,
  renderStatus: (context, label) => (
    <Show when={label()}>
      <text fg={context.theme.text.muted}>{label()}</text>
    </Show>
  ),
}));
