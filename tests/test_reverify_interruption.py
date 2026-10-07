"""Inject interruptions into copied Ship fixtures; never touch the source repo."""

import argparse
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import os


def main():
    scripts = Path(sys.argv[1]).resolve()
    source = Path.cwd()
    spec = importlib.util.spec_from_file_location("pulmu_context", scripts / "run-context.py")
    context = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = context
    spec.loader.exec_module(context)
    for boundary in ("journal", "receipt", "invalidation", "state"):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "repo"
            shutil.copytree(source, fixture)
            os.chdir(fixture)
            store = context.Store()
            run_id = json.loads(store.path.read_text())["runId"]
            head = context.git_text("rev-parse", "HEAD")
            index = context.git_text("write-tree")
            content = Path("file.txt").read_bytes()
            args = argparse.Namespace(commit=head, expect_run_id=run_id)
            original_text, original_unlink, original_write = context.atomic_text, Path.unlink, context.Store.write

            def interrupted():
                raise RuntimeError("injected interruption")

            def atomic_text(path, value):
                original_text(path, value)
                if (boundary == "journal" and path.name == "ship-reverify-pending.json") or (
                    boundary == "receipt" and path.name == "ship-reverify.json"
                ):
                    interrupted()

            def unlink(path, *args, **kwargs):
                original_unlink(path, *args, **kwargs)
                if boundary == "invalidation" and path.name == "quench_fingerprint":
                    interrupted()

            def write(instance, state):
                original_write(instance, state)
                if boundary == "state" and state["stage"]["current"] == "quench":
                    interrupted()

            context.atomic_text, Path.unlink, context.Store.write = atomic_text, unlink, write
            try:
                try:
                    context.command_reverify_ship(store, args)
                except RuntimeError as exc:
                    assert str(exc) == "injected interruption"
                else:
                    raise AssertionError(f"did not interrupt at {boundary}")
            finally:
                context.atomic_text, Path.unlink, context.Store.write = original_text, original_unlink, original_write

            pending = store.root / "ship-reverify-pending.json"
            assert pending.is_file(), boundary
            saved = pending.read_bytes()
            for operation in (
                ["set-stage", "quench", "--expect-run-id", run_id],
                ["reverify-ship", "--commit", head, "--expect-run-id", "stale"],
                ["reverify-ship", "--commit", "0" * 40, "--expect-run-id", run_id],
            ):
                result = subprocess.run([sys.executable, str(scripts / "run-context.py"), *operation], capture_output=True)
                assert result.returncode != 0, (boundary, operation)
                assert pending.read_bytes() == saved
            context.command_reverify_ship(store, args)
            assert not pending.exists()
            state = json.loads(store.path.read_text())
            assert state["status"] == "running" and state["stage"]["current"] == "quench"
            assert context.git_text("rev-parse", "HEAD") == head
            assert context.git_text("write-tree") == index
            assert Path("file.txt").read_bytes() == content
            assert not (store.root.parent / "pulmu-metadata/quench_fingerprint").exists()
            os.chdir(source)


if __name__ == "__main__":
    main()
