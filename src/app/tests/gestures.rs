use super::*;

#[test]
fn mouse_deferred_layout_does_not_roll_back_a_switch() {
    let outgoing = window(10);
    let incoming = window(11);
    let mut backend = FakeBackend {
        observation: Some(observation(&outgoing, frame(50))),
        managed_outcome: Some(macos::ApplyOutcome::Deferred),
        ..FakeBackend::default()
    };
    backend.frames.insert(outgoing.clone(), frame(50));
    backend.frames.insert(incoming.clone(), frame(60));
    let mut runtime = runtime(backend);
    bind(&mut runtime, WorkspaceId::ONE, &outgoing);
    let target = WorkspaceId::new(2).unwrap();
    bind(&mut runtime, target, &incoming);

    let result = runtime.switch(target, outputs(), &AtomicBool::new(false));

    assert!(result.is_ok());
    // The outgoing window stays parked; layout converges on a later cycle.
    assert!(runtime.parked.contains_key(&outgoing));
}

#[test]
fn dragging_to_a_tile_edge_previews_a_nested_insertion() {
    let moving = window(10);
    let target = window(20);
    let third = window(30);
    let mut backend = FakeBackend {
        focused: Some(moving.clone()),
        ..FakeBackend::default()
    };
    backend.frames.insert(moving.clone(), frame(50));
    backend.frames.insert(target.clone(), frame(400));
    backend.frames.insert(third.clone(), frame(750));
    let mut runtime = runtime(backend);
    bind(&mut runtime, WorkspaceId::ONE, &moving);
    bind(&mut runtime, WorkspaceId::ONE, &target);
    bind(&mut runtime, WorkspaceId::ONE, &third);

    runtime
        .drop_window(
            moving.clone(),
            (500, 10),
            true,
            outputs(),
            &AtomicBool::new(false),
        )
        .unwrap();

    let placements = runtime
        .workspaces
        .engine(WorkspaceId::ONE)
        .placements(&Settings::for_output(outputs().main().frame));
    assert_eq!(
        placements[0].frame,
        crate::Rect {
            x: 0,
            y: 0,
            width: 500,
            height: 400
        }
    );
    assert_eq!(
        placements[1].frame,
        crate::Rect {
            x: 0,
            y: 400,
            width: 500,
            height: 400
        }
    );
    assert_eq!(
        placements[2].frame,
        crate::Rect {
            x: 500,
            y: 0,
            width: 500,
            height: 800
        }
    );
}

#[test]
fn dragging_a_tiled_window_over_its_sibling_live_previews_the_swap() {
    let first = window(10);
    let second = window(20);
    let mut backend = FakeBackend {
        focused: Some(first.clone()),
        ..FakeBackend::default()
    };
    backend.frames.insert(first.clone(), frame(50));
    backend.frames.insert(second.clone(), frame(500));
    let mut runtime = runtime(backend);
    bind(&mut runtime, WorkspaceId::ONE, &first);
    bind(&mut runtime, WorkspaceId::ONE, &second);

    runtime
        .drop_window(
            first.clone(),
            (750, 400),
            true,
            outputs(),
            &AtomicBool::new(false),
        )
        .unwrap();

    assert_eq!(
        runtime.workspaces.engine(WorkspaceId::ONE).bound_windows(),
        vec![second.clone(), first.clone()]
    );
    assert!(runtime.backend.calls.contains(&BackendCall::Apply(
        second,
        crate::Rect {
            x: 0,
            y: 0,
            width: 500,
            height: 800,
        }
    )));
    assert!(
        !runtime
            .backend
            .calls
            .iter()
            .any(|call| matches!(call, BackendCall::Apply(window, _) if window == &first))
    );
}

#[test]
fn dropping_a_tiled_window_on_another_display_moves_it() {
    let moving = window(10);
    let target = window(20);
    let mut backend = FakeBackend {
        focused: Some(moving.clone()),
        ..FakeBackend::default()
    };
    backend.frames.insert(moving.clone(), frame(50));
    backend.frames.insert(target.clone(), frame(1050));
    let mut runtime = runtime(backend);
    bind(&mut runtime, WorkspaceId::ONE, &moving);
    bind(&mut runtime, WorkspaceId::SIX, &target);

    runtime
        .drop_window(
            moving.clone(),
            (1500, 400),
            false,
            outputs(),
            &AtomicBool::new(false),
        )
        .unwrap();

    assert_eq!(
        runtime.workspaces.workspace_of(&moving),
        Some(WorkspaceId::SIX)
    );
}
