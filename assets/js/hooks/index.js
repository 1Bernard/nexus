/**
 * LiveView Hooks — barrel export
 *
 * Import all hooks here and re-export as a single object
 * for the LiveSocket constructor in app.js.
 *
 * Usage:
 *   import Hooks from "./hooks";
 *   new LiveSocket("/live", Socket, { hooks: Hooks });
 */

import WebAuthnHook from "./webauthn";
import { CursorFollower, ScrollReveal } from "./cinematic";

export default {
  WebAuthnHook,
  CursorFollower,
  ScrollReveal
};
