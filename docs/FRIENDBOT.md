# Using Friendbot

Friendbot is the faucet built into the quickstart deployment. It creates and
funds Stellar accounts on the private network with **10,000 XLM** each, paid
from the network's root account. There's no authentication — anyone who can
reach the endpoint can fund accounts, which is exactly why the module deploys
private-by-default.

## Availability

| `stellar_network` | Friendbot |
|---|---|
| `local` | ✅ Runs inside this deployment at `<stellar_endpoint>/friendbot` |
| `testnet` | ❌ Not run here — use SDF's public faucet: `https://friendbot.stellar.org` |
| `futurenet` | ❌ Not run here — use `https://friendbot-futurenet.stellar.org` |

Everything below assumes `stellar_network = "local"`.

Your endpoint is the module's `stellar_endpoint` output — e.g.
`http://quickstart.stellar.internal:8000` (private mode, from inside the
VNet/VPN) or `http://<label>.<region>.azurecontainer.io:8000` (public mode).
Substitute it for `$STELLAR` below:

```bash
export STELLAR="http://quickstart.stellar.internal:8000"
```

## Fund an account with curl

Friendbot takes a single query parameter, `addr` — the account to create and
fund. Both regular accounts (`G...`) and contract addresses (`C...`) work:

```bash
curl "$STELLAR/friendbot?addr=GCEXAMPLE...YOURPUBLICKEY"
```

A success response is the submitted transaction, including its hash and ledger:

```json
{
  "_links": { "transaction": { "href": "..." } },
  "hash": "9a4e...",
  "ledger": 1234,
  "successful": true
}
```

Common errors:

| Response | Meaning |
|---|---|
| `400` with `"invalid_field": "addr"` | Missing or malformed address — must be a valid `G` or `C` address |
| `400` with `createAccountAlreadyExist` in the result codes | The account is already funded; Friendbot only creates new accounts |

## Generate and fund a keypair with stellar-cli

```bash
# One-time: register the deployment as a named network
stellar network add azure-dev \
  --rpc-url "$STELLAR/rpc" \
  --network-passphrase "Standalone Network ; February 2017"

# Generate a keypair (no funding yet)
stellar keys generate alice --network azure-dev --no-fund
stellar keys address alice

# Fund it via Friendbot
curl "$STELLAR/friendbot?addr=$(stellar keys address alice)"
```

`"Standalone Network ; February 2017"` is the quickstart local network's
default passphrase. If you set a custom one on the container, use that instead.

> **Why not `--fund`?** `stellar keys generate --fund` discovers the faucet by
> asking the RPC server, and this deployment's RPC advertises its Friendbot as
> `http://localhost:8000/friendbot` — a URL that's only valid *inside* the
> container. From your machine, `--fund` may therefore fail; the explicit
> `curl` above always works.

## Fund an account from JavaScript

```js
import { Keypair, Horizon } from "@stellar/stellar-sdk";

const STELLAR = "http://quickstart.stellar.internal:8000";

const pair = Keypair.random();
const res = await fetch(`${STELLAR}/friendbot?addr=${pair.publicKey()}`);
if (!res.ok) throw new Error(`friendbot: ${res.status} ${await res.text()}`);

// The account now exists with 10,000 XLM:
const horizon = new Horizon.Server(STELLAR, { allowHttp: true });
const account = await horizon.loadAccount(pair.publicKey());
console.log(account.balances);
```

`allowHttp: true` is needed because the endpoint is plain HTTP — acceptable on
a private network, one more reason not to run this public.

## Operational notes

- **Fresh network on restart**: `--local` restarts from genesis, so all funded
  accounts disappear when the container restarts. Scripts should fund on
  startup rather than assume accounts persist.
- **Balance/limits**: each request funds exactly 10,000 XLM; there is no
  per-caller rate limit. On a public deployment this means anyone can create
  unlimited funded accounts — harmless economically (the XLM is play money on
  your private network) but it can pollute or load your test network.
