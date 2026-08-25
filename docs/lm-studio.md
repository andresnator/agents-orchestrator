# Use LM Studio From OpenCode Over a Local Network

Computer A runs OpenCode; Computer B runs LM Studio. Both must share a reachable trusted network, and OpenCode must use Computer B's LAN address rather than `localhost`.

## Quick path

1. On Computer B, enable **Serve on Local Network** and **Require Authentication** under **Developer > Server Settings**.
2. Start the server, allow inbound TCP port `1234` from the trusted LAN, and note Computer B's stable address.
3. From Computer A, verify `/v1/models` with the API token.
4. Add an `lmstudio-lan` provider to OpenCode using the returned model ids.
5. Restart OpenCode and select a model with `/models`.

Never expose the LM Studio port to the internet. It uses plain HTTP unless you add a trusted TLS proxy.

## Configure Computer B

In LM Studio, enable network serving and authentication, create a token for Computer A, then start the server. CLI equivalent:

```bash
lms server start --bind 0.0.0.0 --port 1234
```

`0.0.0.0` is a listen address. Computer A must use Computer B's private address, such as `192.168.1.50`.

Network checklist:

- Keep both machines on a trusted LAN or routed VLAN.
- Restrict firewall access to the private network or Computer A.
- Disable guest-network client isolation or use a reachable network.
- Give Computer B a DHCP reservation or stable address.

## Verify from Computer A

Launch OpenCode from a shell that contains the token:

```bash
export LM_STUDIO_API_TOKEN="replace-with-the-token-from-computer-b"

curl --fail --show-error \
  -H "Authorization: Bearer $LM_STUDIO_API_TOKEN" \
  http://192.168.1.50:1234/v1/models
```

Do not configure OpenCode until this returns JSON with model ids.

| Symptom | Check |
|---|---|
| Connection refused | Server state, bind address, and port |
| Timeout | LAN address, firewall, routing, and client isolation |
| `401` or `403` | API token |
| Later model error | Exact exposed model id |

If authentication is intentionally disabled, omit both the header and `options.apiKey`.

## Configure OpenCode

Merge this into global `~/.config/opencode/opencode.json[c]` or project `.opencode/opencode.json[c]` on Computer A:

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
          "limit": { "context": 32768, "output": 8192 }
        },
        "llama-general": {
          "name": "Llama General on Computer B",
          "limit": { "context": 16384, "output": 4096 }
        }
      }
    }
  },
  "model": "lmstudio-lan/qwen-coder",
  "small_model": "lmstudio-lan/llama-general"
}
```

Replace the address, ids, and limits with values from Computer B. Limits inform OpenCode accounting; they do not increase the model's loaded context. Model references use `provider_id/model_id`.

Restart OpenCode, then use `/models` or `opencode models`.

## Multiple models

| Goal | Supported | Owner |
|---|---|---|
| Make several models selectable | Yes | OpenCode provider map |
| Keep several models resident | If memory permits | LM Studio load settings |
| Process requests concurrently | Hardware and runtime dependent | LM Studio server |

Load stable identifiers when model filenames may change:

```bash
lms load --estimate-only <first-model-key> --context-length 32768
lms load <first-model-key> --identifier qwen-coder --context-length 32768
lms load <second-model-key> --identifier llama-general --context-length 16384
lms ps
```

JIT auto-eviction may unload the previous model. Disable **Only Keep Last JIT Loaded Model** only when RAM or VRAM can retain all models. Residency reduces load delay but does not guarantee parallel execution.

Assign models per agent when useful:

```json
{
  "agent": {
    "orchestraitor": { "model": "lmstudio-lan/qwen-coder" },
    "sdd-explore": { "model": "lmstudio-lan/llama-general" }
  }
}
```

Coding agents need reliable tool calling and enough context; chat quality alone is insufficient.

## Troubleshooting

1. Re-run `/v1/models` from Computer A.
2. Confirm `baseURL` ends in `/v1` and never uses Computer A's `localhost`.
3. Compare every model id exactly with the API response or `--identifier` value.
4. Confirm the OpenCode process inherited `LM_STUDIO_API_TOKEN`.
5. Inspect LM Studio logs during one simple request.
6. For agent-only failures, verify tool calling and context limits.
7. For slow first requests, check JIT loading and auto-eviction.

## References

- [OpenCode providers](https://opencode.ai/docs/providers)
- [LM Studio network serving](https://lmstudio.ai/docs/developer/core/server/serve-on-network)
- [LM Studio authentication](https://lmstudio.ai/docs/developer/core/authentication)
- [LM Studio model loading](https://lmstudio.ai/docs/cli/local-models/load)
- [LM Studio parallel requests](https://lmstudio.ai/docs/app/advanced/parallel-requests)
