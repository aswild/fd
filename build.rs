use std::ffi::OsString;
use std::fs;
use std::path::PathBuf;
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

    let var = std::env::var_os("SHELL_COMPLETIONS_DIR").or(std::env::var_os("OUT_DIR"));
    let outdir = match var {
        None => return,
        Some(outdir) => outdir,
    };
    fs::create_dir_all(&outdir).unwrap();

    let mut app = build_app();
    app.gen_completions("fd", Shell::Bash, &outdir);
    app.gen_completions("fd", Shell::Fish, &outdir);
    app.gen_completions("fd", Shell::Zsh, &outdir);
    app.gen_completions("fd", Shell::PowerShell, &outdir);

    // HACK! As usual, clap is incapable of generating correct zsh completions.
    // In this case, the path option gets set as '::path -- ...' in _arguments,
    // which only takes one path rather than multiple, so only one file path gets
    // completed rather than all of them.
    // Run this through sed (because I'm too lazy to do a whole regex filter
    // thing here) to change ::path into *::path to fix this.
    let zshcomp_path: PathBuf = [&outdir, &OsString::from("_fd")].iter().collect();
    if zshcomp_path.is_file() {
        let sed_status = Command::new("sed")
            .arg("-i")
            .arg("s/'::path/'*::path/")
            .arg("--")
            .arg(zshcomp_path)
            .status();
        match sed_status {
            Ok(s) if s.success() => (),
            Ok(_) => eprintln!("zsh completion sed fixup failed"),
            Err(e) => eprintln!("failed to spawn zsh completion sed fixup: {}", e),
        };
    }
}
