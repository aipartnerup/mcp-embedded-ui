# F4: Auth Hook

**Status:** P1 | **Complexity:** S | **Dependencies:** F3

## Overview

An optional authentication hook that gates tool execution behind
caller-supplied authorization logic. The hook is a function that
receives the incoming HTTP request and returns a context manager
(sync or async). If the context manager raises before yield, the
request is rejected with `401 Unauthorized`. The library never
captures the yielded value -- identity propagation is the caller's
responsibility, **where the language's hook shape makes that possible**.
See FR-1b for the one case where it does not.

## Scope

- `AuthHook` abstraction: a callable that accepts an HTTP request and
  returns a context manager (sync or async).
- Sync and async context manager support with automatic detection.
- Auth failure handling: rejected requests receive a generic 401 with
  no internal detail leaking.
- Guards the execution endpoint only (`POST /tools/{name}/call`).
- Identity propagation is the caller's responsibility (e.g.,
  `ContextVar` in Python, `AsyncLocalStorage` in Node) -- subject to the
  hook-shape rule in FR-1b.

## Functional Requirements

### FR-1: AuthHook Abstraction

The `AuthHook` is a callable with the following contract:

- **Input:** the HTTP request object (framework-specific).
- **Output:** a context manager (sync or async).
- **Behavior:**
  - If the context manager raises/throws before yield, the request is
    rejected with HTTP 401.
  - If the context manager yields without raising, the request
    proceeds to the tool handler.
  - The yielded value is **not** captured by the library. Callers must
    use their own mechanism to propagate identity downstream (e.g.,
    `contextvars.ContextVar` in Python, `AsyncLocalStorage` in
    Node.js).

### FR-1b: Identity Propagation and Hook Shape

FR-1 assumes the caller can scope an identity around the tool call itself.
That holds only when the language's hook shape **carries the call**:

| Language | Hook shape | How the caller propagates identity |
|------------|-----------------------------------|------------------------------------|
| Python | returns a context manager | set a `contextvars.ContextVar` across the `yield` |
| TypeScript | `(req, next) => Promise<Response>` | wrap `next` in `AsyncLocalStorage.run` |

Both receive the continuation, so the caller wraps the tool call without any
cooperation from the library. This is the default and preferred shape.

**Where the hook does not carry the call, FR-1 is structurally
unachievable.** Rust's `AuthHook` is
`Fn(Parts) -> Future<Output = Result<(), AuthError>>`: it produces a pass/fail
verdict, receives no continuation, and returns no value. A caller cannot scope
an identity around a call it never sees.

An implementation in that position MAY expose an additional **authenticator**
abstraction -- a callable returning an identity on success, which the library
then scopes for the duration of the tool call.

This is a **parity mechanism, not a feature**. Its only purpose is to give that
language's callers the same API the others already have (*pass an
authenticator, read the identity inside the handler*), and observable
behaviour MUST stay identical across languages. It is not licence to give one
binding capabilities the others lack.

Requirements when providing one:

- The pass/fail `AuthHook` remains available for callers who need no identity,
  and is not deprecated by the addition.
- The authenticator takes precedence when both are configured, and that
  precedence is documented on the config type.
- It guards exactly the same endpoints as `AuthHook` (execution only, FR-2).
- The rationale is recorded at the type itself, so the next reader does not
  mistake it for an undocumented extension.

Current implementations: Rust exposes `Authenticator` / `Identity` /
`AUTH_IDENTITY` under this clause.

Python and TypeScript **SHOULD NOT** add one: their hook shapes already carry
the call, so an authenticator would be a second way to do something the
existing API does, with no gain in capability. This is conditioned on the hook
shape, not fixed forever -- if a binding's hook shape changes such that it no
longer carries the call, it comes under this clause like any other. Re-evaluate
against the premise, not against this sentence.

### FR-2: Integration Point

The auth hook runs **only** on the execution endpoint:

- `POST /tools/{name}/call` -- **guarded** by auth hook.

The following endpoints are **not** guarded:

- `GET /tools` -- tool list (public discovery).
- `GET /tools/{name}` -- tool detail (public discovery).
- `GET /` -- HTML frontend.

This is intentional: tool discovery is public, execution is gated.

### FR-3: Execution Flow

The auth hook is invoked after the `allow_execute` check and tool
lookup, but before the tool's `handle_call`:

```
request → allow_execute check → tool lookup → auth_hook → handle_call
```

### FR-4: Sync vs Async Detection

The library inspects the returned context manager to determine
whether to use sync or async entry:

- If the object implements `__aenter__` / `__aexit__` (or the
  language equivalent) → enter via `async with`.
- Otherwise → enter via `with`.

This allows callers to choose based on whether their auth logic
requires async I/O (e.g., a remote token validation service) or
is purely synchronous (e.g., local JWT signature check).

## Error Handling

### EH-1: Auth Failure Response

When the auth hook raises an exception (before yield):

- The server responds with HTTP **401** and body
  `{"error": "Unauthorized"}`.
- The response **MUST NOT** include the exception message, traceback,
  or any other internal detail. This prevents leaking database errors,
  file paths, configuration values, or internal state to the client.

### EH-2: Server-Side Logging

The exception raised by the auth hook **IS** logged server-side at
`WARNING` level. This gives operators visibility into auth failures
for debugging and monitoring without exposing details to clients.

## Security

### SEC-1: No Internal Detail Leaking

The 401 response body is always the fixed JSON object
`{"error": "Unauthorized"}` regardless of the exception type or
message. This is a deliberate security constraint.

### SEC-2: Execution-Only Gating

The auth hook is not applied to read-only discovery endpoints.
This avoids accidentally blocking tool exploration while ensuring
that any state-changing operation requires valid credentials.

## Cross-Language Mapping

| Language | Pattern | Example |
|----------|---------|---------|
| Python | `@contextmanager` / `@asynccontextmanager` returning CM | `with auth_hook(request): ...` |
| TypeScript | Middleware function | `(req, next) => { validate(req); return next() }` |
| Go | `http.Handler` middleware wrapper | `func AuthMiddleware(next http.Handler) http.Handler` |
| Rust | Async function (`async fn(parts: Parts) -> Result<(), AuthError>`) | `AuthHook(Some(Arc::new(\|parts\| { ... })))` |

## Examples

### Python -- Basic Auth Hook

```python
@contextmanager
def my_auth(request):
    token = request.headers.get("Authorization")
    if not valid(token):
        raise ValueError("Bad token")  # → 401, detail NOT sent to client
    identity_var.set(decode(token))     # caller propagates identity
    try:
        yield
    finally:
        identity_var.set(None)
```

### Python -- apcore-mcp Integration

```python
@contextmanager
def apcore_auth_hook(request):
    headers = extract_headers(request.scope)
    identity = authenticator.authenticate(headers)
    if identity is None:
        raise ValueError("Missing or invalid Bearer token")
    token = auth_identity_var.set(identity)
    try:
        yield
    finally:
        auth_identity_var.reset(token)
```

## Test Criteria

| # | Assertion | Method |
|---|-----------|--------|
| TC-1 | Valid sync auth hook allows tool execution. | Integration test: call `POST /tools/{name}/call` with valid credentials, assert 200. |
| TC-2 | Invalid sync auth hook returns 401 with `{"error": "Unauthorized"}`. | Integration test: call with invalid credentials, assert 401 and exact body. |
| TC-3 | Valid async auth hook allows tool execution. | Integration test: provide async CM auth hook, call with valid credentials, assert 200. |
| TC-4 | Invalid async auth hook returns 401. | Integration test: provide async CM auth hook, call with invalid credentials, assert 401. |
| TC-5 | 401 response does NOT contain exception detail/message. | Assert response body equals `{"error": "Unauthorized"}` exactly; no traceback, no exception text. |
| TC-6 | Auth hook is not called for GET endpoints. | Integration test: call `GET /tools`, `GET /tools/{name}`, `GET /` without credentials, assert 200 and verify hook was not invoked. |
| TC-7 | **FR-1b only.** An accepting authenticator propagates its identity to the tool handler. | Integration test: handler reports what it sees in the identity slot; assert it matches the authenticated identity — not merely that the call returned 200. |
| TC-8 | **FR-1b only.** A rejecting authenticator returns 401 with the same body as `AuthHook`. | Integration test: assert 401 and body exactly `{"error": "Unauthorized"}`. |
| TC-9 | **FR-1b only.** The authenticator takes precedence; the `AuthHook` is never invoked when both are configured. | Integration test: configure a rejecting hook alongside an accepting authenticator; assert 200 **and** that the hook did not run (flag/spy, not status alone). |
| TC-10 | **FR-1b only.** With no authenticator configured, the identity slot reads as empty rather than erroring. | Integration test: handler reads the slot with no authenticator set; assert it yields "no identity" and does not panic/throw. |
| TC-11 | **FR-1b only.** The authenticator guards the same endpoints as `AuthHook` — not the GET endpoints, not `/validate`. | Integration test: with a rejecting authenticator, assert `GET /`, `GET /tools` and `POST /tools/{name}/validate` all still return 200. |
