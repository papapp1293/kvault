//! Criterion benchmarks for the kv-core store.
//!
//! Placeholder until task 001 lands the store. Real benches to add:
//! `set_get_roundtrip`, `zadd_zrange` (sorted sets), `expiry_sweep`.
//! Run with: `cargo bench -p kv-core`
use criterion::{criterion_group, criterion_main, Criterion};

fn placeholder(c: &mut Criterion) {
    c.bench_function("placeholder", |b| b.iter(kv_core::version));
}

criterion_group!(benches, placeholder);
criterion_main!(benches);
