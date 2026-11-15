set shell := ["sh", "-c"]
set windows-shell := ["powershell.exe", "-c"]

[doc('Compile every artifact without running it')]
check:
    zig build check

[doc('Compile every artifact for Windows from any host')]
check-windows:
    zig build check -Dtarget=x86_64-windows-gnu

[doc('Run the continuous integration pipeline')]
ci:
    zig build ci
    zig build test:unit -Doptimize=safe

[doc('Format build.zig and every source file')]
fmt:
    zig fmt build.zig src

[doc('Lint build.zig and every source file with tigerstyle-lsp')]
lint:
    tigerstyle-lsp check build.zig src --format concise

[default]
[doc('List every recipe')]
list:
    @just --list

[doc('Build and run the application')]
run:
    zig build run

[doc('Run every test suite and the format check')]
test:
    zig build test

[doc('Run the unit tests and the tidy check: just test-unit [filter]')]
test-unit filter="":
    zig build test:unit {{ if filter == "" { "" } else { "-Dtest-filter=" + filter } }}

[doc('Run the Windows tests on a Windows host: just test-windows [filter]')]
test-windows filter="":
    zig build test:windows {{ if filter == "" { "" } else { "-Dtest-filter=" + filter } }}
