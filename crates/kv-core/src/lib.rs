//! kv-core — the in-memory storage engine behind kvault.
//!
//! Owns the data structures (strings, hashes, sorted sets), TTL/expiry,
//! and persistence (append-only log + snapshots). No networking lives here;
//! see `kv-server` for the RESP wire protocol and `leaderboard` for the
//! HTTP/WebSocket service built on top.
//!
//! The first real feature is the store itself — see
//! `docs/tasks/001-resp-protocol.md` and `docs/architecture.md`.

/// Placeholder so the crate compiles before the first feature lands.
/// Replaced by the store implementation in task 001.
pub fn version() -> &'static str {
    env!("CARGO_PKG_VERSION")
}

#[cfg(test)]
mod tests {
    #[test]
    fn placeholder() {
        assert!(!super::version().is_empty());
    }
}
