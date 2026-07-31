# Use LM Studio From OpenCode Over A Local Network

Run LM Studio on one computer and point OpenCode on another computer at its OpenAI-compatible API. The two computers must be able to reach each other on the local network; LM Studio must listen beyond `localhost`; and the OpenCode provider must use the LM Studio computer's LAN address.

This guide calls the computers:

- **Computer A**: runs OpenCode.
- **Computer B**: runs LM Studio and the models.

## Quick Path

1. On Computer B, enable **Serve on Local Network** and **Require Authentication** in LM Studio's **Developer > Server Settings**, then start the server.
2. Note Computer B's LAN address, for example `192.168.1.50`, and allow inbound TCP traffic to LM Studio's port (normally `1234`) from the local network.
3. From Computer A, verify `http://192.168.1.50:1234/v1/models` before configuring OpenCode.
4. Add an `lmstudio-lan` provider and its model ids to Computer A's `opencode.json`.
5. Restart OpenCode, run `/models`, and select a model under **LM Studio (LAN)**.

Do not use `127.0.0.1` or `localhost` in Computer A's configuration: those names refer to Computer A itself, not the computer running LM Studio.

## 1. Expose LM Studio On Computer B

### LM Studio application

In LM Studio:

1. Open **Developer**.
2. Open **Server Settings**.
3. Keep or choose a server port. The examples below use `1234`.
4. Enable **Serve on Local Network**.
5. Enable **Require Authentication**.
6. Open **Manage Tokens**, create a token for Computer A, and copy it immediately.
7. Start the server.

Authentication is disabled by default in LM Studio. Enabling it is strongly recommended whenever the server binds to a network interface rather than only to `127.0.0.1`.

### Command-line alternative

The equivalent server command is:

```bash
lms server start --bind 0.0.0.0 --port 1234
```

`0.0.0.0` is a listen address, not the address Computer A should use. Computer A must use Computer B's actual LAN address.

### Network and firewall checklist

- Keep both computers on the same trusted LAN or reachable VLAN.
- Find Computer B's private address in the operating system's network settings. It commonly resembles `192.168.x.x` or `10.x.x.x`.
- Allow inbound TCP port `1234` in Computer B's firewall, preferably only for the private network or Computer A's address.
- Do not expose or forward this port on the internet. The connection is plain HTTP unless a separate trusted TLS proxy is added.
- If the computers are on the same Wi-Fi but cannot connect, check whether the router or guest network enables client/AP isolation.
- Give Computer B a DHCP reservation or stable address so the OpenCode endpoint does not change later.

## 2. Verify The Connection From Computer A

Store the token in the shell that will launch OpenCode:

```bash
export LM_STUDIO_API_TOKEN="replace-with-the-token-from-computer-b"
```

Then query the OpenAI-compatible model endpoint, replacing the example address:

```bash
curl --fail --show-error \
  -H "Authorization: Bearer $LM_STUDIO_API_TOKEN" \
  http://192.168.1.50:1234/v1/models
```

A JSON response containing model ids proves that routing, the firewall, the port, and authentication work. Copy the exact ids from the response; OpenCode must send ids that LM Studio recognizes.

If LM Studio authentication is intentionally disabled, omit the `Authorization` header and later omit `options.apiKey` from the OpenCode configuration.

Do not continue to OpenCode troubleshooting until this request succeeds. Typical failures are:

| Symptom | Likely cause |
|---|---|
| Connection refused | LM Studio is stopped, listening only on `127.0.0.1`, or using a different port. |
| Request times out | Wrong LAN address, firewall block, guest-network isolation, or different VLANs without a route. |
| `401` or `403` | Missing, invalid, or insufficient LM Studio API token. |
| JSON response but a later model error | The model id in OpenCode does not match the id exposed by LM Studio. |

## 3. Configure OpenCode On Computer A

Merge the following into the global `~/.config/opencode/opencode.json` (or `.jsonc`) on Computer A. A project-local `.opencode/opencode.json` can instead limit the provider to one repository.

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "lmstudio-lan": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "LM Studio (LAN)",
      "options": {
        "baseURL": "http://192.168.1.50:1234/v1",
        "apiKey": "{env:LM_STUDIO_API_TOKEN}"
      },
      "models": {
        "qwen-coder": {
          "name": "Qwen Coder on Computer B",
          "limit": {
            "context": 32768,
            "output": 8192
          }
        },
        "llama-general": {
          "name": "Llama General on Computer B",
          "limit": {
            "context": 16384,
            "output": 4096
          }
        }
      }
    }
  },
  "model": "lmstudio-lan/qwen-coder",
  "small_model": "lmstudio-lan/llama-general"
}
```

Replace:

- `192.168.1.50` with Computer B's stable LAN address.
- `qwen-coder` and `llama-general` with exact ids returned by `/v1/models` or identifiers assigned when loading the models.
- The context and output limits with values supported by each loaded model. These values inform OpenCode's context accounting; they do not increase LM Studio's loaded context length.

The provider id `lmstudio-lan` is arbitrary but must remain consistent. OpenCode model references use `provider_id/model_id`, so a model becomes `lmstudio-lan/qwen-coder`.

Restart OpenCode after changing the provider catalog, run `/models`, and select one of the models under **LM Studio (LAN)**. `opencode models` can also list models from a terminal.

## 4. Use Multiple LM Studio Models

Yes. Add every LM Studio model to the same OpenCode provider's `models` map, as in the example above. There are three separate meanings of "at the same time":

| Capability | Supported? | What controls it |
|---|---|---|
| Make several models selectable in OpenCode | Yes | Add several entries under `provider.lmstudio-lan.models`. |
| Keep several models resident in LM Studio memory | Yes, if RAM/VRAM permits | Load them manually, or disable JIT auto-eviction / **Only Keep Last JIT Loaded Model**. |
| Process requests concurrently | Yes, within runtime and hardware limits | LM Studio model load settings, engine support, and **Max Concurrent Predictions**; OpenCode does not set server concurrency. |

### Keep two models loaded

On Computer B, explicit identifiers make the OpenCode configuration stable even if model filenames or quantizations change:

```bash
lms ls
lms load <first-model-key> --identifier qwen-coder --context-length 32768
lms load <second-model-key> --identifier llama-general --context-length 16384
lms ps
```

Before loading both, estimate their memory requirements if needed:

```bash
lms load --estimate-only <first-model-key> --context-length 32768
lms load --estimate-only <second-model-key> --context-length 16384
```

If **Just in Time Model Loading** is enabled, LM Studio can load a requested downloaded model on first use. With JIT auto-eviction (called **Only Keep Last JIT Loaded Model** in current server settings) enabled, switching models unloads the previous JIT-loaded model. Disable that setting only when Computer B has enough RAM/VRAM to retain multiple models. Models loaded explicitly with `lms load` are not affected by JIT auto-eviction; an optional `--ttl <seconds>` can unload an idle one later.

Keeping models resident avoids repeated load delays, but does not guarantee that unrelated requests execute in parallel. LM Studio can use continuous batching for concurrent predictions on supported runtimes; otherwise requests may queue. Increasing concurrency also increases memory use, especially for KV caches.

### Assign different models to different OpenCode agents

OpenCode can map agents to different models from the same LM Studio server:

```json
{
  "agent": {
    "orchestraitor": {
      "model": "lmstudio-lan/qwen-coder"
    },
    "sdd-explore": {
      "model": "lmstudio-lan/llama-general"
    }
  }
}
```

A session still has one selected primary model at a time. Different agents can use different mappings, and delegated work may produce overlapping requests, but actual parallel execution remains a server and hardware concern.

For coding agents, prefer models with reliable tool calling and enough context for the repository. A model that works for chat is not necessarily capable of following OpenCode's tool protocol reliably.

## Troubleshooting

1. Re-run the `/v1/models` request from Computer A.
2. Confirm the configured `baseURL` ends in `/v1` and uses Computer B's address, not `localhost`.
3. Compare every configured model id character-for-character with the API response or assigned `lms load --identifier` value.
4. Confirm OpenCode inherited `LM_STUDIO_API_TOKEN` from the terminal or service that launched it.
5. Check the LM Studio server logs while sending one simple OpenCode request.
6. If responses fail only during agent work, verify that the selected model supports tool calling and that its context limit matches the load configuration.
7. If the first request after switching models is slow, check JIT loading and whether auto-eviction is forcing a model reload.

## References

- [OpenCode providers: LM Studio and custom OpenAI-compatible providers](https://opencode.ai/docs/providers)
- [LM Studio: serve on a local network](https://lmstudio.ai/docs/developer/core/server/serve-on-network)
- [LM Studio: API-token authentication](https://lmstudio.ai/docs/developer/core/authentication)
- [LM Studio: server settings](https://lmstudio.ai/docs/developer/core/server/settings)
- [LM Studio CLI: load and unload models](https://lmstudio.ai/docs/cli/local-models/load)
- [LM Studio: idle TTL and auto-eviction](https://lmstudio.ai/docs/developer/core/ttl-and-auto-evict)
- [LM Studio: parallel requests](https://lmstudio.ai/docs/app/advanced/parallel-requests)
