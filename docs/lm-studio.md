# Use LM Studio From OpenCode Over a Local Network

Computer A runs OpenCode. Computer B runs LM Studio on the same trusted network. OpenCode must use the LAN address of Computer B, not `localhost`.

## Quick path

1. On Computer B, enable **Serve on Local Network** and **Require Authentication** under **Developer > Server Settings**.
2. Start the server.
3. Allow inbound TCP port `1234` from the trusted LAN.
4. Write down the stable address of Computer B.
5. From Computer A, verify `/v1/models` with the API token.
6. Add an `lmstudio-lan` provider to OpenCode with the returned model ids.
7. Restart OpenCode and select a model with `/models`.

Unauthorized access can occur. Never expose the LM Studio port to the internet. It uses plain HTTP unless you add a trusted TLS proxy.

## Configure Computer B

Create a token for Computer A. The CLI equivalent of the quick-path server steps is:

```bash
lms server start --bind 0.0.0.0 --port 1234
```

`0.0.0.0` is a listen address. Computer A must use the private address of Computer B, for example `192.168.1.50`.

Network checklist:

- Limit firewall access to the private network or to Computer A.
- Disable guest-network client isolation, or use a reachable network.
- Give Computer B a DHCP reservation or a stable address.

## Verify from Computer A

Start OpenCode from a shell that has the token:

```bash
export LM_STUDIO_API_TOKEN="replace-with-the-token-from-computer-b"

curl --fail --show-error \
  -H "Authorization: Bearer $LM_STUDIO_API_TOKEN" \
  http://192.168.1.50:1234/v1/models
```

Do not configure OpenCode until this command returns JSON with model ids.

| Symptom | Check |
|---|---|
| Connection refused | Server state, bind address, and port |
| Timeout | LAN address, firewall, routing, and client isolation |
| `401` or `403` | API token |
| Later model error | Exact exposed model id |

If you disabled authentication on purpose, omit the header and `options.apiKey`.

## Configure OpenCode

On Computer A, merge this into the global `~/.config/opencode/opencode.json[c]` or the project `.opencode/opencode.json[c]`:

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

Replace the address, ids, and limits with the values from Computer B. The limits do not increase the loaded context. Model references use `provider_id/model_id`. Coding agents need reliable tool calling, not only good chat quality. Restart OpenCode, then use `/models` or `opencode models`.

## Multiple models

Each entry in the provider `models` map is selectable. If model filenames can change, load stable identifiers:

```bash
lms load --estimate-only <first-model-key> --context-length 32768
lms load <first-model-key> --identifier qwen-coder --context-length 32768
lms load <second-model-key> --identifier llama-general --context-length 16384
lms ps
```

JIT auto-eviction can unload the previous model. Disable **Only Keep Last JIT Loaded Model** only when the RAM or VRAM can hold all models. Loaded models do not run in parallel.

Assign models per agent when it helps:

```json
{
  "agent": {
    "orchestraitor": { "model": "lmstudio-lan/qwen-coder" },
    "sdd-explore": { "model": "lmstudio-lan/llama-general" }
  }
}
```

## Troubleshooting

1. Run `/v1/models` again from Computer A. Use the symptom table above.
2. Make sure that `baseURL` ends in `/v1` and does not use `localhost`.
3. Make sure that the OpenCode process inherited `LM_STUDIO_API_TOKEN`.
4. For failures only with agents, verify tool calling and context limits.
5. Compare each model id exactly with the `/v1/models` response or the `--identifier` value.
6. Read the LM Studio logs during one request.
7. If the first request is slow, check JIT loading.

## References

- [OpenCode providers](https://opencode.ai/docs/providers)
- [LM Studio network serving](https://lmstudio.ai/docs/developer/core/server/serve-on-network)
- [LM Studio authentication](https://lmstudio.ai/docs/developer/core/authentication)
- [LM Studio model loading](https://lmstudio.ai/docs/cli/local-models/load)
- [LM Studio parallel requests](https://lmstudio.ai/docs/app/advanced/parallel-requests)
