// SPDX-License-Identifier: MIT
//! `tmpl` — render a Typst template with JSON data into a PDF.
//!
//! Usage: `tmpl <template.typ> <data.json> <out.pdf>`
//!
//! The JSON is validated, then handed to the template as `sys.inputs.data`.

use std::io::Write as _;
use std::path::PathBuf;
use std::process::{Command, ExitCode};

/// Usage line shown on bad arguments.
const USAGE: &str = "usage: tmpl <template.typ> <data.json> <out.pdf>";

/// Everything that can go wrong while rendering.
#[derive(Debug, thiserror::Error)]
enum RenderError {
    /// The data file is not valid JSON.
    #[error("invalid JSON in {path}: {source}")]
    InvalidJson {
        /// Data file path.
        path: PathBuf,
        /// Parser error.
        source: serde_json::Error,
    },
    /// A file could not be read.
    #[error("cannot read {path}: {source}")]
    Read {
        /// File path.
        path: PathBuf,
        /// IO error.
        source: std::io::Error,
    },
    /// The `typst` binary could not be launched.
    #[error("cannot run typst (is it on PATH?): {0}")]
    Spawn(std::io::Error),
    /// Typst ran but reported a compile error.
    #[error("typst failed with {0}")]
    Typst(std::process::ExitStatus),
    /// Wrong command-line arguments.
    #[error("{USAGE}")]
    Usage,
}

/// A single render request.
struct Job {
    /// Typst template file.
    template: PathBuf,
    /// JSON data file.
    data: PathBuf,
    /// PDF output file.
    output: PathBuf,
}

impl Job {
    /// Builds a job from exactly three positional arguments.
    fn from_args(mut args: impl Iterator<Item = String>) -> Result<Self, RenderError> {
        match (args.next(), args.next(), args.next(), args.next()) {
            (Some(template), Some(data), Some(output), None) => Ok(Self {
                template: template.into(),
                data: data.into(),
                output: output.into(),
            }),
            _ => Err(RenderError::Usage),
        }
    }

    /// Validates the data and compiles the template to PDF.
    fn render(&self) -> Result<(), RenderError> {
        let json = std::fs::read_to_string(&self.data).map_err(|source| RenderError::Read {
            path: self.data.clone(),
            source,
        })?;
        // STRUCTURAL-VALUE: parsed only to validate; the template owns the schema.
        serde_json::from_str::<serde_json::Value>(&json).map_err(|source| {
            RenderError::InvalidJson {
                path: self.data.clone(),
                source,
            }
        })?;
        let status = Command::new("typst")
            .arg("compile")
            .arg("--input")
            .arg(format!("data={json}"))
            .arg(&self.template)
            .arg(&self.output)
            .status()
            .map_err(RenderError::Spawn)?;
        if status.success() {
            Ok(())
        } else {
            Err(RenderError::Typst(status))
        }
    }
}

fn main() -> ExitCode {
    let result = Job::from_args(std::env::args().skip(1)).and_then(|job| {
        job.render()?;
        Ok(job.output)
    });
    match result {
        Ok(out) => {
            let _ = writeln!(std::io::stdout(), "wrote {}", out.display());
            ExitCode::SUCCESS
        }
        Err(err) => {
            let _ = writeln!(std::io::stderr(), "error: {err}");
            ExitCode::FAILURE
        }
    }
}
