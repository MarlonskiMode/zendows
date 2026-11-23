use super::*;

#[test]
fn dual_display_cycle_call_budget_is_explicit() {
    let mut runtime = runtime(benchmark_backend(2));

    runtime.cycle(outputs(), &AtomicBool::new(false)).unwrap();
    runtime.cycle(outputs(), &AtomicBool::new(false)).unwrap();

    assert_eq!(runtime.backend.snapshot_count, 2);
    assert_eq!(runtime.backend.observed_apply_count, 2);
}

#[test]
#[ignore = "performance benchmark"]
fn benchmark_dual_display_steady_state_256_windows() {
    let mut runtime = runtime(benchmark_backend(256));
    let cancelled = AtomicBool::new(false);
    for _ in 0..10 {
        runtime.cycle(outputs(), &cancelled).unwrap();
    }
    let mut samples = Vec::new();
    for _ in 0..9 {
        let start = std::time::Instant::now();
        for _ in 0..100 {
            std::hint::black_box(runtime.cycle(outputs(), &cancelled).unwrap());
        }
        samples.push(start.elapsed().as_secs_f64() * 10_000.0);
    }
    samples.sort_by(f64::total_cmp);
    let median = samples[samples.len() / 2];
    println!("METRIC steady_state_cycle_us={median:.3}");
    println!("METRIC snapshot_calls={}", runtime.backend.snapshot_count);
    println!(
        "METRIC observed_apply_calls={}",
        runtime.backend.observed_apply_count
    );
}

#[test]
#[ignore = "performance benchmark"]
fn benchmark_new_window_event_to_correct_frame() {
    let existing = window(10);
    let created = window(11);
    let main_frame = frame(50);
    let secondary_frame = frame(1050);
    let mut samples = Vec::new();

    // One warmup followed by nine measured event-loop phases. The AX dirty bit
    // remains set until the production dispatch predicate accepts the refresh.
    for first_tick_ms in [1_u64, 1, 4, 7, 10, 13, 16, 19, 22, 25] {
        let mut backend = FakeBackend {
            focused: Some(existing.clone()),
            frontmost: Some(existing.app.clone()),
            observation: Some(observation_for_windows(
                "com.mitchellh.ghostty",
                &existing,
                &[(existing.clone(), main_frame)],
            )),
            ..FakeBackend::default()
        };
        backend.frames.insert(existing.clone(), main_frame);
        let mut runtime = runtime(backend);
        runtime.cycle(outputs(), &AtomicBool::new(false)).unwrap();

        runtime.backend.focused = Some(created.clone());
        runtime.backend.frontmost = Some(created.app.clone());
        runtime
            .backend
            .frames
            .insert(created.clone(), secondary_frame);
        runtime.backend.observation = Some(observation_for_windows(
            "com.mitchellh.ghostty",
            &created,
            &[
                (existing.clone(), main_frame),
                (created.clone(), secondary_frame),
            ],
        ));

        let mut dispatch_ms = first_tick_ms;
        let activation_ready_ms = first_tick_ms + APPLICATION_ACTIVATION_SETTLE.as_millis() as u64;
        while !refresh_due(true, true, false, dispatch_ms >= activation_ready_ms) {
            dispatch_ms += TICK_INTERVAL.as_millis() as u64;
        }
        let apply_started = Instant::now();
        runtime.cycle(outputs(), &AtomicBool::new(false)).unwrap();
        let latency_ms = dispatch_ms as f64 + apply_started.elapsed().as_secs_f64() * 1_000.0;
        assert_eq!(
            runtime.workspaces.workspace_of(&created),
            Some(WorkspaceId::ONE)
        );
        assert!(runtime.backend.frames[&created].x < 1000);
        samples.push(latency_ms);
    }

    samples.remove(0);
    samples.sort_by(f64::total_cmp);
    let median = samples[samples.len() / 2];
    let spread = samples.last().unwrap() - samples.first().unwrap();
    println!("METRIC new_window_correct_frame_ms={median:.3}");
    println!("METRIC new_window_correct_frame_spread_ms={spread:.3}");
    println!("METRIC new_window_correct_frame_best_ms={:.3}", samples[0]);
    println!(
        "METRIC new_window_correct_frame_worst_ms={:.3}",
        samples[samples.len() - 1]
    );
}
