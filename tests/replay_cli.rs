use std::process::Command;

use serde_json::Value;

#[test]
fn replay_reports_a_slot_preserving_ghostty_replacement() {
    let output = Command::new(env!("CARGO_BIN_EXE_zendows"))
        .args(["replay", "fixtures/ghostty-tab-replacement.json"])
        .output()
        .expect("zendows should run");

    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    let value: Value = serde_json::from_slice(&output.stdout).expect("replay should output JSON");
    let steps = value["steps"].as_array().expect("steps should be an array");

    assert_eq!(steps.len(), 2);
    assert_eq!(
        steps[0]["model"]["workspace"]["slots"]
            .as_array()
            .unwrap()
            .len(),
        1
    );
    assert_eq!(
        steps[1]["model"]["workspace"]["slots"]
            .as_array()
            .unwrap()
            .len(),
        1
    );
    assert_eq!(steps[1]["decisions"][0]["type"], "native_tab_replaced");
    assert_eq!(steps[1]["decisions"][0]["slot"], 1);
}
