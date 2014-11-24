#!/usr/bin/env bats

@test "docker version is current" {
  run "docker --version | grep 1.3.1"
  [ "$?" -eq 0 ]
}
