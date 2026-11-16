//! leaderboard — the live leaderboard service built on kvault.
//!
//! A player submits a score, it lands in a sorted set in the store, and the
//! dashboard shows live ranks. The point of this service is to make the KV
//! store demonstrable: sorted sets, TTL'd seasonal boards, and pub/sub
//! fan-out are the features that make a leaderboard fast, and they're the
//! features this project exists to teach.
//!
//! Scaffold state: serves `/health` and the static dashboard shell. The
//! score API and WebSocket live updates land in later tasks — see
//! `docs/tasks/queue.md`.
use axum::{routing::get, Router};
use std::path::PathBuf;
use tower_http::services::ServeDir;

fn static_dir() -> PathBuf {
    // Works from the workspace root (`cargo run -p leaderboard`) and from
    // the crate directory.
    for candidate in ["crates/leaderboard/static", "static"] {
        let path = PathBuf::from(candidate);
        if path.is_dir() {
            return path;
        }
    }
    PathBuf::from("crates/leaderboard/static")
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();

    let app = Router::new()
        .route("/health", get(|| async { "ok" }))
        .fallback_service(ServeDir::new(static_dir()));

    let addr = std::env::var("LEADERBOARD_ADDR").unwrap_or_else(|_| "127.0.0.1:3000".to_string());
    let listener = tokio::net::TcpListener::bind(&addr).await?;
    tracing::info!(
        "leaderboard listening on http://{addr} (score API pending — see docs/tasks/queue.md)"
    );
    axum::serve(listener, app).await?;
    Ok(())
}
