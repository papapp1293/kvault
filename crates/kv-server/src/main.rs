//! kv-server — the RESP wire server for kvault.
//!
//! Speaks the Redis protocol (RESP), so `redis-cli` and `redis-benchmark`
//! work against it. The store itself lives in `kv-core`; this binary owns
//! the socket, the protocol parser, and command dispatch.
//!
//! Scaffold state: binds and accepts connections, but the RESP handler is
//! not implemented yet. Task 001 (`docs/tasks/001-resp-protocol.md`) adds
//! the parser and the first commands (PING, ECHO, SET, GET, DEL).
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();

    let addr = std::env::var("KVAULT_ADDR").unwrap_or_else(|_| "127.0.0.1:6379".to_string());
    let listener = TcpListener::bind(&addr).await?;
    tracing::info!("kv-server listening on {addr} (RESP handler not implemented yet)");

    loop {
        let (socket, peer) = listener.accept().await?;
        tracing::info!(
            "accepted connection from {peer} — closing, RESP handler pending (task 001)"
        );
        drop(socket);
    }
}
