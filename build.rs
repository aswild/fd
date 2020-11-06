use std::fs;
use std::process::{Command, Stdio};

use clap::Shell;

include!("src/app.rs");

fn main() {
    let min_version = "1.36";

    match version_check::is_min_version(min_version) {
        Some(true) => {}
        // rustc version too small or can't figure it out
        _ => {
            eprintln!("'fd' requires rustc >= {}", min_version);
            std::process::exit(1);
        }
    }

    // determine version from "git describe", unless disabled
    if !cfg!(feature = "fd-no-gitversion") {
        let git_describe_out = Command::new("git")
            .arg("describe")
            .arg("--tags")
            .arg("--dirty=+")
            .stderr(Stdio::inherit())
            .output();
        if let Ok(out) = git_describe_out {
            if out.status.success() {
                // stringify output, strip whitespace, and strip a leading 'v'
                let git_version = String::from_utf8_lossy(&out.stdout);
                let git_version_trimmed = git_version.trim().trim_start_matches('v');
                println!("cargo:rustc-env=FD_GIT_VERSION={}", git_version_trimmed);
            }
        }
    }

    let var = std::env::var_os("SHELL_COMPLETIONS_DIR").or_else(|| std::env::var_os("OUT_DIR"));
    let outdir = match var {
        None => return,
        Some(outdir) => outdir,
    };
    fs::create_dir_all(&outdir).unwrap();

    let mut app = build_app();
    app.gen_completions("fd", Shell::Bash, &outdir);
    app.gen_completions("fd", Shell::Fish, &outdir);
    app.gen_completions("fd", Shell::PowerShell, &outdir);
}
